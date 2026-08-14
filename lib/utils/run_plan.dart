import 'workout.dart';

/// how a step relates to the one immediately before it
enum StepBoundary {
  /// same set, same repetition, next exercise
  none,

  /// same set, wrapped around to the next repetition
  newRep,

  /// moved on to the next set
  newSet,
}

/// one exercise occurrence in the fully expanded run order
class RunStep {
  RunStep({
    required this.exercise,
    required this.setIndex,
    required this.set,
    required this.rep,
    required this.exerciseIndex,
    required this.startSecond,
    required this.boundary,
  });

  final Exercise exercise;
  final int setIndex;
  final Set set;

  /// 0-based repetition of [set] this step belongs to
  final int rep;

  /// index of [exercise] within [set.exercises]
  final int exerciseIndex;

  /// offset in seconds from workout start (excludes the countdown lead-in)
  final int startSecond;

  final StepBoundary boundary;
}

sealed class TimelineRow {}

/// group header shown above the first step of a set repetition
class TimelineHeaderRow extends TimelineRow {
  TimelineHeaderRow({
    required this.setIndex,
    required this.setCount,
    required this.rep,
    required this.repCount,
  });

  final int setIndex;
  final int setCount;
  final int rep;
  final int repCount;
}

class TimelineStepRow extends TimelineRow {
  TimelineStepRow(this.stepIndex, this.step);

  final int stepIndex;
  final RunStep step;
}

/// fully expanded, flat run order for a [Workout]: every repetition of every
/// set materialised into individual steps, so callers don't need to reason
/// about nested sets/repetitions themselves
class RunPlan {
  RunPlan._(this.steps, this.rows, this._rowIndexOfStep);

  final List<RunStep> steps;
  final List<TimelineRow> rows;
  final List<int> _rowIndexOfStep;

  int get totalDuration =>
      steps.fold(0, (sum, step) => sum + step.exercise.duration);

  /// index into [rows] of the row representing steps[stepIndex]
  int rowIndexOfStep(int stepIndex) => _rowIndexOfStep[stepIndex];

  factory RunPlan.of(Workout workout) {
    final steps = <RunStep>[];
    var currentSecond = 0;

    workout.sets.asMap().forEach((setIndex, set) {
      for (var rep = 0; rep < set.repetitions; rep++) {
        set.exercises.asMap().forEach((exerciseIndex, exercise) {
          final boundary = exerciseIndex != 0
              ? StepBoundary.none
              : (rep != 0
                  ? StepBoundary.newRep
                  : (setIndex != 0 ? StepBoundary.newSet : StepBoundary.none));

          steps.add(
            RunStep(
              exercise: exercise,
              setIndex: setIndex,
              set: set,
              rep: rep,
              exerciseIndex: exerciseIndex,
              startSecond: currentSecond,
              boundary: boundary,
            ),
          );
          currentSecond += exercise.duration;
        });
      }
    });

    final rows = <TimelineRow>[];
    final rowIndexOfStep = List<int>.filled(steps.length, 0);

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.exerciseIndex == 0) {
        rows.add(
          TimelineHeaderRow(
            setIndex: step.setIndex,
            setCount: workout.sets.length,
            rep: step.rep,
            repCount: step.set.repetitions,
          ),
        );
      }
      rowIndexOfStep[i] = rows.length;
      rows.add(TimelineStepRow(i, step));
    }

    return RunPlan._(steps, rows, rowIndexOfStep);
  }
}
