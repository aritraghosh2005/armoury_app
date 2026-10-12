import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'viewmodels/auth_viewmodel.dart';

class TutorialNotifier extends Notifier<bool> {
  static const String _kSettingsFile = 'app_settings.json';
  static const int _tutorialVersion = 6;
  String? _accountKey;

  @override
  bool build() {
    final accountKey = ref.watch(
      authViewModelProvider.select((state) => state.accountKey),
    );
    _accountKey = accountKey;
    _loadState(accountKey);
    return true; // default to true until loaded to prevent flash
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_kSettingsFile');
  }

  Future<void> _loadState(String? accountKey) async {
    if (accountKey == null) {
      state = true;
      return;
    }
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final versions = Map<String, dynamic>.from(
          data['tutorialVersions'] as Map? ?? const {},
        );
        final seenVersion = (versions[accountKey] as num?)?.toInt() ?? 0;
        if (_accountKey == accountKey) {
          state = seenVersion >= _tutorialVersion;
        }
      } else {
        if (_accountKey == accountKey) state = false;
      }
    } catch (_) {
      if (_accountKey == accountKey) state = false;
    }
  }

  Future<void> markCompleted() async {
    state = true;
    try {
      final accountKey = _accountKey;
      if (accountKey == null) return;
      final file = await _getFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      }
      final versions = Map<String, dynamic>.from(
        data['tutorialVersions'] as Map? ?? const {},
      );
      versions[accountKey] = _tutorialVersion;
      data['tutorialVersions'] = versions;
      data['hasSeenTutorial'] = true;
      data['tutorialVersion'] = _tutorialVersion;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> resetTutorial() async {
    state = false;
    try {
      final accountKey = _accountKey;
      final file = await _getFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      }
      if (accountKey != null) {
        final versions = Map<String, dynamic>.from(
          data['tutorialVersions'] as Map? ?? const {},
        );
        versions.remove(accountKey);
        data['tutorialVersions'] = versions;
      }
      data['hasSeenTutorial'] = false;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, bool>(
  TutorialNotifier.new,
);
