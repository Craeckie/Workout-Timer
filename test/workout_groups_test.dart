import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/utils/workout.dart';
import 'package:just_another_workout_timer/utils/workout_groups.dart';

Workout _w(String title, {String category = '', int position = -1}) =>
    Workout(title: title, category: category, position: position);

List<String> _titles(Iterable<Workout> ws) => ws.map((w) => w.title).toList();

void main() {
  group('WorkoutGroups.categoryFromTitle', () {
    test('programme prefixes', () {
      expect(
        WorkoutGroups.categoryFromTitle('CC B W1-T1 Stufenintervalle'),
        'CC Beginner',
      );
      expect(
        WorkoutGroups.categoryFromTitle('CC F W10-T4 Supersätze'),
        'CC First Class',
      );
      expect(WorkoutGroups.categoryFromTitle('B W1-T3'), 'Beginner');
      expect(
        WorkoutGroups.categoryFromTitle('F W5-T2 Supersätze'),
        'First Class',
      );
      expect(WorkoutGroups.categoryFromTitle('FW5-T2 Supersätze'), 'First Class');
    });

    test('other titles stay uncategorized', () {
      expect(WorkoutGroups.categoryFromTitle('Workout'), '');
      expect(WorkoutGroups.categoryFromTitle('Beine'), '');
      expect(WorkoutGroups.categoryFromTitle('Full Body W1'), '');
      expect(WorkoutGroups.categoryFromTitle('CC X W1'), '');
    });
  });

  group('WorkoutGroups.group', () {
    test('keeps first-appearance order, uncategorized last', () {
      final groups = WorkoutGroups.group([
        _w('a', category: 'CC Beginner'),
        _w('x'),
        _w('b', category: 'First Class'),
        _w('c', category: 'CC Beginner'),
        _w('y'),
      ]);
      expect(groups.map((g) => g.category), [
        'CC Beginner',
        'First Class',
        '',
      ]);
      expect(_titles(groups[0].workouts), ['a', 'c']);
      expect(_titles(groups[2].workouts), ['x', 'y']);
      expect(_titles(WorkoutGroups.flatten(groups)), [
        'a',
        'c',
        'b',
        'x',
        'y',
      ]);
    });

    test('empty list gives no groups', () {
      expect(WorkoutGroups.group([]), isEmpty);
    });
  });

  group('WorkoutGroups.nextWorkout', () {
    final groups = WorkoutGroups.group([
      _w('B1', category: 'B'),
      _w('B2', category: 'B'),
      _w('F1', category: 'F'),
      _w('F2', category: 'F'),
    ]);

    test('next within the same category', () {
      expect(WorkoutGroups.nextWorkout(groups, 'B1')?.title, 'B2');
      expect(WorkoutGroups.nextWorkout(groups, 'F1')?.title, 'F2');
    });

    test('wraps to the start of the category, not into the next one', () {
      expect(WorkoutGroups.nextWorkout(groups, 'B2')?.title, 'B1');
      expect(WorkoutGroups.nextWorkout(groups, 'F2')?.title, 'F1');
    });

    test('unknown or missing last workout gives null', () {
      expect(WorkoutGroups.nextWorkout(groups, 'deleted'), isNull);
      expect(WorkoutGroups.nextWorkout(groups, null), isNull);
    });
  });

  group('WorkoutGroups.appendPositions', () {
    test('imported workouts go after the highest existing position', () {
      final existing = [_w('a', position: 0), _w('b', position: 55)];
      // positions from the file collide with the existing ones
      final imported = [_w('n1', position: 12), _w('n2', position: 13)];
      WorkoutGroups.appendPositions(existing, imported);
      expect(imported.map((w) => w.position), [56, 57]);
    });

    test('empty existing list starts at 0', () {
      final imported = [_w('n1', position: 30)];
      WorkoutGroups.appendPositions([], imported);
      expect(imported.single.position, 0);
    });
  });

  group('Workout.category JSON', () {
    test('roundtrip', () {
      final w = Workout.fromJson(_w('a', category: 'CC Beginner').toJson());
      expect(w.category, 'CC Beginner');
      expect(w.version, 3);
    });

    test('version 2 file without the key reads as uncategorized', () {
      final w = Workout.fromJson({
        'title': 'B W1-T1',
        'sets': <dynamic>[],
        'version': 2,
        'position': 4,
      });
      expect(w.category, '');
      expect(w.version, 2);
    });
  });
}
