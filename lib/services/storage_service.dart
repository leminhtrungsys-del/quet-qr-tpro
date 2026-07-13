import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_record.dart';

/// Wraps a local Hive box holding [ScanRecord] history.
///
/// Call [StorageService.init] once in `main()` before `runApp`.
class StorageService {
  StorageService._();

  static const String _boxName = 'scan_history';
  static Box<ScanRecord>? _box;

  /// Opens the Hive box. Must be awaited before any other method is used.
  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ScanRecordAdapter());
    }
    _box = await Hive.openBox<ScanRecord>(_boxName);
  }

  static Box<ScanRecord> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('StorageService.init() must be called before use.');
    }
    return box;
  }

  /// Returns all history items, newest first.
  static List<ScanRecord> getAll() {
    final items = _requireBox.values.toList();
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  static Future<void> add(ScanRecord record) async {
    await _requireBox.add(record);
  }

  static Future<void> delete(ScanRecord record) async {
    await record.delete();
  }

  static Future<void> clearAll() async {
    await _requireBox.clear();
  }

  /// Live-updating stream of the box so UI (e.g. ValueListenableBuilder)
  /// can react to changes without manual setState plumbing.
  static ValueListenable<Box<ScanRecord>> listenable() {
    return _requireBox.listenable();
  }
}
