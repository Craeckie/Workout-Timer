import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'autobackup_helper.dart';
import 'history_helper.dart';
import 'run_plan.dart';
import 'sound_helper.dart';
import 'package:just_another_workout_timer/utils/tts_helper.dart';
import 'workout.dart';
import 'package:prefs/prefs.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../generated/l10n.dart';

class Timetable with ChangeNotifier {
  final BuildContext _context;
  late final ItemScrollController itemScrollController;
  final Workout _workout;

  Timetable(this._context, this._workout);

  Timer? _timer;

  late RunPlan plan;
  int currentStepIndex = 0;

  late Set currentSet;
  late Exercise currentExercise;
  int currentReps = 0;

  Set? nextSet;

  Exercise? prevExercise;
  Exercise? nextExercise;

  int remainingSeconds = 10;
  int currentSecond = 0;

  bool workoutDone = false;
  bool isInitialized = false;

  /// timestamps of functions to announce current exercise (among other things)
  final Map<int, Function> _timetable = SplayTreeMap();

  bool get canQuit => _timer == null || !_timer!.isActive || workoutDone;

  bool get isActive => _timer != null && _timer!.isActive;

  void skipForward() {
    final wasActive = isActive;
    if (nextExercise != null || currentSecond < 10) {
      currentSecond += remainingSeconds - 1;
      timerStop();
      timerStart();
      _timerTick();
      if (!wasActive) timerStop();
      notifyListeners();
    }
  }

  void skipBackward() {
    if (currentSecond <= 10) return;
    final wasActive = isActive;
    final elapsed = currentExercise.duration - remainingSeconds;
    if (elapsed > 3) {
      currentSecond -= elapsed + 1;
    } else if (prevExercise != null) {
      currentSecond -= elapsed + prevExercise!.duration + 1;
    } else {
      return;
    }
    timerStop();
    timerStart();
    _timerTick();
    if (!wasActive) timerStop();
    notifyListeners();
  }

  void resetWorkout() {
    workoutDone = false;
    currentSet = Set(exercises: [], repetitions: 1);
    currentExercise = Exercise(duration: 0, name: '');
    currentReps = 1;

    nextSet = Set(exercises: [], repetitions: 1);

    remainingSeconds = 10;
    currentSecond = 0;

    itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );

    buildTimetable();
    notifyListeners();
  }

  void buildTimetable() {
    plan = RunPlan.of(_workout);
    currentStepIndex = 0;

    // init values
    currentSet = plan.steps[0].set;
    currentExercise = plan.steps[0].exercise;
    prevExercise = null;
    nextExercise = plan.steps.length > 1 ? plan.steps[1].exercise : null;
    nextSet = _workout.sets.length > 1 ? _workout.sets[1] : null;

    /// current timestamp
    var currentTime = 10;

    // announce first exercise
    _timetable[1] = () {
      TTSHelper.speak(
        S.of(_context).firstExercise(plan.steps[0].exercise.name),
      );
    };

    // countdown to workout start
    _timetable[7] = () {
      TTSHelper.speak('3');
      SoundHelper.playBeepLow();
    };

    _timetable[8] = () {
      TTSHelper.speak('2');
      SoundHelper.playBeepLow();
    };

    _timetable[9] = () {
      TTSHelper.speak('1');
      SoundHelper.playBeepLow();
    };

    for (var i = 0; i < plan.steps.length; i++) {
      final step = plan.steps[i];
      final exercise = step.exercise;
      final set = step.set;

      final locNextExercise =
          i + 1 < plan.steps.length ? plan.steps[i + 1].exercise : null;
      final locPrevExercise = i > 0 ? plan.steps[i - 1].exercise : null;
      final locNextSet = step.setIndex + 1 < _workout.sets.length
          ? _workout.sets[step.setIndex + 1]
          : null;

      // announce next exercise
      if ((Prefs.getString('sound') == 'tts' &&
              Prefs.getBool('tts_next_announce')) &&
          exercise.duration >= 10) {
        _timetable[currentTime + exercise.duration - 9] = () {
          if (locNextExercise != null) {
            TTSHelper.speak(
              S.of(_context).nextExercise(locNextExercise.name),
            );
          }
        };
      } else if (currentSecond > 10 && Prefs.getBool('ticks')) {
        SoundHelper.playBeepTick();
      }

      if (exercise.duration >= 10 && Prefs.getBool('halftime')) {
        _timetable[(currentTime + exercise.duration / 2).round()] = () {
          if (Prefs.getString('sound') == 'beep') {
            SoundHelper.playDouble();
          } else if (!TTSHelper.isTalking &&
              Prefs.getString('sound') == 'tts') {
            TTSHelper.speak(S.of(_context).halfwayDone);
          }
        };
      }

      // countdown to next exercise
      _timetable[currentTime + exercise.duration - 3] = () {
        TTSHelper.speak('3');
        SoundHelper.playBeepLow();
      };

      _timetable[currentTime + exercise.duration - 2] = () {
        TTSHelper.speak('2');
        SoundHelper.playBeepLow();
      };

      _timetable[currentTime + exercise.duration - 1] = () {
        TTSHelper.speak('1');
        SoundHelper.playBeepLow();
      };

      // update display and announce current exercise
      _timetable[currentTime] = () {
        itemScrollController.scrollTo(
          index: plan.rowIndexOfStep(i),
          alignment: 0.25,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
        remainingSeconds = exercise.duration;
        if (currentSet == set) {
          SoundHelper.playBeepHigh();
        } else {
          SoundHelper.playTriple();
        }
        currentSet = set;
        prevExercise = locPrevExercise;
        nextExercise = locNextExercise;
        currentExercise = exercise;
        nextSet = locNextSet;
        currentReps = step.rep;
        currentStepIndex = i;
        TTSHelper.speak(exercise.name);
      };
      currentTime += exercise.duration;
      notifyListeners();
    }

    // announce completed workout
    _timetable[currentTime] = () {
      timerStop();
      TTSHelper.speak(S.of(_context).workoutComplete);

      workoutDone = true;
      currentExercise =
          Exercise(name: S.of(_context).workoutComplete, duration: 1);
      appendHistoryEntry(_workout.title).then((_) => runAutobackup());
      notifyListeners();
    };

    isInitialized = true;
  }

  void timerStart() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerTick();
    });
    notifyListeners();
  }

  void _timerTick() {
    currentSecond += 1;
    remainingSeconds -= 1;

    if (_timetable.containsKey(currentSecond)) {
      _timetable[currentSecond]!();
    } else if (currentSecond > 10 && Prefs.getBool('ticks')) {
      SoundHelper.playBeepTick();
    }
    notifyListeners();
  }

  void timerStop() {
    _timer?.cancel();
    notifyListeners();
  }

  void finishEarly() {
    if (workoutDone) return;
    timerStop();
    workoutDone = true;
    currentExercise =
        Exercise(name: S.of(_context).workoutComplete, duration: 1);
    TTSHelper.speak(S.of(_context).workoutComplete);
    appendHistoryEntry(_workout.title).then((_) => runAutobackup());
    notifyListeners();
  }
}
