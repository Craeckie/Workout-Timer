import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'workout.dart';

Future<File> _historyFile() async {
  final directory = await getExternalStorageDirectory();
  return File('${directory!.path}/history.json');
}

Future<List<HistoryEntry>> loadHistory() async {
  final file = await _historyFile();
  if (!await file.exists()) return [];
  final contents = await file.readAsString();
  if (contents.trim().isEmpty) return [];
  final decoded = jsonDecode(contents) as List<dynamic>;
  return decoded
      .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> _writeHistory(List<HistoryEntry> entries) async {
  final file = await _historyFile();
  await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
}

Future<void> appendHistoryEntry(String title) async {
  final entries = await loadHistory();
  entries.add(HistoryEntry(title: title, completedAt: DateTime.now()));
  await _writeHistory(entries);
}

/// Merge [incoming] into the on-disk history, dropping entries that already
/// exist (same title + completedAt). Returns the number of entries actually
/// added. Used when importing a backup so re-importing the same file is a
/// no-op rather than a duplication.
Future<int> addHistoryEntries(List<HistoryEntry> incoming) async {
  if (incoming.isEmpty) return 0;
  final existing = await loadHistory();
  final seen = existing
      .map((e) => '${e.title}|${e.completedAt.toIso8601String()}')
      .toSet();
  var added = 0;
  for (final entry in incoming) {
    final key = '${entry.title}|${entry.completedAt.toIso8601String()}';
    if (seen.add(key)) {
      existing.add(entry);
      added++;
    }
  }
  if (added > 0) await _writeHistory(existing);
  return added;
}

Future<void> deleteHistoryEntry(int index) async {
  final entries = await loadHistory();
  if (index < 0 || index >= entries.length) return;
  entries.removeAt(index);
  await _writeHistory(entries);
}

Future<void> clearHistory() async {
  final file = await _historyFile();
  if (await file.exists()) await file.delete();
}
