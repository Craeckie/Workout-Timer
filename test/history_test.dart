import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/utils/workout.dart';

void main() {
  group('HistoryEntry', () {
    test('JSON roundtrip preserves title and completedAt', () {
      final ts = DateTime.utc(2026, 5, 14, 9, 30, 15);
      final entry = HistoryEntry(title: 'Leg Day', completedAt: ts);
      final copy = HistoryEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(copy.title, 'Leg Day');
      expect(copy.completedAt.toUtc(), ts);
    });

    test('fromJson — missing required title throws', () {
      expect(
        () => HistoryEntry.fromJson(
          {'completedAt': DateTime.now().toIso8601String()},
        ),
        throwsA(anything),
      );
    });

    test('fromJson — missing required completedAt throws', () {
      expect(
        () => HistoryEntry.fromJson({'title': 'X'}),
        throwsA(anything),
      );
    });
  });
}
