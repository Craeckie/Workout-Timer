import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pref/pref.dart';
import 'package:prefs/prefs.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../generated/l10n.dart';
import '../utils/autobackup_helper.dart';
import '../utils/languages.dart';
import '../utils/sound_helper.dart';
import '../utils/storage_helper.dart';
import '../utils/tts_helper.dart';
import 'oss_license_page.dart';

/// change some settings of the app and display licenses
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late String _license;
  bool _autobackupEnabled = false;
  String _autobackupFolder = '';

  @override
  void initState() {
    super.initState();
    _loadAutobackupState();
  }

  Future<void> _loadAutobackupState() async {
    final folderName = await autobackupFolderDisplayName();
    if (!mounted) return;
    setState(() {
      _autobackupEnabled = Prefs.getBool('autobackup_enabled', false);
      _autobackupFolder = folderName;
    });
  }

  void _loadLicense() async {
    var lic = await rootBundle.loadString('LICENSE');
    setState(() {
      _license = lic;
    });
  }

  @override
  Widget build(BuildContext context) {
    _loadLicense();
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).settings),
      ),
      body: PrefPage(
        children: [
          PrefTitle(
            title: Text(
              S.of(context).general,
            ),
          ),
          PrefDropdown(
            title: Text(S.of(context).language),
            items: Languages.languages
                .map(
                  (lang) => DropdownMenuItem(
                    value: lang.localeCode,
                    child: Text(lang.displayName),
                  ),
                )
                .toList(),
            onChange: (String? value) {
              var lang = Languages.fromLocaleCode(value!);
              setState(() {
                S.load(Locale(lang.localeCode));
                TTSHelper.setLanguage(lang.languageCode);
              });
            },
            pref: 'lang',
          ),
          PrefDropdown(
            title: Text(S.of(context).theme),
            pref: 'theme',
            onChange: (_) {
              Phoenix.rebirth(context);
            },
            items: [
              DropdownMenuItem(
                value: 'dark',
                child: Text(S.of(context).theme_dark),
              ),
              DropdownMenuItem(
                value: 'light',
                child: Text(S.of(context).theme_light),
              ),
              DropdownMenuItem(
                value: 'system',
                child: Text(S.of(context).theme_system),
              ),
              DropdownMenuItem(
                value: 'black',
                child: Text(S.of(context).theme_black),
              ),
            ],
          ),
          PrefSwitch(
            title: Text(S.of(context).keepScreenAwake),
            pref: 'wakelock',
          ),
          PrefSwitch(
            title: Text(S.of(context).settingHalfway),
            pref: 'halftime',
          ),
          PrefSwitch(
            title: Text(S.of(context).playTickEverySecond),
            pref: 'ticks',
          ),
          PrefSwitch(
            title: Text(S.of(context).expanded_setlist),
            subtitle: Text(S.of(context).expanded_setlist_info),
            pref: 'expanded_setlist',
          ),
          PrefTitle(
            title: Text(
              S.of(context).backup,
            ),
          ),
          PrefLabel(
            title: Text(
              _autobackupEnabled
                  ? S.of(context).autobackupEnabled
                  : S.of(context).autobackupDisabled,
            ),
            subtitle: _autobackupEnabled && _autobackupFolder.isNotEmpty
                ? Text(S.of(context).autobackupFolder(_autobackupFolder))
                : null,
          ),
          if (!_autobackupEnabled)
            PrefLabel(
              leading: Icon(
                Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                S.of(context).autobackupNotEnabledWarning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!_autobackupEnabled)
            PrefLabel(
              title: Text(S.of(context).enableAutobackup),
              onTap: () async {
                final ok = await pickAutobackupDirectory();
                if (ok) {
                  await Prefs.setBool('autobackup_asked', true);
                  await _loadAutobackupState();
                }
              },
            ),
          if (_autobackupEnabled)
            PrefLabel(
              title: Text(S.of(context).changeAutobackupFolder),
              onTap: () async {
                final ok = await pickAutobackupDirectory();
                if (ok) await _loadAutobackupState();
              },
            ),
          if (_autobackupEnabled)
            PrefLabel(
              title: Text(S.of(context).disableAutobackup),
              onTap: () async {
                await disableAutobackup();
                await _loadAutobackupState();
              },
            ),
          PrefLabel(
            title: Text(S.of(context).export),
            onTap: exportAllWorkouts,
          ),
          PrefLabel(
            title: Text(S.of(context).import),
            onTap: () async {
              var mode = ImportMode.overwrite;
              if ((await getAllWorkouts()).isNotEmpty) {
                if (!context.mounted) return;
                final chosen = await showDialog<ImportMode>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(S.of(ctx).importExistingTitle),
                    content: Text(S.of(ctx).importExistingMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(S.of(ctx).cancel),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, ImportMode.merge),
                        child: Text(S.of(ctx).importMerge),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, ImportMode.overwrite),
                        child: Text(S.of(ctx).importOverwrite),
                      ),
                    ],
                  ),
                );
                if (chosen == null) return;
                mode = chosen;
              }
              final count = await importFile(true, mode: mode);
              if (!context.mounted) return;
              Fluttertoast.showToast(
                msg: S.of(context).importedCount(count),
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.CENTER,
              );
            },
          ),
          PrefTitle(
            title: Text(
              S.of(context).soundOutput,
            ),
          ),
          PrefRadio(
            title: Text(S.of(context).noSound),
            value: 'none',
            pref: 'sound',
            subtitle: Text(S.of(context).noSoundDesc),
            onSelect: () {
              TTSHelper.useTTS = false;
              SoundHelper.useSound = false;
            },
          ),
          PrefRadio(
            title: Text(S.of(context).useTTS),
            value: 'tts',
            pref: 'sound',
            subtitle: Text(S.of(context).useTTSDesc),
            disabled: !TTSHelper.available,
            onSelect: () {
              TTSHelper.useTTS = true;
              SoundHelper.useSound = false;
            },
          ),
          PrefRadio(
            title: Text(S.of(context).useSound),
            value: 'beep',
            pref: 'sound',
            subtitle: Text(S.of(context).useSoundDesc),
            onSelect: () {
              TTSHelper.useTTS = false;
              SoundHelper.useSound = true;
            },
          ),
          PrefTitle(
            title: Text(
              S.of(context).tts,
            ),
          ),
          PrefDropdown(
            title: Text(S.of(context).ttsEngine),
            pref: 'tts_engine',
            subtitle: Text(S.of(context).ttsEngineDesc),
            items: TTSHelper.engines
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ),
                )
                .toList(),
            disabled: !TTSHelper.available,
            onChange: (String? value) {
              TTSHelper.flutterTts
                  .setEngine(value!)
                  .then((_) => TTSHelper.init());
            },
          ),
          PrefDropdown(
            title: Text(S.of(context).ttsVoice),
            pref: 'tts_voice',
            subtitle: Text(S.of(context).ttsVoiceDesc),
            items: TTSHelper.voices
                .where(
                  (voice) =>
                      voice.locale == Prefs.getString('tts_lang', 'en-US'),
                )
                .toList()
                .asMap()
                .entries
                .map(
                  (voice) => DropdownMenuItem(
                    value: voice.value.name,
                    child: Text(
                      '${S.of(context).voice} ${voice.key + 1} (${voice.value.name})',
                    ),
                  ),
                )
                .toList(),
            disabled: !TTSHelper.available,
            onChange: (String? value) {
              TTSHelper.flutterTts.setVoice({
                "name": value!,
                "locale": Prefs.getString('tts_lang', 'en-US'),
              });
            },
          ),
          PrefSwitch(
            title: Text(S.of(context).announceUpcomingExercise),
            pref: 'tts_next_announce',
            subtitle: Text(S.of(context).AnnounceUpcomingExerciseDesc),
            disabled: !TTSHelper.available,
          ),
          PrefTitle(
            title: Text(
              S.of(context).licenses,
            ),
          ),
          PrefLabel(
            title: Text(S.of(context).viewOnGithub),
            subtitle: Text(S.of(context).reportIssuesOrRequestAFeature),
            onTap: () {
              launchUrlString(
                'https://github.com/blockbasti/just_another_workout_timer',
              );
            },
          ),
          PrefLabel(
            title: Text(S.of(context).viewLicense),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          S.of(context).title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(_license),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          PrefLabel(
            title: Text(S.of(context).viewOSSLicenses),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OssLicensesPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
