/// Root [MaterialApp]: theme (light/dark), locale (English/Arabic, RTL-aware)
/// and the startup gate that wraps the single dashboard screen.
///
/// There is deliberately no router: the app is single-farm and single-device,
/// so every other screen is pushed from [DeviceDashboardScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/devices/screens/device_dashboard_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/locale_provider.dart';
import 'core/widgets/app_startup.dart';
import 'l10n/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Lotus Power',
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? AppTheme.dark : AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppStartup(child: DeviceDashboardScreen()),
    );
  }}