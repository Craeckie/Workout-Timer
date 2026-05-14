import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/utils/utils.dart';
import 'package:just_another_workout_timer/utils/workout.dart' as w;

void main() {
  group('Utils.formatSeconds', () {
    test('zero', () => expect(Utils.formatSeconds(0), '00:00'));
    test('30 seconds', () => expect(Utils.formatSeconds(30), '00:30'));
    test('59 seconds', () => expect(Utils.formatSeconds(59), '00:59'));
    test('exactly one minute', () => expect(Utils.formatSeconds(60), '01:00'));
    test('65 seconds', () => expect(Utils.formatSeconds(65), '01:05'));
    test('90 seconds', () => expect(Utils.formatSeconds(90), '01:30'));
    test('59:59', () => expect(Utils.formatSeconds(3599), '59:59'));
    test('does not display hours — 61:01', () => expect(Utils.formatSeconds(3661), '61:01'));
  });

  group('Utils.removeSpecialChar', () {
    test('empty string', () => expect(Utils.removeSpecialChar(''), ''));
    test('alphanumeric unchanged', () => expect(Utils.removeSpecialChar('abc123'), 'abc123'));
    test('space becomes underscore', () => expect(Utils.removeSpecialChar('hello world'), 'hello_world'));
    test('exclamation becomes underscore', () => expect(Utils.removeSpecialChar('My Workout!'), 'My_Workout_'));
    test('unicode becomes underscore', () => expect(Utils.removeSpecialChar('héllo'), 'h_llo'));
    test('all special chars', () => expect(Utils.removeSpecialChar('!@#\$'), '____'));
    test('mixed', () => expect(Utils.removeSpecialChar('Workout-1 (A)'), 'Workout_1__A_'));
  });

  group('Utils.sortWorkouts', () {
    w.Workout make(String title, int position) =>
        w.Workout(title: title, sets: [], position: position);

    test('all with positions — sorted numerically', () {
      final list = [make('C', 3), make('A', 1), make('B', 2)];
      final result = Utils.sortWorkouts(list);
      expect(result.map((w) => w.title).toList(), ['A', 'B', 'C']);
    });

    test('all without positions — sorted by title naturally', () {
      final list = [
        make('Workout 10', -1),
        make('Workout 2', -1),
        make('Workout 1', -1),
      ];
      final result = Utils.sortWorkouts(list);
      expect(result.map((w) => w.title).toList(), ['Workout 1', 'Workout 2', 'Workout 10']);
    });

    test('returns the same list object (mutates in-place)', () {
      final list = [make('B', -1), make('A', -1)];
      final result = Utils.sortWorkouts(list);
      expect(identical(result, list), isTrue);
    });

    test('single workout unchanged', () {
      final list = [make('Solo', 0)];
      expect(Utils.sortWorkouts(list).first.title, 'Solo');
    });
  });
}
