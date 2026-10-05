import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme.dart';

/// Manages application theme mode (Dark OLED vs High-Contrast Light)
/// Defaults to device system theme. Persists user overrides in app document storage.
class ThemeNotifier extends Notifier<bool> {
  static bool get _systemIsLight {
    try {
      final brightness = PlatformDispatcher.instance.platformBrightness;
      return brightness == Brightness.light;
    } catch (_) {
      return false;
    }
  }

  @override
  bool build() {
    final systemDefault = _systemIsLight;
    AppColors.isLight = systemDefault;
    _updateSystemUi(systemDefault);
    _loadSavedTheme();
    return systemDefault;
  }

  static const String _kSettingsFile = 'app_settings.json';
  bool _hasUserToggled = false;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_kSettingsFile');
  }

  Future<void> _loadSavedTheme() async {
    if (_hasUserToggled) return;
    try {
      final file = await _getFile();
      if (_hasUserToggled) return;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (_hasUserToggled) return;
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data.containsKey('isLight') && data['isLight'] != null) {
          final isLight = data['isLight'] as bool;
          AppColors.isLight = isLight;
          state = isLight;
          _updateSystemUi(isLight);
          return;
        }
      }
    } catch (_) {}

    if (_hasUserToggled) return;
    final sys = _systemIsLight;
    AppColors.isLight = sys;
    state = sys;
    _updateSystemUi(sys);
  }

  void _updateSystemUi(bool isLight) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isLight ? const Color(0xFFF1F5F9) : const Color(0xFF000000),
        systemNavigationBarDividerColor:
            isLight ? const Color(0xFFCBD5E1) : const Color(0x00000000),
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  void toggleTheme() {
    _hasUserToggled = true;
    final newMode = !state;
    AppColors.isLight = newMode;
    state = newMode;
    _updateSystemUi(newMode);
    _persistTheme(newMode);
  }

  void setTheme(bool isLight) {
    if (state == isLight) return;
    AppColors.isLight = isLight;
    state = isLight;
    _updateSystemUi(isLight);
    _persistTheme(isLight);
  }

  void _persistTheme(bool isLight) async {
    try {
      final file = await _getFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        data = jsonDecode(content) as Map<String, dynamic>;
      }
      data['isLight'] = isLight;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);
