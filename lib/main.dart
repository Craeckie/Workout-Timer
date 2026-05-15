import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:pref/pref.dart';
import 'package:prefs/prefs.dart';

import 'generated/l10n.dart';
import 'layouts/home_page.dart';
import 'utils/migrations.dart';
import 'utils/sound_helper.dart';
import 'utils/tts_helper.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Prefs.init();

  PrefServiceShared.init(
    defaults: {
      'theme': 'system',
      'wakelock': true,
      'halftime': true,
      'ticks': false,
      'tts_next_announce': true,
      'sound': 'tts',
      'expanded_setlist': false,
    },
  ).then(
    (service) => Future.wait([
      TTSHelper.init(),
      SoundHelper.loadSounds(),
      Migrations.runMigrations(),
    ]).then(
      (_) {
        runApp(
          PrefService(service: service, child: Phoenix(child: JAWTApp())),
        );
        FlutterNativeSplash.remove();
      },
    ),
  );
}

class JAWTApp extends StatelessWidget {
  const JAWTApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final themePref = PrefService.of(context).get('theme');
    final brightness = switch (themePref) {
      'light' => ThemeMode.light,
      'dark' || 'black' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final isBlack = themePref == 'black';
        // OLED-friendly: scaffold is pure black, but card/dialog surfaces
        // are lifted to a dark grey so structure stays visible.
        const liftedSurface = Color(0xFF1E1E1E);
        final darkScheme = (darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.dark,
                ))
            .copyWith(surface: isBlack ? liftedSurface : null);
        return MaterialApp(
          title: 'Workout Timer',
          themeMode: brightness,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: lightDynamic,
            colorSchemeSeed: lightDynamic != null ? null : Colors.blue,
            cardTheme: const CardThemeData(
              elevation: 4,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: isBlack ? Colors.black : null,
            canvasColor: isBlack ? Colors.black : null,
            cardTheme: isBlack
                ? CardThemeData(
                    elevation: 0,
                    color: liftedSurface,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.white12, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                : const CardThemeData(elevation: 4),
            dialogTheme: isBlack
                ? const DialogThemeData(backgroundColor: liftedSurface)
                : null,
            bottomSheetTheme: isBlack
                ? const BottomSheetThemeData(backgroundColor: liftedSurface)
                : null,
          ),
          home: const HomePage(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          localeListResolutionCallback: (locales, supportedLocales) {
            if (PrefService.of(context).get('lang') != null) {
              final locale = Locale(PrefService.of(context).get('lang'));
              if (supportedLocales.contains(locale)) return locale;
            }

            for (var locale in locales!) {
              if (supportedLocales.any(
                (element) => element.languageCode == locale.languageCode,
              )) {
                PrefService.of(context).set('lang', locale.languageCode);
                return locale;
              }
            }
            PrefService.of(context).set('lang', 'en');
            return const Locale('en');
          },
        );
      },
    );
  }
}
