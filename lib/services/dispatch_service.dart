import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:docx_template/docx_template.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as ai;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../models/mapping_model.dart';

class DispatchService {
  final String geminiApiKey;

  DispatchService({required this.geminiApiKey});

  String _normalize(String input) {
    String s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll("gram panchayat", "").replaceAll("panchayat samiti", "").trim();
    return s;
  }

  String _clean(dynamic value) {
    if (value == null) return "";
    return value.toString().trim();
  }

  String _formatDispatchNo(String value) {
    String s = _clean(value);
    RegExp hyphenReg = RegExp(r'-(\d+)-');
    var match = hyphenReg.firstMatch(s);
    if (match != null) return match.group(1)!;

    RegExp numReg = RegExp(r'\b(\d+)\b');
    match = numReg.firstMatch(s);
    if (match != null) return match.group(1)!;

    return s;
  }

  String _paraPlusOne(dynamic value) {
    String s = _clean(value);
    if (s.isEmpty) return "";
    try {
      double d = double.parse(s);
      return (d.toInt() + 1).toString();
    } catch (_) {
      return s;
    }
  }

  // Local Dropdown Helpers
  List<String> getAvailableDistricts() {
    if (!Hive.isBoxOpen('mappings_box')) return [];
    final box = Hive.box<MappingModel>('mappings_box');
    final districts = box.values
        .map((e) => e.distHi.isNotEmpty ? e.distHi : e.distEn)
        .where((element) => element.isNotEmpty)
        .toSet();
    return List<String>.from(districts)..sort();
  }

  List<String> getPanchayatSamitisForDistrict(String district) {
    if (!Hive.isBoxOpen('mappings_box')) return [];
    final box = Hive.box<MappingModel>('mappings_box');
    final psList = box.values
        .where((e) => (e.distHi == district || e.distEn == district))
        .map((e) => e.psHi.isNotEmpty ? e.psHi : e.psEn)
        .where((element) => element.isNotEmpty)
        .toSet();
    return List<String>.from(psList)..sort();
  }

  List<String> getGramPanchayatsForPS(String district, String ps) {
    if (!Hive.isBoxOpen('mappings_box')) return [];
    final box = Hive.box<MappingModel>('mappings_box');
    final gpList = box.values
        .where((e) =>
            (e.distHi == district || e.distEn == district) &&
            (e.psHi == ps || e.psEn == ps))
        .map((e) => e.gpHi.isNotEmpty ? e.gpHi : e.gpEn)
        .where((element) => element.isNotEmpty)
        .toSet();
    return List<String>.from(gpList)..sort();
  }

  // Sync Unmapped entries with AI in 50-50 Batches
  Future<void> syncUnmappedWithAI({
    required Uint8List excelBytes,
    required Function(String status) onProgress,
  }) async {
    final box = Hive.box<MappingModel>('mappings_box');
    var excel = Excel.decodeBytes(excelBytes);
    var table = excel.tables[excel.tables.keys.first];
    if (table == null || table.rows.isEmpty) return;

    List<Data?> headerRow = table.rows.first;
    int colUnitName = -1;
    int colParentName = -1;
    int colDistrictName = -1;

    for (int i = 0; i < headerRow.length; i++) {
      String val = _clean(headerRow[i]?.value).toLowerCase();
      if (val.contains('unit name') || val.contains('gp name')) colUnitName = i;
      if (val.contains('parent name') || val.contains('panchayat samiti')) colParentName = i;
      if (val.contains('district')) colDistrictName = i;
    }

    List<Map<String, String>> unmappedList = [];
    Set<String> unmappedKeys = {};

    for (int r = 1; r < table.rows.length; r++) {
      var row = table.rows[r];
      if (row.isEmpty || colUnitName == -1 || row[colUnitName]?.value == null) continue;

      String gpEn = _clean(row[colUnitName]?.value);
      String psEn = colParentName != -1 ? _clean(row[colParentName]?.value) : '';
      String distEn = colDistrictName != -1 ? _clean(row[colDistrictName]?.value) : '';

      String normKey = "${_normalize(gpEn)}_${_normalize(psEn)}";

      if (!box.containsKey(normKey) && !unmappedKeys.contains(normKey) && gpEn.isNotEmpty) {
        unmappedKeys.add(normKey);
        unmappedList.add({
          "GP_EN": gpEn,
          "PS_EN": psEn.replaceAll(RegExp(r'(?i)panchayat samiti'), '').trim(),
          "DIST_EN": distEn,
        });
      }
    }

    if (unmappedList.isEmpty) {
      onProgress("Sabhi entries pehle se local DB me mapped hain!");
      return;
    }

    // 50-50 entries ke batches me AI ko send karna
    int batchSize = 50;
    int totalBatches = (unmappedList.length / batchSize).ceil();

    final model = ai.GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      generationConfig: ai.GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    for (int b = 0; b < totalBatches; b++) {
      int start = b * batchSize;
      int end = (start + batchSize < unmappedList.length) ? start + batchSize : unmappedList.length;
      var batch = unmappedList.sublist(start, end);

      onProgress("AI Mapping batch ${b + 1}/$totalBatches ($start to $end) process ho raha hai...");

      try {
        final prompt = '''
        You are an official administrative Hindi transliterator for Rajasthan Government documents.
        Convert the following list to official Hindi.

        Data: ${jsonEncode(batch)}

        Return ONLY a JSON Array:
        [
          {
            "GP_EN": "...",
            "GP_HI": "...",
            "PS_EN": "...",
            "PS_HI": "...",
            "DIST_EN": "...",
            "DIST_HI": "..."
          }
        ]
        ''';

        final response = await model.generateContent([ai.Content.text(prompt)]);
        String resText = response.text?.trim() ?? '';

        if (resText.startsWith("```json")) {
          resText = resText.substring(7, resText.length - 3).trim();
        } else if (resText.startsWith("```")) {
          resText = resText.substring(3, resText.length - 3).trim();
        }

        List<dynamic> parsedList = jsonDecode(resText);
        for (var item in parsedList) {
          String gpEn = item["GP_EN"] ?? "";
          String psEn = item["PS_EN"] ?? "";

          MappingModel newMapping = MappingModel(
            gpEn: gpEn,
            gpHi: item["GP_HI"] ?? gpEn,
            psEn: psEn,
            psHi: item["PS_HI"] ?? psEn,
            distEn: item["DIST_EN"] ?? "",
            distHi: item["DIST_HI"] ?? "बीकानेर",
          );

          await box.put(newMapping.keyName, newMapping);
        }
      } catch (e) {
        onProgress("Batch ${b + 1} Error: $e");
      }
    }
    onProgress("Sabhi ${unmappedList.length} Naye Records Save ho gaye hain!");
  }

  // Cover Letter DOCX Generator
  Future<List<String>> generateCoveringLetters({
    required Uint8List excelBytes,
    required Uint8List docxBytes,
    required String selectedDistrict,
    required String selectedPS,
    required List<String> selectedGPs,
    required bool isAllSelected,
    required String selectedYear,
    required Function(String status) onProgress,
  }) async {
    final box = Hive.box<MappingModel>('mappings_box');

    onProgress("Excel Processing...");
    var excel = Excel.decodeBytes(excelBytes);
    var table = excel.tables[excel.tables.keys.first];

    if (table == null || table.rows.isEmpty) return [];

    List<Data?> headerRow = table.rows.first;
    int colUnitName = -1, colParentName = -1, colDispatchName = -1, colParas = -1, colDate = -1;

    for (int i = 0; i < headerRow.length; i++) {
      String val = _clean(headerRow[i]?.value).toLowerCase();
      if (val.contains('unit name') || val.contains('gp name')) colUnitName = i;
      if (val.contains('parent name') || val.contains('panchayat samiti')) colParentName = i;
      if (val.contains('dispatch name') || val.contains('dispatch')) colDispatchName = i;
      if (val.contains('para')) colParas = i;
      if (val.contains('date') || val.contains('approval')) colDate = i;
    }

    final docxTemplate = await DocxTemplate.fromBytes(docxBytes);
    final outputDir = await getApplicationDocumentsDirectory();
    final saveFolder = Directory(p.join(outputDir.path, "Covering_Letters_${DateTime.now().millisecondsSinceEpoch}"));
    await saveFolder.create(recursive: true);

    List<String> generatedFilePaths = [];
    int letterCount = 0;

    for (int r = 1; r < table.rows.length; r++) {
      var row = table.rows[r];
      if (row.isEmpty || colUnitName == -1 || row[colUnitName]?.value == null) continue;

      String gpEn = _clean(row[colUnitName]?.value);
      String psEn = colParentName != -1 ? _clean(row[colParentName]?.value) : '';

      String normKey = "${_normalize(gpEn)}_${_normalize(psEn)}";
      MappingModel? mapItem = box.get(normKey);

      String currentGPHi = mapItem?.gpHi ?? gpEn;

      // Filtering Check
      if (!isAllSelected && !selectedGPs.contains(currentGPHi) && !selectedGPs.contains(gpEn)) {
        continue;
      }

      String dName = colDispatchName != -1 ? _clean(row[colDispatchName]?.value) : '';
      String dNo = _formatDispatchNo(dName);
      String dateVal = colDate != -1 ? _clean(row[colDate]?.value) : '06.10.26';
      String paraOriginal = colParas != -1 ? _clean(row[colParas]?.value) : '0';
      String paraPlus1 = _paraPlusOne(paraOriginal);

      String gpEngShort = gpEn.replaceAll(RegExp(r'^\s*gram\s+panchayat\s+', caseSensitive: false), '').trim();

      Content c = Content();
      c.add(TextContent("YEAR", selectedYear));
      c.add(TextContent("GP_NAME_EN", gpEn));
      c.add(TextContent("GP_NAME_ENG", gpEngShort));
      c.add(TextContent("GP_NAME_HI", "$currentGPHi ($gpEngShort)"));
      c.add(TextContent("PS_NAME_EN", mapItem?.psEn ?? selectedPS));
      c.add(TextContent("PS_NAME_HI", mapItem?.psHi ?? selectedPS));
      c.add(TextContent("DISTRICT_EN", mapItem?.distEn ?? selectedDistrict));
      c.add(TextContent("DISTRICT_HI", mapItem?.distHi ?? selectedDistrict));
      c.add(TextContent("DISPATCH_NO", dNo));
      c.add(TextContent("DISPATCH_NAME", dName));
      c.add(TextContent("DATE", dateVal));
      c.add(TextContent("PARA_COUNT", paraPlus1));
      c.add(TextContent("OFFICE_NAME", mapItem?.distHi ?? selectedDistrict));
      c.add(TextContent("DIVISION_NAME", mapItem?.distHi ?? selectedDistrict));
      c.add(TextContent("CONSTITUTION_OBJECTION", "0"));
      c.add(TextContent("SERIOUS_OBJECTION", "0"));
      c.add(TextContent("PARA_BREAKUP", paraOriginal));

      final docGenerated = await docxTemplate.generate(c);
      if (docGenerated != null) {
        letterCount++;
        String safeGpName = gpEngShort.replaceAll(RegExp(r'[^\w\-_\. ]'), '_');
        String fileName = "Cover_Letter_${safeGpName}_$selectedYear.docx";
        File file = File(p.join(saveFolder.path, fileName));
        await file.writeAsBytes(docGenerated);
        generatedFilePaths.add(file.path);
        
        onProgress("Letter $letterCount ($currentGPHi) generate ho chuka hai...");
      }
    }

    if (generatedFilePaths.isEmpty) return [];

    onProgress("Total $letterCount Letters Successfully Ready Hain!");
    return generatedFilePaths;
  }

  // Share to WhatsApp
  Future<void> shareToWhatsApp(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    final xFiles = filePaths.map((e) => XFile(e)).toList();
    await Share.shareXFiles(xFiles, text: 'INS RAMA - Covering Letters');
  }

  // Print PDF Helper
  Future<void> printPdfDocument(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}
