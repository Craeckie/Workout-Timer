import 'package:flutter/material.dart';
import 'package:prefs/prefs.dart';
import 'package:just_another_workout_timer/layouts/workout_runner.dart';

import '../generated/l10n.dart';
import '../utils/autobackup_helper.dart';
import '../utils/history_helper.dart';
import '../utils/storage_helper.dart';
import '../utils/utils.dart';
import '../utils/workout.dart';
import '../utils/workout_groups.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'workout_builder.dart';

/// Main screen
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Workout> workouts = [];
  List<WorkoutGroup> groups = [];
  String? nextWorkoutToHighlight;

  /// Categories whose section is open. Filled once per app start with the
  /// category of the next workout; afterwards only the user toggles it.
  final _expanded = <String>{};
  bool _expansionInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeAskAutobackup();
      _loadWorkouts();
    });
  }

  Future<void> _maybeAskAutobackup() async {
    if (Prefs.getBool('autobackup_asked', false)) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx).enableAutobackupPromptTitle),
        content: Text(S.of(ctx).enableAutobackupPromptBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).notNow),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await pickAutobackupDirectory();
            },
            child: Text(S.of(ctx).enableAutobackup),
          ),
        ],
      ),
    );
    await Prefs.setBool('autobackup_asked', true);
  }

  /// load all workouts from disk and populate list
  Future<void> _loadWorkouts() async {
    getAllWorkouts().then(
      (value) => setState(() {
        groups = WorkoutGroups.group(value);
        workouts = WorkoutGroups.flatten(groups);
        _saveSorting();
        _determineNextWorkout();
      }),
    );
  }

  /// Determine which workout to highlight based on the latest history entry:
  /// the one after it within the same category.
  Future<void> _determineNextWorkout() async {
    final history = await loadHistory();
    final next = WorkoutGroups.nextWorkout(
      groups,
      history.isEmpty ? null : history.last.title,
    );
    if (!mounted) return;
    setState(() {
      if (next != null && next.title != nextWorkoutToHighlight) {
        _expanded.add(next.category);
      } else if (!_expansionInitialized && groups.isNotEmpty) {
        _expanded.add(groups.first.category);
      }
      _expansionInitialized = true;
      nextWorkoutToHighlight = next?.title;
    });
  }

  List<String> get _categories => [
        for (final group in groups)
          if (group.category.isNotEmpty) group.category,
      ];

  void _saveSorting() {
    for (var workout in workouts.asMap().entries) {
      workout.value.position = workout.key;
      writeWorkout(workout.value);
    }
  }

  /// aks user if they want to delete a workout
  void _showDeleteDialog(BuildContext context, Workout workout) {
    // set up the buttons
    Widget cancelButton = TextButton(
      child: Text(S.of(context).cancel),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );
    Widget continueButton = TextButton(
      child: Text(S.of(context).delete),
      onPressed: () {
        deleteWorkout(workout.title);
        _loadWorkouts();
        Navigator.of(context).pop();
      },
    );
    // set up the AlertDialog
    var alert = AlertDialog(
      title: Text(S.of(context).delete),
      content: Text(S.of(context).deleteConfirmation(workout.title)),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (context) => alert,
    );
  }

  void _renameCategory(BuildContext context, String category) {
    final controller = TextEditingController(text: category);
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).renameCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: S.of(context).category),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(S.of(context).rename),
          ),
        ],
      ),
    ).then((value) async {
      final name = value?.trim() ?? '';
      if (name.isEmpty || name == category) return;
      for (final workout in workouts.where((w) => w.category == category)) {
        workout.category = name;
        await writeWorkout(workout);
      }
      if (_expanded.remove(category)) _expanded.add(name);
      _loadWorkouts();
    });
  }

  Widget _buildWorkoutList() {
    // Without any categories the list looks as it did before them.
    if (groups.length == 1 && groups.first.category.isEmpty) {
      return CustomScrollView(
        slivers: [_buildGroupList(groups.first), _listEndSpace],
      );
    }
    return CustomScrollView(
      slivers: [
        for (final group in groups) ...[
          SliverToBoxAdapter(child: _buildGroupHeader(group)),
          if (_expanded.contains(group.category)) _buildGroupList(group),
        ],
        _listEndSpace,
      ],
    );
  }

  /// keeps the last workout clear of the FAB
  static const _listEndSpace = SliverToBoxAdapter(child: SizedBox(height: 80));

  Widget _buildGroupHeader(WorkoutGroup group) {
    final expanded = _expanded.contains(group.category);
    final containsNext =
        group.workouts.any((w) => w.title == nextWorkoutToHighlight);
    return ListTile(
      key: Key('category:${group.category}'),
      leading: Icon(
        expanded ? Icons.folder_open : Icons.folder,
        color: containsNext ? Colors.amber.shade600 : null,
      ),
      title: Text(
        group.category.isEmpty ? S.of(context).uncategorized : group.category,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${group.workouts.length}'),
          Icon(expanded ? Icons.expand_less : Icons.expand_more),
        ],
      ),
      onTap: () => setState(() {
        if (!_expanded.remove(group.category)) _expanded.add(group.category);
      }),
      onLongPress: group.category.isEmpty
          ? null
          : () => _renameCategory(context, group.category),
    );
  }

  Widget _buildGroupList(WorkoutGroup group) => SliverReorderableList(
        itemCount: group.workouts.length,
        itemBuilder: (context, index) =>
            _buildWorkoutItem(group.workouts[index], index),
        proxyDecorator: (child, index, animation) =>
            Material(elevation: 6, color: Colors.transparent, child: child),
        onReorder: (oldIndex, newIndex) {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          setState(() {
            var workout = group.workouts.removeAt(oldIndex);
            group.workouts.insert(newIndex, workout);
            workouts = WorkoutGroups.flatten(groups);
          });
          _saveSorting();
        },
      );

  Widget _buildWorkoutItem(Workout workout, int index) {
    final isNextWorkout = nextWorkoutToHighlight == workout.title;
    return Card(
      key: Key(workout.toJson().toString()),
      shape: isNextWorkout
          ? RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              side: BorderSide(
                color: Colors.amber.shade600,
                width: 2,
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ),
          Expanded(
            child: ListTile(
              title: Text(workout.title),
              subtitle: Text(
                S
                    .of(context)
                    .durationWithTime(Utils.formatSeconds(workout.duration)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: S.of(context).editWorkout,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BuilderPage(
                    workout: workout,
                    newWorkout: false,
                    categories: _categories,
                  ),
                ),
              ).then((value) => _loadWorkouts());
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            tooltip: S.of(context).startWorkout,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutPage(
                    workout: workout,
                  ),
                ),
              ).then((value) => _loadWorkouts());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: S.of(context).deleteWorkout,
            onPressed: () {
              _showDeleteDialog(context, workout);
            },
          ),
          IconButton(
            tooltip: S.of(context).shareWorkout,
            onPressed: () {
              shareWorkout(workout.title);
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).workouts),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: S.of(context).history,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                ).then((value) => _loadWorkouts());
              },
            ),
          ],
        ),
        body: _buildWorkoutList(),
        floatingActionButton: FloatingActionButton(
          heroTag: 'mainFAB',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BuilderPage(
                  workout: Workout(),
                  newWorkout: true,
                  categories: _categories,
                ),
              ),
            ).then((value) => _loadWorkouts());
          },
          tooltip: S.of(context).addWorkout,
          child: const Icon(Icons.add),
        ),
      );
}
