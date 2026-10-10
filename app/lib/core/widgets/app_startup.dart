import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../../l10n/app_localizations.dart';
import '../services/push_notification_service.dart';

/// Initializes Firebase + anonymous auth once. Retryable on failure.
final appInitProvider = FutureProvider<void>((ref) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // Not awaited on the critical path — a denied/slow permission prompt or
  // FCM hiccup shouldn't block the whole app from starting up.
  unawaited(PushNotificationService.initialize());
});

/// Wraps the app in an async startup gate. Shows a splash while Firebase
/// is initializing, an error + retry screen on failure, and the [child]
/// once ready. Never blocks `runApp`.
class AppStartup extends ConsumerWidget {
  const AppStartup({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitProvider);
    return init.when(
      loading: () => const _SplashScreen(),
      error: (error, _) => AppInitError(
        error: error,
        onRetry: () => ref.invalidate(appInitProvider),
      ),
      data: (_) => child,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Shown when Firebase initialization fails (e.g. device is offline).
class AppInitError extends StatelessWidget {
  const AppInitError({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  bool get _isOffline {
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('unreachable') ||
        msg.contains('unavailable');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                _isOffline ? l10n.offlineTitle : l10n.couldNotConnectTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isOffline ? l10n.offlineBody : l10n.genericStartupErrorBody,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retryBtn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
