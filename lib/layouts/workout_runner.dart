import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_another_workout_timer/utils/timetable.dart';
import 'package:prefs/prefs.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../generated/l10n.dart';
import '../utils/run_plan.dart';
import '../utils/run_progress_rail.dart';
import '../utils/utils.dart';
import '../utils/workout.dart';

class WorkoutPage extends StatelessWidget {
  final Workout workout;

  const WorkoutPage({super.key, required this.workout});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (context) => Timetable(context, workout),
        child: Consumer<Timetable>(
          builder: (context, timetable, child) =>
              WorkoutPageContent(workout: workout, timetable: timetable),
        ),
      );
}

/// page to do a workout
class WorkoutPageContent extends StatefulWidget {
  final Workout workout;
  final Timetable timetable;

  const WorkoutPageContent({
    super.key,
    required this.workout,
    required this.timetable,
  });

  @override
  WorkoutPageState createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPageContent> {
  late final Workout _workout;
  late final Timetable timetable;

  WorkoutPageState();

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void dispose() {
    timetable.timerStop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    timetable = widget.timetable;
    timetable.itemScrollController = _itemScrollController;
    if (Prefs.getBool('wakelock', true)) WakelockPlus.enable();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      timetable.buildTimetable();
    });
  }

  bool get _isBlackTheme =>
      Theme.of(context).scaffoldBackgroundColor == Colors.black;

  Widget _buildRepIndicator(int rep, int repCount) {
    if (repCount <= 1) return const SizedBox.shrink();
    if (repCount > 8) {
      return Text(
        S.of(context).repOf(rep + 1, repCount),
        style: const TextStyle(fontSize: 14),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        repCount,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            i == rep ? Icons.circle : Icons.circle_outlined,
            size: 8,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroContext() {
    final setIndex = _workout.sets.indexOf(timetable.currentSet);
    final repCount = timetable.currentSet.repetitions;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          S.of(context).setOf(setIndex + 1, _workout.sets.length),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        if (repCount > 1) ...[
          const SizedBox(width: 8),
          const Text('·'),
          const SizedBox(width: 8),
          _buildRepIndicator(timetable.currentReps, repCount),
        ],
      ],
    );
  }

  Widget _buildHeaderRow(TimelineHeaderRow row) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          row.repCount > 1
              ? '${S.of(context).setIndex(row.setIndex + 1)} · '
                  '${S.of(context).repOf(row.rep + 1, row.repCount)}'
              : S.of(context).setIndex(row.setIndex + 1),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _buildStepRow(TimelineStepRow row) {
    final isDone = row.stepIndex < timetable.currentStepIndex ||
        (timetable.workoutDone && row.stepIndex <= timetable.currentStepIndex);
    final isCurrent =
        !timetable.workoutDone && row.stepIndex == timetable.currentStepIndex;

    final tileColor = isCurrent
        ? Theme.of(context).primaryColor
        : (_isBlackTheme ? Colors.transparent : Theme.of(context).focusColor);
    final textColor = isDone
        ? Theme.of(context).disabledColor
        : (!isCurrent && _isBlackTheme ? Colors.white70 : null);

    return ListTile(
      dense: true,
      tileColor: tileColor,
      textColor: textColor,
      leading: isDone ? const Icon(Icons.check, size: 18) : null,
      title: Text(row.step.exercise.name),
      subtitle: Text(
        S.of(context).durationWithTime(
              Utils.formatSeconds(row.step.exercise.duration),
            ),
      ),
    );
  }

  Widget _buildTimelineRow(TimelineRow row) => switch (row) {
        TimelineHeaderRow() => _buildHeaderRow(row),
        TimelineStepRow() => _buildStepRow(row),
      };

  @override
  Widget build(BuildContext context) {
    if (!timetable.isInitialized) {
      return Container();
    }
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_workout.title),
          scrolledUnderElevation: 1,
          elevation: 1,
          actions: [
            if (!timetable.workoutDone && timetable.currentSecond > 0)
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: S.of(context).finishEarly,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(S.of(context).finishEarly),
                      content: Text(S.of(context).finishEarlyConfirmation),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(S.of(context).no),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(S.of(context).yes),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    timetable.finishEarly();
                  }
                },
              ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // left side of footer
              Expanded(
                child: ListTile(
                  title: Text(
                    S.of(context).exerciseOf(
                          timetable.currentStepIndex + 1,
                          timetable.plan.steps.length,
                        ),
                  ),
                ),
              ),
              // right side of footer
              Expanded(
                child: ListTile(
                  title: Text(
                    S.of(context).durationLeft(
                          Utils.formatSeconds(
                            _workout.duration - timetable.currentSecond + 10,
                          ),
                          Utils.formatSeconds(_workout.duration + 10),
                        ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // hero card with current exercise
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    _buildHeroContext(),
                    const SizedBox(height: 4),
                    Text(
                      Utils.formatSeconds(timetable.remainingSeconds),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: RunProgressRail(
                        plan: timetable.plan,
                        elapsedSeconds:
                            math.max(0, timetable.currentSecond - 10),
                      ),
                    ),
                    Text(
                      timetable.currentExercise.name,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // remaining run: every set, every repetition, every exercise
            Expanded(
              child: Card(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ScrollablePositionedList.builder(
                  itemBuilder: (context, index) =>
                      _buildTimelineRow(timetable.plan.rows[index]),
                  itemCount: timetable.plan.rows.length,
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FloatingActionButton.large(
              heroTag: 'FAB1',
              onPressed: timetable.isInitialized && !timetable.workoutDone
                  ? timetable.skipBackward
                  : null,
              child: const Icon(Icons.skip_previous, size: 40),
            ),
            const SizedBox(width: 16),
            FloatingActionButton.large(
              heroTag: 'mainFAB',
              elevation: 8,
              child: Icon(
                timetable.isActive
                    ? Icons.pause
                    : timetable.workoutDone
                        ? Icons.replay
                        : Icons.play_arrow,
                size: 48,
              ),
              onPressed: () {
                if (timetable.isActive) {
                  timetable.timerStop();
                } else if (timetable.workoutDone) {
                  timetable.resetWorkout();
                } else {
                  timetable.timerStart();
                }
              },
            ),
            const SizedBox(width: 16),
            FloatingActionButton.large(
              heroTag: 'FAB2',
              onPressed: timetable.isInitialized && !timetable.workoutDone
                  ? timetable.skipForward
                  : null,
              child: const Icon(Icons.skip_next, size: 40),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
      onWillPop: () async {
        // Just pop if the workout wasn't started yet or is already done
        if (timetable.canQuit) {
          return true;
        }

        final value = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(S.of(context).exitCheck),
            actions: <Widget>[
              TextButton(
                child: Text(S.of(context).no),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: Text(S.of(context).yesExit),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        );

        return value == true;
      },
    );
  }
}
