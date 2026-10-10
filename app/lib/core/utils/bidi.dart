/// Wraps a numeric-range fragment (e.g. "18-24") in Unicode directional
/// isolate marks so it keeps its own internal order when embedded in RTL
/// text.
///
/// Root cause: our l10n templates use String-typed placeholders (not
/// num/int) so we control decimal formatting ourselves instead of letting
/// intl's NumberFormat pick a locale numbering system (which would render
/// Eastern Arabic-Indic digits for `ar` — see vision_alert_localizations.dart
/// for that decision). The tradeoff is that intl's automatic bidi isolation
/// for *typed* numeric arguments doesn't apply either. Confirmed on a real
/// RTL device: without this, "{low}-{high}" (two separate embedded LTR
/// digit-runs joined by a dash) visually reorders to "{high}-{low}" inside
/// Arabic text, even though wrapping the rendered Text widget in
/// `Directionality(textDirection: ltr)` does NOT fix it — that only sets
/// paragraph base direction, it doesn't stop same-level runs from being
/// ordered right-to-left relative to each other. Isolating the whole
/// "low-high" fragment as one LTR run is what actually works.
///
/// Uses String.fromCharCode (not literal characters in source) so the
/// zero-width marks can't be silently corrupted by an editor/tool that
/// doesn't round-trip invisible Unicode correctly.
final String _lri = String.fromCharCode(0x2066); // LEFT-TO-RIGHT ISOLATE
final String _pdi = String.fromCharCode(0x2069); // POP DIRECTIONAL ISOLATE

String isolateLtr(String s) => '$_lri$s$_pdi';
