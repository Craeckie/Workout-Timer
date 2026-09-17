// Parses externally generated backup files through the app's own model, so a
// file produced by a script can be checked before importing it on a device.
//
//   BACKUP_FILES=path/a.json:path/b.json flutter test test/backup_file_test.dart
//
// Skipped when BACKUP_FILES is not set.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/utils/workout.dart';

void main() {
  final files = (Platform.environment['BACKUP_FILES'] ?? '')
      .split(':')
      .where((f) => f.isNotEmpty)
      .toList();

  test(
    'BACKUP_FILES parse as Backup',
    () {
      for (final f in files) {
        final json =
            jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>;
        final backup = Backup.fromJson(json);
        expect(backup.workouts, isNotEmpty, reason: f);
        final titles = <String>{};
        for (final w in backup.workouts) {
          expect(w.version, Workout.fileVersion, reason: '$f: ${w.title}');
          expect(
            titles.add(w.title),
            isTrue,
            reason: '$f: duplicate ${w.title}',
          );
          expect(w.sets, isNotEmpty, reason: '$f: ${w.title}');
          for (final s in w.sets) {
            expect(s.repetitions, greaterThan(0), reason: '$f: ${w.title}');
            expect(s.exercises, isNotEmpty, reason: '$f: ${w.title}');
            for (final e in s.exercises) {
              expect(e.name, isNotEmpty, reason: '$f: ${w.title}');
              expect(
                e.name.length,
                lessThanOrEqualTo(60),
                reason: '$f: ${w.title}: ${e.name}',
              );
              expect(
                e.duration,
                greaterThan(0),
                reason: '$f: ${w.title}: ${e.name}',
              );
            }
          }
          // ignore: avoid_print
          print('${w.title}: ${w.duration}s, ${w.sets.length} sets');
        }
      }
    },
    skip: files.isEmpty ? 'set BACKUP_FILES=a.json:b.json' : false,
  );
}
