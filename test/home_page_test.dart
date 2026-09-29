// Runs the real migration and HomePage against workout files in a temp
// directory (path_provider faked), to check the category sections.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_another_workout_timer/generated/l10n.dart';
import 'package:just_another_workout_timer/layouts/home_page.dart';
import 'package:just_another_workout_timer/utils/migrations.dart';
import 'package:just_another_workout_timer/utils/utils.dart';
import 'package:just_another_workout_timer/utils/workout.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:prefs/prefs.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getExternalStoragePath() async => path;
}

late Directory dir;

void writeFile(String name, Object json) {
  File('${dir.path}/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(json));
}

/// Workout files as an app version before categories wrote them.
void writeV2Workouts(List<String> titles) {
  for (final (i, title) in titles.indexed) {
    writeFile(
      'workouts/${Utils.removeSpecialChar(title)}.json',
      Workout(title: title, version: 2, position: i).toJson()
        ..remove('category'),
    );
  }
}

void writeHistory(String lastTitle) => writeFile('history.json', [
      HistoryEntry(title: lastTitle, completedAt: DateTime(2026, 9, 22))
          .toJson(),
    ]);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

Future<void> pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      locale: const Locale('en'),
      home: const HomePage(),
    ),
  );
  // HomePage loads files and history in a post-frame callback: let the real
  // I/O run until workout cards show up.
  for (var i = 0; i < 100 && find.byType(Card).evaluate().isEmpty; i++) {
    await tester.runAsync(settle);
    await tester.pump();
  }
}

void main() {
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('home_page_test');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    SharedPreferences.setMockInitialValues({'autobackup_asked': true});
    await Prefs.init();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  const titles = [
    'CC B W1-T1 Stufenintervalle',
    'CC B W1-T2 Intervallsätze',
    'CC F W1-T1 Supersätze',
    'CC F W1-T2 Stufenintervalle',
    'Beine',
  ];

  test('migration v2 → v3 fills categories from titles', () async {
    writeV2Workouts(titles);
    await Migrations.runMigrations();
    await settle();
    final categories = {
      for (final t in titles)
        t: Workout.fromJson(
          jsonDecode(File('${dir.path}/workouts/${Utils.removeSpecialChar(t)}.json').readAsStringSync()),
        ),
    };
    expect(categories.values.map((w) => w.version).toSet(), {3});
    expect(categories.values.map((w) => w.category).toList(), [
      'CC Beginner',
      'CC Beginner',
      'CC First Class',
      'CC First Class',
      '',
    ]);
  });

  testWidgets('only the next workout\'s category is open', (tester) async {
    writeV2Workouts(titles);
    writeHistory('CC F W1-T1 Supersätze');
    await tester.runAsync(() async {
      await Migrations.runMigrations();
      await settle();
    });
    await pumpHome(tester);

    expect(find.text('CC Beginner'), findsOneWidget);
    expect(find.text('CC First Class'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    // CC First Class is open, its next workout highlighted
    expect(find.text('CC F W1-T1 Supersätze'), findsOneWidget);
    expect(find.text('CC F W1-T2 Stufenintervalle'), findsOneWidget);
    final nextCard = tester.widget<Card>(
      find.ancestor(
        of: find.text('CC F W1-T2 Stufenintervalle'),
        matching: find.byType(Card),
      ),
    );
    expect(nextCard.shape, isA<RoundedRectangleBorder>());

    // the others are closed
    expect(find.text('CC B W1-T1 Stufenintervalle'), findsNothing);
    expect(find.text('Beine'), findsNothing);

    await tester.tap(find.text('CC Beginner'));
    await tester.pump();
    expect(find.text('CC B W1-T1 Stufenintervalle'), findsOneWidget);

    await tester.tap(find.text('CC First Class'));
    await tester.pump();
    expect(find.text('CC F W1-T1 Supersätze'), findsNothing);
  });

  testWidgets('next workout wraps within its category', (tester) async {
    writeV2Workouts(titles);
    writeHistory('CC B W1-T2 Intervallsätze');
    await tester.runAsync(() async {
      await Migrations.runMigrations();
      await settle();
    });
    await pumpHome(tester);

    expect(find.text('CC B W1-T1 Stufenintervalle'), findsOneWidget);
    expect(find.text('CC F W1-T1 Supersätze'), findsNothing);
    final nextCard = tester.widget<Card>(
      find.ancestor(
        of: find.text('CC B W1-T1 Stufenintervalle'),
        matching: find.byType(Card),
      ),
    );
    expect(nextCard.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('without categories the list has no headers', (tester) async {
    writeV2Workouts(['Beine', 'Arme']);
    await tester.runAsync(() async {
      await Migrations.runMigrations();
      await settle();
    });
    await pumpHome(tester);

    expect(find.text('Other'), findsNothing);
    expect(find.text('Beine'), findsOneWidget);
    expect(find.text('Arme'), findsOneWidget);
  });
}
