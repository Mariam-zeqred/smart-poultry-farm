/// Bridges vision alert data to the localized (English/Arabic) strings the
/// UI shows. Kept separate from vision_alert_engine.dart and the Alert
/// model on purpose: the engine and the model stay UI-agnostic (no
/// BuildContext, no AppLocalizations), and this file is the only place that
/// knows how to turn `type` + `params` into text a user reads.
///
/// Numbers are pre-formatted to plain Dart strings (Western digits) rather
/// than passed as typed ICU placeholders — see the placeholder types in
/// app_en.arb. This keeps every rendered number consistent regardless of
/// locale, since `intl`'s default number formatting for `ar` would otherwise
/// render Eastern Arabic-Indic digits for `int`/`num` placeholders while the
/// percentage values (already formatted as strings for precision control)
/// stayed Western — a jarring mix in a technical monitoring screen.
library;

import '../models/alert_model.dart';
import '../models/vision_models.dart';
import '../../l10n/app_localizations.dart';

String _pct(num v) => v.toStringAsFixed(1);
String _int(num v) => v.round().toString();

/// "just now" / "5 min ago" — used for both the snapshot's "last updated"
/// line and anywhere else a short relative time reads naturally.
String formatMinutesAgo(AppLocalizations l10n, double ageMinutes) {
  final clamped = ageMinutes < 0 ? 0.0 : ageMinutes;
  if (clamped < 1) return l10n.justNow;
  return l10n.minutesAgo(clamped.round());
}

String localizedActivityLevel(AppLocalizations l10n, String? level) {
  switch (level) {
    case 'high':
      return l10n.activityHigh;
    case 'medium':
      return l10n.activityMedium;
    case 'low':
      return l10n.activityLow;
    default:
      return l10n.activityUnknown;
  }
}

String localizedHealthStatus(AppLocalizations l10n, String? status) {
  switch (status) {
    case 'alert':
      return l10n.statusAlert;
    case 'watch':
      return l10n.statusWatch;
    case 'normal':
      return l10n.statusNormal;
    default:
      return l10n.statusNormal;
  }
}

/// Covers both the vision_* types this app writes and the sensor types the
/// ESP32 firmware writes (temperature_high, gas_critical, ...) — an alert
/// list showing both sources renders every known type through one function.
String localizedAlertTypeName(AppLocalizations l10n, String type) {
  switch (type) {
    case 'temperature_high':
      return l10n.alertTypeTemperatureHigh;
    case 'temperature_low':
      return l10n.alertTypeTemperatureLow;
    case 'humidity_high':
      return l10n.alertTypeHumidityHigh;
    case 'humidity_low':
      return l10n.alertTypeHumidityLow;
    case 'gas_detected':
      return l10n.alertTypeGasDetected;
    case 'gas_critical':
      return l10n.alertTypeGasCritical;
    case 'temp_critical_low':
      return l10n.alertTypeTempCriticalLow;
    case 'temp_critical_high':
      return l10n.alertTypeTempCriticalHigh;
    case 'hum_critical_low':
      return l10n.alertTypeHumCriticalLow;
    case 'hum_critical_high':
      return l10n.alertTypeHumCriticalHigh;
    case 'vision_stale':
      return l10n.alertTypeVisionStale;
    case 'vision_unhealthy_rate':
      return l10n.alertTypeVisionUnhealthyRate;
    case 'vision_activity_low':
      return l10n.alertTypeVisionActivityLow;
    case 'vision_bird_count_drop':
      return l10n.alertTypeVisionBirdCountDrop;
    case 'vision_overcrowding':
      return l10n.alertTypeVisionOvercrowding;
    case 'vision_feeding_stalled':
      return l10n.alertTypeVisionFeedingStalled;
    case 'vision_combined_health_activity_risk':
      return l10n.alertTypeVisionCombinedHealthActivity;
    case 'vision_combined_mortality_risk':
      return l10n.alertTypeVisionCombinedMortality;
    default:
      return type.replaceAll('_', ' ').toUpperCase();
  }
}

extension VisionAlertLocalization on Alert {
  String localizedTypeName(AppLocalizations l10n) => localizedAlertTypeName(l10n, type);

  /// Rebuilds the message from `type` + `params` in the current locale.
  /// Falls back to the stored (English) `message` for alerts that have no
  /// `params` — i.e. every sensor alert the ESP32 firmware writes, or a
  /// vision alert from before this field existed.
  String localizedMessage(AppLocalizations l10n) {
    final p = params;
    final visionType = VisionAlertType.fromWire(type);
    if (p == null || visionType == null) return message;

    switch (visionType) {
      case VisionAlertType.visionStale:
        return l10n.msgVisionStale(_int(p['minutes'] ?? 0));
      case VisionAlertType.visionUnhealthyRate:
        return l10n.msgVisionUnhealthyRate(
          _pct(p['pct'] ?? 0),
          _int(p['unhealthy'] ?? 0),
          _int(p['total'] ?? 0),
        );
      case VisionAlertType.visionActivityLow:
        return l10n.msgVisionActivityLow(_int(p['count'] ?? 0));
      case VisionAlertType.visionBirdCountDrop:
        return l10n.msgVisionBirdCountDrop(
          _int(p['count'] ?? 0),
          _pct(p['pct'] ?? 0),
          _int(p['baseline'] ?? 0),
        );
      case VisionAlertType.visionOvercrowding:
        return l10n.msgVisionOvercrowding(
          (p['ratio'] ?? 0).toStringAsFixed(2),
          (p['multiplier'] ?? 0).toStringAsFixed(1),
          _int(p['row'] ?? 0),
          _int(p['col'] ?? 0),
        );
      case VisionAlertType.visionFeedingStalled:
        return l10n.msgVisionFeedingStalled(_pct(p['pct'] ?? 0), _int(p['count'] ?? 0));
      case VisionAlertType.visionCombinedHealthActivityRisk:
        return l10n.msgVisionCombinedHealthActivity(_pct(p['pct'] ?? 0));
      case VisionAlertType.visionCombinedMortalityRisk:
        return l10n.msgVisionCombinedMortality(
          _int(p['count'] ?? 0),
          _int(p['baseline'] ?? 0),
          _pct(p['pct'] ?? 0),
        );
    }
  }
}
