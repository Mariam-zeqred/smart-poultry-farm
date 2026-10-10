/// Smart Poultry Farm — app entry point.
///
/// Boots Flutter, installs a global error logger, and mounts [App] inside a
/// Riverpod [ProviderScope]. Firebase initialisation and anonymous sign-in
/// happen later, inside [AppStartup] (see core/widgets/app_startup.dart), so
/// the first frame is never blocked on the network.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // AppStartup (splash/error/data gate) lives INSIDE App's MaterialApp now
  // (see app.dart) rather than wrapping it — the splash and error screens
  // both render a Scaffold, which needs a Directionality/Localizations
  // ancestor that only MaterialApp provides. Wrapping App from the outside
  // put those screens outside that ancestor and crashed on first launch.
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
