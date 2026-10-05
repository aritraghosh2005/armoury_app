import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class TutorialNotifier extends Notifier<bool> {
  static const String _kSettingsFile = 'app_settings.json';

  @override
  bool build() {
    _loadState();
    return true; // default to true until loaded to prevent flash
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_kSettingsFile');
  }

  Future<void> _loadState() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        state = data['hasSeenTutorial'] as bool? ?? false;
      } else {
        state = false; // first run!
      }
    } catch (_) {
      state = false;
    }
  }

  Future<void> markCompleted() async {
    state = true;
    try {
      final file = await _getFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      }
      data['hasSeenTutorial'] = true;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> resetTutorial() async {
    state = false;
    try {
      final file = await _getFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      }
      data['hasSeenTutorial'] = false;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, bool>(TutorialNotifier.new);
