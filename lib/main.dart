import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isLight = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF000000),
      systemNavigationBarDividerColor: isLight ? const Color(0xFFCBD5E1) : Colors.transparent,
      systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const ProviderScope(child: ArmouryApp()));
}

class ArmouryApp extends ConsumerWidget {
  const ArmouryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeProvider);
    AppColors.isLight = isLight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF000000),
        systemNavigationBarDividerColor: isLight ? const Color(0xFFCBD5E1) : Colors.transparent,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: MaterialApp(
        title: 'ORCUS · ARMOURY',
        debugShowCheckedModeBanner: false,
        theme: buildTerminalTheme(isLight: isLight),
        home: const AppShell(),
      ),
    );
  }
}
