import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:docx_template/docx_template.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/mapping_model.dart';

class DispatchService {
  final String geminiApiKey;

  DispatchService({required this.geminiApiKey});

  String _normalize(String input) {
    return input
        .replaceAll("Gram Panchayat ", "")
        .replaceAll("Panchayat Samiti ", "")
        .trim()
        .toLowerCase();
  }

  // ==========================================
  // LOCAL MAPPING DROPDOWN HELPERS
  // ==========================================

  /// Local Hive DB se saare Unique Districts ki List nikalna
  List<String> getAvailableDistricts() {
    if (!Hive.isBoxOpen('mappings_box')) return [];
    final box = Hive.box<MappingModel>('mappings_box');
    final districts = box.values
        .map((e) => e.distHi.isNotEmpty ? e.distHi : e.distEn)
        .where((element) => element.isNotEmpty)
        .toSet()
        .toList();
    districts.sort();
    return districts;
  }

  /// Selected District ke basis par Panchayat Samitis ki List
  List<String> getPanchayatSamitisForDistrict(String district) {
    if (!Hive.isBoxOpen('mappings_box')) return [];
    final box = Hive.box<MappingModel>('mappings_box');
    final psList = box.values
        .where((e) => (e.distHi == district || e.distEn == district))
        .map((e) => e.psHi.isNotEmpty ? e.psHi : e.psEn)
        .where((element) => element.isNotEmpty)
        .toSet()
        .toList();
    psList.sort();
    return psList;
  }

  /// Selected Panchayat Samiti ke basis par Gram Panchayats ki List
  List<String> getGramPanchayatsForPS(String district, String ps) {
    if (!Hive.isBoxOpen('mappings_box')) return [];
    final box = Hive.box<MappingModel>('mappings_box');
    final gpList = box.values
        .where((e) => 
            (e.distHi == district || e.distEn == district) &&
            (e.psHi == ps || e.psEn == ps))
        .map((e) => e.gpHi.isNotEmpty ? e.gpHi : e.gpEn)
        .where((element) => element.isNotEmpty)
        .toSet()
        .toList();
    gpList.sort();
    return gpList;
  }

  // ==========================================
  // DISPATCH PROCESSING LOGIC
  // ==========================================

  Future<String> processDispatchLocal({
    required Uint8List excelBytes,
    required Uint8List docxBytes,
    required String selectedYear,
    required Function(String status) onProgress,
  }) async {
    final box = Hive.box<MappingModel>('mappings_box');

    // 1. Read Excel File
    onProgress("Excel file padhi ja rahi hai...");
    var excel = Excel.decodeBytes(excelBytes);
    var table = excel.tables[excel.tables.keys.first];

    if (table == null || table.rows.isEmpty) {
      throw Exception("Excel file khaali hai ya format sahi nahi hai.");
    }

    // Header Columns Identify
    List<Data?> headerRow = table.rows.first;
    int colUnitName = -1;
    int colParentName = -1;
    int colDistrictName = -1;
    int colDispatchName = -1;
    int colAuditParty = -1;
    int colParas = -1;
    int colApprovalDate = -1;

    for (int i = 0; i < headerRow.length; i++) {
      String val = headerRow[i]?.value?.toString().trim() ?? '';
      if (val == 'Unit Name') colUnitName = i;
      if (val == 'Parent Name') colParentName = i;
      if (val == 'District Name') colDistrictName = i;
      if (val == 'Dispatch Name') colDispatchName = i;
      if (val == 'Audit Party No') colAuditParty = i;
      if (val == 'Converted to Para in Nos') colParas = i;
      if (val == 'Report Approval Date') colApprovalDate = i;
    }

    // 2. Identify Unmapped Entries
    onProgress("Local Master Database check ho raha hai...");
    List<Map<String, String>> unmappedList = [];
    Set<String> unmappedKeys = {};

    for (int r = 1; r < table.rows.length; r++) {
      var row = table.rows[r];
      if (row.isEmpty || colUnitName == -1 || row[colUnitName]?.value == null) continue;

      String gpEn = row[colUnitName]!.value.toString().trim();
      String psEn = colParentName != -1 ? (row[colParentName]?.value?.toString().trim() ?? '') : '';
      String distEn = colDistrictName != -1 ? (row[colDistrictName]?.value?.toString().trim() ?? '') : '';

      String normKey = "${_normalize(gpEn)}_${_normalize(psEn)}";

      if (!box.containsKey(normKey) && !unmappedKeys.contains(normKey) && gpEn.isNotEmpty) {
        unmappedKeys.add(normKey);
        unmappedList.add({
          "GP_EN": gpEn,
          "PS_EN": psEn.replaceAll("Panchayat Samiti ", "").trim(),
          "DIST_EN": distEn,
        });
      }
    }

    // 3. Gemini AI Transliteration (Unmapped items ke liye)
    if (unmappedList.isNotEmpty && geminiApiKey.isNotEmpty) {
      onProgress("${unmappedList.length} Nayi entries mili hain. Gemini AI se Hindi transliteration chal raha hai...");

      try {
        final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: geminiApiKey);
        final prompt = '''
        You are an official administrative Hindi transliterator for Rajasthan Government documents.
        Convert the following list to official Hindi.

        Data: ${jsonEncode(unmappedList)}

        Return ONLY a JSON Array with exact structure:
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

        final response = await model.generateContent([Content.text(prompt)]);
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

          // Save to Hive DB
          await box.put(newMapping.keyName, newMapping);
        }
        onProgress("Naye Hindi names Local DB mein save ho gaye hain.");
      } catch (e) {
        onProgress("AI Translation Warning: $e");
      }
    }

    // 4. DOCX Covering Letters Generation
    onProgress("Covering Letters generated ho rahe hain...");
    final docxTemplate = await DocxTemplate.fromBytes(docxBytes);

    final outputDir = await getApplicationDocumentsDirectory();
    final saveFolder = Directory(p.join(outputDir.path, "Covering_Letters_${DateTime.now().millisecondsSinceEpoch}"));
    await saveFolder.create(recursive: true);

    int generatedCount = 0;

    for (int r = 1; r < table.rows.length; r++) {
      var row = table.rows[r];
      if (row.isEmpty || colUnitName == -1 || row[colUnitName]?.value == null) continue;

      String gpEn = row[colUnitName]!.value.toString().trim();
      String psEn = colParentName != -1 ? (row[colParentName]?.value?.toString().trim() ?? '') : '';
      String normKey = "${_normalize(gpEn)}_${_normalize(psEn)}";

      MappingModel? mapItem = box.get(normKey);

      String dispatchNo = colDispatchName != -1 ? (row[colDispatchName]?.value?.toString().trim() ?? '') : '';
      String dateStr = colApprovalDate != -1 ? (row[colApprovalDate]?.value?.toString().trim() ?? '06/10/2026') : '06/10/2026';
      int paraCount = colParas != -1 ? int.tryParse(row[colParas]?.value?.toString() ?? '0') ?? 0 : 0;

      // Fill Content Context
      Content c = Content();
      c.add(TextContent("OFFICE_NAME", mapItem?.distHi ?? 'बीकानेर'));
      c.add(TextContent("DIVISION_NAME", mapItem?.distHi ?? 'बीकानेर'));
      c.add(TextContent("YEAR", selectedYear));
      c.add(TextContent("DISPATCH_NO", dispatchNo));
      c.add(TextContent("DATE", dateStr));
      c.add(TextContent("PS_NAME_HI", mapItem?.psHi ?? psEn));
      c.add(TextContent("DISTRICT_HI", mapItem?.distHi ?? 'बीकानेर'));
      c.add(TextContent("GP_NAME_HI", mapItem?.gpHi ?? gpEn));
      c.add(TextContent("PARA_COUNT", paraCount.toString()));
      c.add(TextContent("PARA_BREAKUP", paraCount > 0 ? "आक्षेप सं. 1 से $paraCount" : "आक्षेप सं. 0"));

      final docGenerated = await docxTemplate.generate(c);
      if (docGenerated != null) {
        String safeName = gpEn.replaceAll(RegExp(r'[^\w\-_\. ]'), '_');
        File outFile = File(p.join(saveFolder.path, "Covering_Letter_$safeName.docx"));
        await outFile.writeAsBytes(docGenerated);
        generatedCount++;
      }
    }

    return "$generatedCount Files successfully save ho gayi hain: ${saveFolder.path}";
  }
}
