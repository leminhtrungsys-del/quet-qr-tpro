import 'package:hive/hive.dart';

/// Types of content a scanned code can represent.
/// Used to pick the right icon/label/action buttons on the Result screen.
enum ScanContentType {
  url,
  wifi,
  contact,
  email,
  phone,
  sms,
  text,
}

/// A single saved scan (or generated QR) entry, persisted locally via Hive.
///
/// NOTE: We hand-write the TypeAdapter below instead of relying on
/// `build_runner` code-gen, so this file works immediately after
/// copy-pasting — no `flutter pub run build_runner build` step required.
class ScanRecord extends HiveObject {
  final String rawValue;
  final String contentTypeName; // stores ScanContentType.name
  final DateTime timestamp;
  final String format; // e.g. "QR_CODE", "EAN_13", "CODE_128"
  final bool isGenerated; // true if created via the QR Generator tab

  ScanRecord({
    required this.rawValue,
    required this.contentTypeName,
    required this.timestamp,
    required this.format,
    this.isGenerated = false,
  });

  ScanContentType get contentType => ScanContentType.values.firstWhere(
        (e) => e.name == contentTypeName,
        orElse: () => ScanContentType.text,
      );
}

/// Hand-written Hive adapter for [ScanRecord]. Registered once in
/// `main.dart` via `Hive.registerAdapter(ScanRecordAdapter())`.
class ScanRecordAdapter extends TypeAdapter<ScanRecord> {
  @override
  final int typeId = 0;

  @override
  ScanRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanRecord(
      rawValue: fields[0] as String,
      contentTypeName: fields[1] as String,
      timestamp: fields[2] as DateTime,
      format: fields[3] as String,
      isGenerated: fields[4] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ScanRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.rawValue)
      ..writeByte(1)
      ..write(obj.contentTypeName)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.format)
      ..writeByte(4)
      ..write(obj.isGenerated);
  }
}
