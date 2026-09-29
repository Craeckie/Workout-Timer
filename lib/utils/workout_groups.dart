import 'workout.dart';

/// A category and its workouts, in list order.
class WorkoutGroup {
  WorkoutGroup(this.category, this.workouts);

  /// Empty for workouts without a category.
  final String category;
  final List<Workout> workouts;
}

class WorkoutGroups {
  static final _titlePrefix = RegExp(r'^(CC )?([BF]) ?W\d');

  /// Category derived from the title prefix used by the B/F programme
  /// workouts (`B W1-T2`, `CC F W5-T2 …`); empty when the title has none.
  static String categoryFromTitle(String title) {
    final match = _titlePrefix.firstMatch(title);
    if (match == null) return '';
    final programme = match.group(2) == 'B' ? 'Beginner' : 'First Class';
    return match.group(1) != null ? 'CC $programme' : programme;
  }

  /// Groups [sorted] (already in list order) by category. Groups keep the
  /// order in which their category first appears; uncategorized workouts
  /// come last.
  static List<WorkoutGroup> group(List<Workout> sorted) {
    final groups = <String, WorkoutGroup>{};
    for (final workout in sorted) {
      groups
          .putIfAbsent(
            workout.category,
            () => WorkoutGroup(workout.category, []),
          )
          .workouts
          .add(workout);
    }
    final uncategorized = groups.remove('');
    return [...groups.values, ?uncategorized];
  }

  /// Workouts in the order the grouped list shows them.
  static List<Workout> flatten(List<WorkoutGroup> groups) => [
    for (final group in groups) ...group.workouts,
  ];

  /// The workout after the one titled [lastCompleted] within its own
  /// category, wrapping around to the category's first workout.
  static Workout? nextWorkout(
    List<WorkoutGroup> groups,
    String? lastCompleted,
  ) {
    if (lastCompleted == null) return null;
    for (final group in groups) {
      final index = group.workouts.indexWhere((w) => w.title == lastCompleted);
      if (index != -1) {
        return group.workouts[(index + 1) % group.workouts.length];
      }
    }
    return null;
  }

  /// Gives [imported] positions after the highest one in [existing], in
  /// their current order, so merged workouts are appended instead of
  /// interleaving with the existing list.
  static void appendPositions(List<Workout> existing, List<Workout> imported) {
    var next =
        existing.fold<int>(
          -1,
          (max, w) => w.position > max ? w.position : max,
        ) +
        1;
    for (final workout in imported) {
      workout.position = next++;
    }
  }
}
