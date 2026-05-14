import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/utils/workout.dart' as w;

void main() {
  group('Exercise', () {
    test('default name and duration', () {
      final e = w.Exercise();
      expect(e.name, 'Exercise');
      expect(e.duration, 30);
    });

    test('auto-generates id when not provided', () {
      final e = w.Exercise();
      expect(e.id, isNotEmpty);
    });

    test('two exercises have different ids', () {
      expect(w.Exercise().id, isNot(w.Exercise().id));
    });

    test('JSON roundtrip preserves fields', () {
      final e = w.Exercise(id: 'abc', name: 'Push-up', duration: 45);
      final copy = w.Exercise.fromJson(e.toJson());
      expect(copy.id, e.id);
      expect(copy.name, e.name);
      expect(copy.duration, e.duration);
    });

    test('fromJson — missing required name throws', () {
      expect(() => w.Exercise.fromJson({'duration': 30}), throwsA(anything));
    });

    test('fromJson — missing required duration throws', () {
      expect(() => w.Exercise.fromJson({'name': 'Push-up'}), throwsA(anything));
    });

    test('fromJson — missing id is auto-generated', () {
      final e = w.Exercise.fromJson({'name': 'Push-up', 'duration': 30});
      expect(e.id, isNotEmpty);
    });
  });

  group('Set.duration', () {
    test('single exercise, 1 rep', () {
      final s = w.Set(exercises: [w.Exercise(duration: 30)], repetitions: 1);
      expect(s.duration, 30);
    });

    test('two exercises, 1 rep', () {
      final s = w.Set(
        exercises: [w.Exercise(duration: 10), w.Exercise(duration: 20)],
        repetitions: 1,
      );
      expect(s.duration, 30);
    });

    test('two exercises, 2 reps', () {
      final s = w.Set(
        exercises: [w.Exercise(duration: 10), w.Exercise(duration: 10)],
        repetitions: 2,
      );
      expect(s.duration, 40);
    });

    test('zero reps gives zero duration', () {
      final s = w.Set(exercises: [w.Exercise(duration: 30)], repetitions: 0);
      expect(s.duration, 0);
    });

    test('JSON roundtrip preserves repetitions and exercises', () {
      final s = w.Set(
        id: 'set-1',
        exercises: [w.Exercise(id: 'e-1', name: 'Squat', duration: 20)],
        repetitions: 3,
      );
      final copy = w.Set.fromJson(s.toJson());
      expect(copy.id, s.id);
      expect(copy.repetitions, s.repetitions);
      expect(copy.exercises.first.name, s.exercises.first.name);
    });

    test('fromJson — missing required repetitions throws', () {
      expect(
        () => w.Set.fromJson({'exercises': []}),
        throwsA(anything),
      );
    });
  });

  group('Workout.duration', () {
    test('single set', () {
      final workout = w.Workout(
        sets: [
          w.Set(exercises: [w.Exercise(duration: 30)], repetitions: 1),
        ],
      );
      expect(workout.duration, 30);
    });

    test('multiple sets summed', () {
      final workout = w.Workout(
        sets: [
          w.Set(exercises: [w.Exercise(duration: 10)], repetitions: 2),
          w.Set(exercises: [w.Exercise(duration: 15)], repetitions: 1),
        ],
      );
      expect(workout.duration, 35);
    });

    test('empty sets list gives zero', () {
      final workout = w.Workout(sets: []);
      expect(workout.duration, 0);
    });
  });

  group('Workout.cleanUp', () {
    test('removes sets with empty exercises', () {
      final workout = w.Workout(
        sets: [
          w.Set(exercises: [], repetitions: 1),
          w.Set(exercises: [w.Exercise()], repetitions: 1),
        ],
      );
      workout.cleanUp();
      expect(workout.sets.length, 1);
      expect(workout.sets.first.exercises.isNotEmpty, isTrue);
    });

    test('non-empty set is unchanged', () {
      final workout = w.Workout(
        sets: [w.Set(exercises: [w.Exercise()], repetitions: 1)],
      );
      workout.cleanUp();
      expect(workout.sets.length, 1);
    });

    test('all empty — results in empty sets list', () {
      final workout = w.Workout(
        sets: [w.Set(exercises: [], repetitions: 1)],
      );
      workout.cleanUp();
      expect(workout.sets, isEmpty);
    });
  });

  group('Workout JSON', () {
    test('roundtrip preserves all fields', () {
      final original = w.Workout(
        title: 'My Workout',
        position: 3,
        sets: [
          w.Set(
            id: 's-1',
            exercises: [w.Exercise(id: 'e-1', name: 'Burpee', duration: 45)],
            repetitions: 2,
          ),
        ],
      );
      final copy = w.Workout.fromJson(original.toJson());
      expect(copy.title, original.title);
      expect(copy.position, original.position);
      expect(copy.sets.length, original.sets.length);
      expect(copy.sets.first.repetitions, original.sets.first.repetitions);
      expect(copy.sets.first.exercises.first.name, 'Burpee');
    });

    test('fromJson — null title coalesces to default "Workout"', () {
      final workout = w.Workout.fromJson({'title': null, 'sets': []});
      expect(workout.title, 'Workout');
    });

    test('fromJson — missing position defaults to -1', () {
      final workout = w.Workout.fromJson({'title': 'T', 'sets': []});
      expect(workout.position, -1);
    });

    test('fromJson — missing required sets throws', () {
      expect(() => w.Workout.fromJson({'title': 'T'}), throwsA(anything));
    });

    test('fromJson — missing required title key throws', () {
      expect(() => w.Workout.fromJson({'sets': []}), throwsA(anything));
    });
  });

  group('Backup', () {
    test('roundtrip preserves workouts list', () {
      final backup = w.Backup(
        workouts: [
          w.Workout(title: 'A', sets: []),
          w.Workout(title: 'B', sets: []),
        ],
      );
      final json = jsonEncode(backup.toJson());
      final copy = w.Backup.fromJson(jsonDecode(json));
      expect(copy.workouts.length, 2);
      expect(copy.workouts.map((w) => w.title).toList(), ['A', 'B']);
    });

    test('fromJson — missing required workouts throws', () {
      expect(() => w.Backup.fromJson({}), throwsA(anything));
    });

    test('history roundtrips through JSON', () {
      final backup = w.Backup(
        workouts: [w.Workout(title: 'A', sets: [])],
        history: [
          w.HistoryEntry(
            title: 'A',
            completedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
          ),
          w.HistoryEntry(
            title: 'B',
            completedAt: DateTime.utc(2026, 1, 3, 0, 0, 0),
          ),
        ],
      );
      final copy = w.Backup.fromJson(jsonDecode(jsonEncode(backup.toJson())));
      expect(copy.history, isNotNull);
      expect(copy.history!.length, 2);
      expect(copy.history!.first.title, 'A');
      expect(
        copy.history!.first.completedAt.toUtc(),
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
    });

    test('history omitted from JSON when null (back-compat with old backups)',
        () {
      final backup = w.Backup(workouts: [w.Workout(title: 'A', sets: [])]);
      final json = backup.toJson();
      expect(json.containsKey('history'), isFalse);
    });

    test('fromJson — backup without history field decodes (back-compat)', () {
      final copy = w.Backup.fromJson({
        'workouts': [
          {'title': 'A', 'sets': []},
        ],
      });
      expect(copy.history, isNull);
      expect(copy.workouts.single.title, 'A');
    });

    test('byte roundtrip preserves umlauts (regression: .codeUnits bug)', () {
      // Backups used to be written as `jsonEncode(...).codeUnits`, which
      // truncates UTF-16 to bytes and produces Latin-1 for chars like ä/ö/ü.
      // Re-reading those bytes as UTF-8 replaces them with U+FFFD. Exports
      // must encode as proper UTF-8 so a UTF-8 read decodes them intact.
      final backup = w.Backup(
        workouts: [
          w.Workout(
            title: 'Liegestütz',
            sets: [
              w.Set(
                exercises: [w.Exercise(name: 'Türziehen', duration: 30)],
                repetitions: 1,
              ),
            ],
          ),
        ],
      );

      final bytes = utf8.encode(jsonEncode(backup.toJson()));
      final decoded = w.Backup.fromJson(jsonDecode(utf8.decode(bytes)));

      expect(decoded.workouts.first.title, 'Liegestütz');
      expect(decoded.workouts.first.sets.first.exercises.first.name, 'Türziehen');
      expect(utf8.decode(bytes), isNot(contains('�')));
    });

    test('legacy .codeUnits bytes are recoverable as Latin-1', () {
      // Legacy export path: jsonEncode(...).codeUnits. For BMP chars <= 0xFF
      // (German umlauts), this is exactly Latin-1 — invalid UTF-8, but
      // round-trips losslessly through latin1.decode.
      final original = w.Backup(
        workouts: [w.Workout(title: 'Liegestütz Türziehen Maß', sets: [])],
      );
      final legacyBytes = jsonEncode(original.toJson()).codeUnits;

      expect(
        () => utf8.decode(legacyBytes),
        throwsA(isA<FormatException>()),
        reason: 'legacy bytes must not be valid UTF-8',
      );

      final recovered = w.Backup.fromJson(jsonDecode(latin1.decode(legacyBytes)));
      expect(recovered.workouts.single.title, 'Liegestütz Türziehen Maß');
    });
  });
}
