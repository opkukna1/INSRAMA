import 'package:hive/hive.dart';

part 'mapping_model.g.dart';

@HiveType(typeId: 0)
class MappingModel extends HiveObject {
  @HiveField(0)
  String gpEn;

  @HiveField(1)
  String gpHi;

  @HiveField(2)
  String psEn;

  @HiveField(3)
  String psHi;

  @HiveField(4)
  String distEn;

  @HiveField(5)
  String distHi;

  MappingModel({
    required this.gpEn,
    required this.gpHi,
    required this.psEn,
    required this.psHi,
    required this.distEn,
    required this.distHi,
  });

  // Unique lookup key (normalized)
  String get keyName => "${_normalize(gpEn)}_${_normalize(psEn)}";

  static String _normalize(String input) {
    return input
        .replaceAll("Gram Panchayat ", "")
        .replaceAll("Panchayat Samiti ", "")
        .trim()
        .toLowerCase();
  }
}
