import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/models/vision_models.dart';
import '../../../core/services/vision_alert_localizations.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/vision_repository.dart';

/// AI Monitor tab — vision analysis snapshot, trends, alerts, and editable
/// alarm thresholds. Ported from vision_alerts_prototype/{index.html,main.js}
/// with the same card
/// layout, styled with this app's own AppTheme/Card conventions instead of
/// the prototype's hand-rolled CSS, and fully localized (see
/// vision_alert_localizations.dart) instead of the prototype's fixed
/// English strings.
class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  bool _showResolved = false;

  static const _behaviorEatDrinkColor = Color(0xFF63B897);
  static const _behaviorMovingColor = Color(0xFFE5A93B);
  static const _behaviorRestColor = Color(0xFF1F5138);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final analysisAsync = ref.watch(visionAnalysisProvider);
    final historyAsync = ref.watch(visionHistoryProvider);
    final alertsAsync = ref.watch(allAlertsProvider);
    final thresholdsAsync = ref.watch(visionThresholdsProvider);
    final repo = ref.watch(visionRepositoryProvider);
    final thresholds = thresholdsAsync.valueOrNull ?? VisionThresholds.defaults;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : colors.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(visionAnalysisProvider);
          ref.invalidate(visionHistoryProvider);
          ref.invalidate(visionThresholdsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSnapshotCard(l10n, isDarkMode, colors, analysisAsync.valueOrNull, thresholds),
            const SizedBox(height: 16),
            _buildTrendsCard(l10n, isDarkMode, colors, historyAsync),
            const SizedBox(height: 16),
            _buildAlertsCard(l10n, isDarkMode, colors, alertsAsync),
            const SizedBox(height: 16),
            _buildThresholdsCard(l10n, isDarkMode, colors, thresholdsAsync, repo),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------- Snapshot ----------------

  Widget _buildSnapshotCard(
    AppLocalizations l10n,
    bool isDarkMode,
    ColorScheme colors,
    Map<dynamic, dynamic>? analysis,
    VisionThresholds thresholds,
  ) {
    final timestamp = (analysis?['timestamp'] as num?)?.toInt() ?? 0;
    final hasData = analysis != null && timestamp > 0;
    final ageMin = hasData
        ? (DateTime.now().millisecondsSinceEpoch - timestamp) / 60000
        : 0.0;
    final stale = hasData && ageMin > thresholds.staleMinutes;

    final behavior = (analysis?['behavior'] as Map?) ?? const {};
    final health = (analysis?['health'] as Map?) ?? const {};
    final breakdown = (behavior['behaviorBreakdown'] as Map?) ?? const {};
    final hotspot = (behavior['hotspot'] as Map?) ?? const {};

    final eatDrinkPct = (((breakdown['eatDrink'] as num?) ?? 0) * 100).round();
    final movingPct = (((breakdown['moving'] as num?) ?? 0) * 100).round();
    final restPct = (100 - eatDrinkPct - movingPct).clamp(0, 100);

    String statusLabel;
    Color statusColor;
    if (!hasData) {
      statusLabel = l10n.statusNoData;
      statusColor = Colors.grey;
    } else if (stale) {
      statusLabel = l10n.statusStale;
      statusColor = Colors.grey;
    } else {
      final status = (health['status'] as String?) ?? 'normal';
      statusLabel = localizedHealthStatus(l10n, status);
      statusColor = status == 'alert'
          ? colors.error
          : status == 'watch'
              ? colors.warning
              : colors.success;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.snapshotCardTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : colors.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.noDataYet,
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: _statTile(isDarkMode, '${behavior['birdCount'] ?? '—'}', l10n.statBirdsTracked)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      isDarkMode,
                      localizedActivityLevel(l10n, behavior['activityLevel'] as String?),
                      l10n.statActivityLevel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      isDarkMode,
                      '${health['healthy'] ?? 0} / ${health['unhealthy'] ?? 0}',
                      l10n.statHealthyUnhealthy,
                      forceLtrValue: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.behaviorMixLabel,
                style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      if (eatDrinkPct > 0) Expanded(flex: eatDrinkPct, child: Container(color: _behaviorEatDrinkColor)),
                      if (movingPct > 0) Expanded(flex: movingPct, child: Container(color: _behaviorMovingColor)),
                      if (restPct > 0) Expanded(flex: restPct, child: Container(color: _behaviorRestColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _legendDot(_behaviorEatDrinkColor, '${l10n.behaviorEatDrink} $eatDrinkPct%', isDarkMode),
                  _legendDot(_behaviorMovingColor, '${l10n.behaviorMoving} $movingPct%', isDarkMode),
                  _legendDot(_behaviorRestColor, '${l10n.behaviorRest} $restPct%', isDarkMode),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hotspot['row'] != null
                          ? l10n.hotspotInfo('${hotspot['row']}', '${hotspot['col']}', '${hotspot['intensity']}')
                          : l10n.hotspotUnknown,
                      style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                  Text(
                    stale
                        ? l10n.lastUpdatedStale(formatMinutesAgo(l10n, ageMin))
                        : l10n.lastUpdated(formatMinutesAgo(l10n, ageMin)),
                    style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // forceLtrValue: for "12 / 4"-style hand-built numeric strings, not one of
  // the ARB message templates (those get directional isolation from ICU
  // MessageFormat automatically). Confirmed on a real RTL device: without
  // this, Unicode bidi visually reorders "12 / 4" to read "4 / 12" inside
  // an RTL ancestor even though the logical string is correct — the data
  // was right, only the rendering flipped it.
  Widget _statTile(bool isDarkMode, String value, String label, {bool forceLtrValue = false}) {
    final valueText = Text(
      value,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          forceLtrValue ? Directionality(textDirection: TextDirection.ltr, child: valueText) : valueText,
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
      ],
    );
  }

  // ---------------- Trends ----------------

  Widget _buildTrendsCard(
    AppLocalizations l10n,
    bool isDarkMode,
    ColorScheme colors,
    AsyncValue<List<VisionRecord>> historyAsync,
  ) {
    final history = historyAsync.valueOrNull ?? const <VisionRecord>[];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trendsCardTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : colors.onSurface),
            ),
            const SizedBox(height: 12),
            if (history.length < 2)
              SizedBox(
                height: 60,
                child: Center(
                  child: Text(
                    l10n.trendsHint,
                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _sparkline(
                      l10n.trendBirdCount,
                      history.map((r) => r.birdCount.toDouble()).toList(),
                      colors.primary,
                      isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _sparkline(
                      l10n.trendUnhealthyPct,
                      history.map((r) => r.unhealthyPct).toList(),
                      colors.error,
                      isDarkMode,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _sparkline(String label, List<double> values, Color color, bool isDarkMode) {
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() < 0.01 ? 1.0 : (maxY - minY) * 0.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                  isCurved: true,
                  color: color,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Alerts ----------------

  Widget _buildAlertsCard(
    AppLocalizations l10n,
    bool isDarkMode,
    ColorScheme colors,
    AsyncValue<List<Alert>> alertsAsync,
  ) {
    final all = alertsAsync.valueOrNull ?? const <Alert>[];
    const sevRank = {'critical': 0, 'warning': 1, 'info': 2};
    final sorted = [...all.where((a) => _showResolved || !a.isResolved)]
      ..sort((a, b) {
        final ar = a.isResolved ? 1 : 0, br = b.isResolved ? 1 : 0;
        if (ar != br) return ar - br;
        final sr = (sevRank[a.severity] ?? 3) - (sevRank[b.severity] ?? 3);
        if (sr != 0) return sr;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.alertsCardTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : colors.onSurface),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.showResolved, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                    Switch(
                      value: _showResolved,
                      onChanged: (v) => setState(() => _showResolved = v),
                      activeColor: colors.primary,
                    ),
                  ],
                ),
              ],
            ),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.noAlertsYet,
                  style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              )
            else
              ...sorted.map((a) => _alertItem(l10n, isDarkMode, colors, a)),
          ],
        ),
      ),
    );
  }

  Widget _alertItem(AppLocalizations l10n, bool isDarkMode, ColorScheme colors, Alert alert) {
    final borderColor = alert.severity == 'critical'
        ? colors.error
        : alert.severity == 'warning'
            ? colors.warning
            : colors.info;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Opacity(
        opacity: alert.isResolved ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${alert.severityIcon} ${alert.localizedTypeName(l10n)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : colors.onSurface,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(alert.createdAt),
                  style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              alert.localizedMessage(l10n),
              style: TextStyle(fontSize: 12.5, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            if (alert.isResolved)
              Text(
                l10n.resolvedBtn,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              )
            else
              Row(
                children: [
                  OutlinedButton(
                    onPressed: alert.isAcknowledged
                        ? null
                        : () => ref.read(visionRepositoryProvider).acknowledgeAlert(alert.id),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(alert.isAcknowledged ? l10n.acknowledgedBtn : l10n.acknowledgeBtn, style: const TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => ref.read(visionRepositoryProvider).resolveAlert(alert.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(l10n.resolveBtn, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final d = dt.toLocal();
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ---------------- Thresholds ----------------

  Widget _buildThresholdsCard(
    AppLocalizations l10n,
    bool isDarkMode,
    ColorScheme colors,
    AsyncValue<VisionThresholds> thresholdsAsync,
    VisionRepository repo,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : colors.surface,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            l10n.thresholdsCardTitle,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDarkMode ? Colors.white : colors.onSurface),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            thresholdsAsync.when(
              data: (t) => _ThresholdsForm(
                key: ValueKey(t.toMap().toString()),
                initial: t,
                isDarkMode: isDarkMode,
                colors: colors,
                l10n: l10n,
                onSave: (updated) async {
                  await repo.saveThresholds(updated);
                  ref.invalidate(visionThresholdsProvider);
                },
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdsForm extends StatefulWidget {
  final VisionThresholds initial;
  final bool isDarkMode;
  final ColorScheme colors;
  final AppLocalizations l10n;
  final Future<void> Function(VisionThresholds) onSave;

  const _ThresholdsForm({
    super.key,
    required this.initial,
    required this.isDarkMode,
    required this.colors,
    required this.l10n,
    required this.onSave,
  });

  @override
  State<_ThresholdsForm> createState() => _ThresholdsFormState();
}

class _ThresholdsFormState extends State<_ThresholdsForm> {
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial.toMap();
    _controllers = {for (final e in m.entries) e.key: TextEditingController(text: '${e.value}')};
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(String key) => double.tryParse(_controllers[key]!.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final rows = <(String, String)>[
      ('unhealthyWarnPct', l10n.thUnhealthyWarnPct),
      ('unhealthyCriticalPct', l10n.thUnhealthyCriticalPct),
      ('activityLowSustainedCount', l10n.thActivityLowSustainedCount),
      ('birdCountDropPct', l10n.thBirdCountDropPct),
      ('birdCountSustainedCount', l10n.thBirdCountSustainedCount),
      ('hotspotSpikeRatio', l10n.thHotspotSpikeRatio),
      ('feedingStalledPct', l10n.thFeedingStalledPct),
      ('feedingSustainedCount', l10n.thFeedingSustainedCount),
      ('staleMinutes', l10n.thStaleMinutes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$2,
                      style: TextStyle(fontSize: 12, color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _controllers[row.$1],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 16),
              label: Text(l10n.thresholdsSaveBtn, style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: widget.colors.primary),
            ),
            if (_saved) ...[
              const SizedBox(width: 10),
              Text(l10n.thresholdsSaved, style: TextStyle(color: widget.colors.success, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    final updated = VisionThresholds(
      unhealthyWarnPct: _n('unhealthyWarnPct'),
      unhealthyCriticalPct: _n('unhealthyCriticalPct'),
      activityLowSustainedCount: _n('activityLowSustainedCount').round(),
      birdCountDropPct: _n('birdCountDropPct'),
      birdCountSustainedCount: _n('birdCountSustainedCount').round(),
      hotspotSpikeRatio: _n('hotspotSpikeRatio'),
      feedingStalledPct: _n('feedingStalledPct'),
      feedingSustainedCount: _n('feedingSustainedCount').round(),
      staleMinutes: _n('staleMinutes'),
    );
    await widget.onSave(updated);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }
}
