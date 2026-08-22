import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/ocr_models.dart';

class HistoryRepository {
  static const _boxName = 'ocr_history';
  late Box _box;
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }
  List<HistoryItem> all() => _box.values.map((v) {
        final m = Map<String, dynamic>.from(v as Map);
        return HistoryItem(id: m['id'], path: m['path'], text: m['text'], createdAt: DateTime.parse(m['createdAt']), title: m['title'] ?? 'Scan');
      }).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  Future<void> save(HistoryItem item) => _box.put(item.id, {'id': item.id, 'path': item.path, 'text': item.text, 'createdAt': item.createdAt.toIso8601String(), 'title': item.title});
  Future<void> delete(String id) => _box.delete(id);
  Future<void> clear() => _box.clear();
}
