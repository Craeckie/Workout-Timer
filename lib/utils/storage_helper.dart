import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prefs/prefs.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/workout.dart';
import 'history_helper.dart';
import 'migrations.dart';
import 'utils.dart';

Future<Map<String, dynamic>> _dumpSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (var key in prefs.getKeys()) key: prefs.get(key)};
}

Future<void> _restoreSettings(Map<String, dynamic> settings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  for (final entry in settings.entries) {
    final value = entry.value;
    if (value is bool) {
      await prefs.setBool(entry.key, value);
    } else if (value is int) {
      await prefs.setInt(entry.key, value);
    } else if (value is double) {
      await prefs.setDouble(entry.key, value);
    } else if (value is String) {
      await prefs.setString(entry.key, value);
    } else if (value is List) {
      await prefs.setStringList(entry.key, value.cast<String>());
    }
  }
}

Future<String> get localPath async {
  final directory = await getExternalStorageDirectory();
  await Directory('${directory!.path}/workouts').create();

  return directory.path;
}

Future<File> _loadWorkoutFile(String title) async {
  final path = await localPath;
  return File('$path/workouts/${Utils.removeSpecialChar(title)}.json');
}

Future<void> exportWorkout(String title) async {
  var workout = await loadWorkout(title: title);
  var backup = Backup(workouts: [workout]);
  final params = SaveFileDialogParams(
    data: Uint8List.fromList(utf8.encode(jsonEncode(backup.toJson()))),
    fileName: '${Utils.removeSpecialChar(title)}.json',
  );
  await FlutterFileDialog.saveFile(params: params);
}

Future<void> shareWorkout(String title) async {
  final path = await localPath;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile('$path/workouts/${Utils.removeSpecialChar(title)}.json')],
      text: title,
    ),
  );
}

Future<void> exportAllWorkouts() async {
  var backup = Backup(
    workouts: await getAllWorkouts(),
    history: await loadHistory(),
    settings: await _dumpSettings(),
  );
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final params = SaveFileDialogParams(
    data: Uint8List.fromList(utf8.encode(jsonEncode(backup.toJson()))),
    fileName: 'WorkoutTimer_$today.json',
  );
  await FlutterFileDialog.saveFile(params: params);
}

Future<String?> pickFile() async {
  const params = OpenFileDialogParams(
    dialogType: OpenFileDialogType.document,
    fileExtensionsFilter: ['json'],
    allowEditing: false,
  );
  return FlutterFileDialog.pickFile(params: params);
}

enum ImportMode { merge, overwrite }

Future<int> importFile(bool fromBackup, {ImportMode mode = ImportMode.merge}) async {
  String? filePath = await pickFile();
  if (filePath != null && filePath.isNotEmpty) {
    String content;
    var file = File(filePath);
    try {
      content = await file.readAsString();
    } on FileSystemException {
      // readAsString wraps UTF-8 decode errors as FileSystemException.
      // Older app versions wrote backups with String.codeUnits, which for
      // BMP characters <= 0xFF (German umlauts etc.) is exactly Latin-1 —
      // valid in Latin-1 but invalid UTF-8. Decoding as Latin-1 recovers
      // the original characters losslessly.
      var bytes = await file.readAsBytes();
      content = latin1.decode(bytes);
    }

    if (fromBackup) {
      var backup = Backup.fromJson(jsonDecode(content));
      List<Workout> toImport;
      if (mode == ImportMode.overwrite) {
        for (var existing in await getAllWorkouts()) {
          await deleteWorkout(existing.title);
        }
        toImport = backup.workouts;
      } else {
        toImport = [];
        for (var w in backup.workouts) {
          if (!await workoutExists(w.title)) toImport.add(w);
        }
      }
      await Future.wait(toImport.map(writeWorkout));
      if (backup.history != null) {
        await addHistoryEntries(backup.history!);
      }
      // Settings only restored on overwrite — merge keeps the user's current setup.
      if (mode == ImportMode.overwrite && backup.settings != null) {
        await _restoreSettings(backup.settings!);
      }
      await Migrations.runMigrations();
      return Future.value(toImport.length);
    } else {
      var workout = Workout.fromJson(jsonDecode(content));
      writeWorkout(workout, fixDuplicates: true);
      return Future.value(1);
    }
  } else {
    return Future.value(0);
  }
}

Future<void> writeWorkout(Workout workout, {bool fixDuplicates = false}) async {
  if (fixDuplicates) {
    var counter = 2;
    var newTitle = workout.title;

    while (await workoutExists(newTitle)) {
      newTitle = '${workout.title}($counter)';
      counter++;
    }
    workout.title = newTitle;
  }

  final file = await _loadWorkoutFile(workout.title);

  file.writeAsString(jsonEncode(workout.toJson()), flush: true);
}

Future<bool> workoutExists(String title) async {
  final file = await _loadWorkoutFile(title);
  return file.exists();
}

Future<Workout> loadWorkout({String? title, File? workoutFile}) async {
  final file = workoutFile ?? await _loadWorkoutFile(title!);
  var contents = await file.readAsString();

  return Workout.fromJson(jsonDecode(contents));
}

Future<void> deleteWorkout(String title) async {
  try {
    final file = await _loadWorkoutFile(title);
    file.delete();
    // ignore: empty_catches
  } on Exception {}
}

Future<void> createBackup() async {
  final path = await localPath;

  var dir = Directory('$path/workouts');
  var dirbak = Directory('$path/backup');
  try {
    dirbak.deleteSync();
  } on Exception catch (_) {}
  dirbak.createSync();

  Utils.copyDirectory(dir, dirbak);
  var backup = Backup(
    workouts: await getAllWorkouts(),
    history: await loadHistory(),
    settings: await _dumpSettings(),
  );
  var backupfile = File('${dirbak.path}/backup.json');
  backupfile.writeAsBytesSync(
    Uint8List.fromList(utf8.encode(jsonEncode(backup.toJson()))),
  );
}

Future<List<Workout>> getAllWorkouts() async {
  final path = await localPath;

  var dir = Directory('$path/workouts');
  var titles = dir
      .listSync()
      .map((e) => e.path.split("/").last.split(".").first)
      .toList();
  var list =
      (await Future.wait(titles.map((t) async => await loadWorkout(title: t))));
  return Utils.sortWorkouts(list);
}
