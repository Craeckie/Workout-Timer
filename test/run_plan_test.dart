import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/utils/run_plan.dart';
import 'package:just_another_workout_timer/utils/workout.dart' as w;

void main() {
  group('RunPlan.of', () {
    test('single set, single rep: one step per exercise, no boundaries', () {
      final workout = w.Workout(
        sets: [
          w.Set(
            repetitions: 1,
            exercises: [
              w.Exercise(name: 'A', duration: 10),
              w.Exercise(name: 'B', duration: 20),
            ],
          ),
        ],
      );

      final plan = RunPlan.of(workout);

      expect(plan.steps.length, 2);
      expect(plan.steps[0].exercise.name, 'A');
      expect(plan.steps[0].boundary, StepBoundary.none);
      expect(plan.steps[1].exercise.name, 'B');
      expect(plan.steps[1].boundary, StepBoundary.none);
    });

    test('startSecond accumulates exercise durations in order', () {
      final workout = w.Workout(
        sets: [
          w.Set(
            repetitions: 1,
            exercises: [
              w.Exercise(name: 'A', duration: 10),
              w.Exercise(name: 'B', duration: 20),
              w.Exercise(name: 'C', duration: 5),
            ],
          ),
        ],
      );

      final plan = RunPlan.of(workout);

      expect(plan.steps[0].startSecond, 0);
      expect(plan.steps[1].startSecond, 10);
      expect(plan.steps[2].startSecond, 30);
    });

    test('wrapping to the next repetition is boundary newRep', () {
      final workout = w.Workout(
        sets: [
          w.Set(
            repetitions: 2,
            exercises: [
              w.Exercise(name: 'A', duration: 10),
              w.Exercise(name: 'B', duration: 20),
            ],
          ),
        ],
      );

      final plan = RunPlan.of(workout);

      expect(plan.steps.length, 4);
      expect(plan.steps[0].boundary, StepBoundary.none); // A, rep 0
      expect(plan.steps[1].boundary, StepBoundary.none); // B, rep 0
      expect(plan.steps[2].boundary, StepBoundary.newRep); // A, rep 1
      expect(plan.steps[2].rep, 1);
      expect(plan.steps[3].boundary, StepBoundary.none); // B, rep 1
    });

    test('moving to the next set is boundary newSet', () {
      final workout = w.Workout(
        sets: [
          w.Set(repetitions: 1, exercises: [w.Exercise(name: 'A')]),
          w.Set(repetitions: 1, exercises: [w.Exercise(name: 'B')]),
        ],
      );

      final plan = RunPlan.of(workout);

      expect(plan.steps[0].boundary, StepBoundary.none);
      expect(plan.steps[1].boundary, StepBoundary.newSet);
      expect(plan.steps[1].setIndex, 1);
    });

    test('first step of the whole workout has boundary none', () {
      final workout = w.Workout(
        sets: [
          w.Set(repetitions: 3, exercises: [w.Exercise(name: 'A')]),
        ],
      );

      final plan = RunPlan.of(workout);

      expect(plan.steps.first.boundary, StepBoundary.none);
    });

    test('totalDuration matches Workout.duration', () {
      final workout = w.Workout(
        sets: [
          w.Set(
            repetitions: 3,
            exercises: [
              w.Exercise(name: 'A', duration: 10),
              w.Exercise(name: 'B', duration: 15),
            ],
          ),
          w.Set(
            repetitions: 2,
            exercises: [w.Exercise(name: 'C', duration: 45)],
          ),
        ],
      );

      final plan = RunPlan.of(workout);

      expect(plan.totalDuration, workout.duration);
    });

    test('rows contain a header before the first step of every repetition',
        () {
      final workout = w.Workout(
        sets: [
          w.Set(
            repetitions: 2,
            exercises: [
              w.Exercise(name: 'A'),
              w.Exercise(name: 'B'),
            ],
          ),
        ],
      );

      final plan = RunPlan.of(workout);

      // header, A, B, header, A, B
      expect(plan.rows.length, 6);
      expect(plan.rows[0], isA<TimelineHeaderRow>());
      expect(plan.rows[1], isA<TimelineStepRow>());
      expect(plan.rows[2], isA<TimelineStepRow>());
      expect(plan.rows[3], isA<TimelineHeaderRow>());
      expect(plan.rows[4], isA<TimelineStepRow>());
      expect(plan.rows[5], isA<TimelineStepRow>());

      final header = plan.rows[3] as TimelineHeaderRow;
      expect(header.rep, 1);
      expect(header.repCount, 2);
    });

    test('rowIndexOfStep maps each step to its row in rows', () {
      final workout = w.Workout(
        sets: [
          w.Set(
            repetitions: 2,
            exercises: [w.Exercise(name: 'A'), w.Exercise(name: 'B')],
          ),
        ],
      );

      final plan = RunPlan.of(workout);

      for (var i = 0; i < plan.steps.length; i++) {
        final row = plan.rows[plan.rowIndexOfStep(i)];
        expect(row, isA<TimelineStepRow>());
        expect((row as TimelineStepRow).stepIndex, i);
      }
    });
  });
}
