import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';

/// App-bar icon that shows a count badge when active alerts exist.
/// Orange for warnings-only, red when any critical alert is present.
class NotificationBadgeIcon extends ConsumerWidget {
  const NotificationBadgeIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(activeAlertsCountProvider);
    final criticalAsync = ref.watch(criticalAlertsCountProvider);

    final total = totalAsync.valueOrNull ?? 0;
    final critical = criticalAsync.valueOrNull ?? 0;

    final icon = Icon(
      total > 0 ? Icons.notifications_active : Icons.notifications_none,
    );

    if (total == 0) {
      return IconButton(icon: icon, onPressed: null);
    }

    final label = total > 99 ? '99+' : '$total';
    final color = critical > 0 ? Colors.red : Colors.orange;

    return Badge(
      label: Text(label),
      backgroundColor: color,
      child: IconButton(icon: icon, onPressed: null),
    );
  }
}
