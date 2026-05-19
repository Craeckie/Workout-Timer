import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:prefs/prefs.dart';
import 'package:saf_util/saf_util.dart';

import 'storage_helper.dart';

const _channel = MethodChannel('com.craeckie.workouttimer/saf');
const _backupFileName = 'WorkoutTimer_autobackup.json';
final _saf = SafUtil();

Future<bool> pickAutobackupDirectory() async {
  final dir = await _saf.pickDirectory(
    writePermission: true,
    persistablePermission: true,
  );
  if (dir == null) return false;
  await Prefs.setBool('autobackup_enabled', true);
  await Prefs.setString('autobackup_uri', dir.uri);
  return true;
}

Future<void> disableAutobackup() async {
  await Prefs.setBool('autobackup_enabled', false);
}

Future<String> autobackupFolderDisplayName() async {
  final uri = Prefs.getString('autobackup_uri', '');
  if (uri.isEmpty) return '';
  final doc = await _saf.documentFileFromUri(uri, true);
  return doc?.name ?? uri.split('%3A').last.split('%2F').last;
}

Future<void> runAutobackup() async {
  if (!Prefs.getBool('autobackup_enabled', false)) return;
  final treeUri = Prefs.getString('autobackup_uri', '');
  if (treeUri.isEmpty) return;
  try {
    final bytes = await buildBackupBytes();
    await _channel.invokeMethod<void>('writeToTree', {
      'treeUri': treeUri,
      'bytes': bytes,
      'fileName': _backupFileName,
      'mimeType': 'application/json',
    });
  } catch (e) {
    debugPrint('autobackup error: $e');
    Fluttertoast.showToast(msg: 'Autobackup failed');
  }
}
