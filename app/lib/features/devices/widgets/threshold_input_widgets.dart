/// Reusable min/max stepper inputs used by the Settings screen.
///
/// Each stepper clamps to the sensor's absolute range and validates that
/// min < max before calling back, so a bad edit never reaches Firebase.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';

class ThresholdStepperInput extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String unit;
  final double minValue;
  final double maxValue;
  final double absoluteMin;
  final double absoluteMax;
  final double step;
  final Future<bool> Function(double min, double max) onChanged;
  final bool isDarkMode;

  const ThresholdStepperInput({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.absoluteMin,
    required this.absoluteMax,
    this.step = 0.5,
    required this.onChanged,
    required this.isDarkMode,
  });

  @override
  State<ThresholdStepperInput> createState() => _ThresholdStepperInputState();
}

class _ThresholdStepperInputState extends State<ThresholdStepperInput> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late double _currentMin;
  late double _currentMax;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentMin = widget.minValue;
    _currentMax = widget.maxValue;
    _minController = TextEditingController(text: _currentMin.toStringAsFixed(1));
    _maxController = TextEditingController(text: _currentMax.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(ThresholdStepperInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers when widget values change (e.g., from Firebase)
    if (oldWidget.minValue != widget.minValue || oldWidget.maxValue != widget.maxValue) {
      _currentMin = widget.minValue;
      _currentMax = widget.maxValue;
      _minController.text = _currentMin.toStringAsFixed(1);
      _maxController.text = _currentMax.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _updateMin(double newValue) async {
    if (_isSaving) return;
    if (newValue >= widget.absoluteMin && newValue < _currentMax) {
      setState(() => _isSaving = true);
      final success = await widget.onChanged(newValue, _currentMax);
      if (!mounted) return;
      if (success) {
        setState(() {
          _currentMin = newValue;
          _minController.text = newValue.toStringAsFixed(1);
          _isSaving = false;
        });
      } else {
        setState(() {
          _minController.text = _currentMin.toStringAsFixed(1);
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateMax(double newValue) async {
    if (_isSaving) return;
    if (newValue <= widget.absoluteMax && newValue > _currentMin) {
      setState(() => _isSaving = true);
      final success = await widget.onChanged(_currentMin, newValue);
      if (!mounted) return;
      if (success) {
        setState(() {
          _currentMax = newValue;
          _maxController.text = newValue.toStringAsFixed(1);
          _isSaving = false;
        });
      } else {
        setState(() {
          _maxController.text = _currentMax.toStringAsFixed(1);
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = widget.isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                // Forced LTR — see _statCard's comment in device_dashboard_screen.dart.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    l10n.plainRangeLabel(_currentMin.toStringAsFixed(1), _currentMax.toStringAsFixed(1), widget.unit),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.iconColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Min/Max Input Fields
          Row(
            children: [
              // Minimum Value
              Expanded(
                child: _buildStepperField(
                  label: l10n.minimumLabel,
                  controller: _minController,
                  value: _currentMin,
                  onDecrease: () { _updateMin(_currentMin - widget.step); },
                  onIncrease: () { _updateMin(_currentMin + widget.step); },
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      _updateMin(parsed);
                    }
                  },
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 16),

              // Arrow indicator
              Icon(
                Icons.arrow_forward,
                color: subtextColor,
                size: 20,
              ),
              const SizedBox(width: 16),

              // Maximum Value
              Expanded(
                child: _buildStepperField(
                  label: l10n.maximumLabel,
                  controller: _maxController,
                  value: _currentMax,
                  onDecrease: () { _updateMax(_currentMax - widget.step); },
                  onIncrease: () { _updateMax(_currentMax + widget.step); },
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      _updateMax(parsed);
                    }
                  },
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Valid range indicator (forced LTR for the embedded numeric
          // range — see _statCard's comment in device_dashboard_screen.dart)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              l10n.validRangeLabel(widget.absoluteMin.toStringAsFixed(0), widget.absoluteMax.toStringAsFixed(0), widget.unit),
              style: TextStyle(
                fontSize: 11,
                color: subtextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperField({
    required String label,
    required TextEditingController controller,
    required double value,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    required Function(String) onChanged,
    required Color? textColor,
    required Color? subtextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: subtextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              // Decrease button
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: _isSaving ? null : onDecrease,
                color: widget.iconColor,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),

              // Value input
              Expanded(
                child: SizedBox(
                  width: 80, // Fixed width to prevent text cutoff
                  child: TextField(
                    controller: controller,
                    enabled: !_isSaving,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, // Slightly smaller to fit better
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ),
              // Unit label outside text field
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  widget.unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Increase button
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: _isSaving ? null : onIncrease,
                color: widget.iconColor,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTION 2: Visual Range Card with Tap-to-Edit (MOST MODERN)
// ============================================================================
/// Modern visual approach:
/// - Visual temperature/humidity bar
/// - Tap on min/max to edit directly
/// - Color-coded safe/warning/danger zones
/// - More engaging and intuitive
class VisualRangeCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String unit;
  final double minValue;
  final double maxValue;
  final double absoluteMin;
  final double absoluteMax;
  final double currentReading; // Show current value on the bar
  final Function(double min, double max) onChanged;
  final bool isDarkMode;

  const VisualRangeCard({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.absoluteMin,
    required this.absoluteMax,
    required this.currentReading,
    required this.onChanged,
    required this.isDarkMode,
  });

  @override
  State<VisualRangeCard> createState() => _VisualRangeCardState();
}

class _VisualRangeCardState extends State<VisualRangeCard> {
  void _editValue(bool isMin) {
    final controller = TextEditingController(
      text: isMin 
        ? widget.minValue.toStringAsFixed(1)
        : widget.maxValue.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${isMin ? 'Minimum' : 'Maximum'} ${widget.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.unit,
            suffixText: widget.unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                if (isMin) {
                  widget.onChanged(value, widget.maxValue);
                } else {
                  widget.onChanged(widget.minValue, value);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.absoluteMax - widget.absoluteMin;
    final minPercent = (widget.minValue - widget.absoluteMin) / range;
    final maxPercent = (widget.maxValue - widget.absoluteMin) / range;
    final currentPercent = (widget.currentReading - widget.absoluteMin) / range;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.iconColor.withValues(alpha: 0.05),
            widget.iconColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.iconColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                widget.currentReading.toStringAsFixed(1) + widget.unit,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Visual Range Bar
          SizedBox(
            height: 60,
            child: Stack(
              children: [
                // Background track
                Positioned(
                  left: 0,
                  right: 0,
                  top: 25,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),

                // Safe range (green zone)
                Positioned(
                  left: minPercent * MediaQuery.of(context).size.width * 0.8,
                  right: (1 - maxPercent) * MediaQuery.of(context).size.width * 0.8,
                  top: 25,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),

                // Current value indicator
                Positioned(
                  left: currentPercent * MediaQuery.of(context).size.width * 0.8 - 2,
                  top: 20,
                  child: Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: widget.iconColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Min value marker
                Positioned(
                  left: minPercent * MediaQuery.of(context).size.width * 0.8 - 30,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => _editValue(true),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.iconColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.minValue.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 12,
                          color: widget.iconColor,
                        ),
                      ],
                    ),
                  ),
                ),

                // Max value marker
                Positioned(
                  left: maxPercent * MediaQuery.of(context).size.width * 0.8 - 30,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () => _editValue(false),
                    child: Column(
                      children: [
                        Container(
                          width: 2,
                          height: 12,
                          color: widget.iconColor,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.iconColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.maxValue.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Range labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.absoluteMin.toStringAsFixed(0)}${widget.unit}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              Text(
                'Tap min/max to edit',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                '${widget.absoluteMax.toStringAsFixed(0)}${widget.unit}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// OPTION 3: Preset Quick Select (FASTEST FOR USERS)
// ============================================================================
/// Quick selection for common scenarios:
/// - Preset buttons for typical ranges
/// - Custom option for advanced users
/// - Fastest UX for most users
class PresetThresholdSelector extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String unit;
  final double minValue;
  final double maxValue;
  final List<ThresholdPreset> presets;
  final Function(double min, double max) onChanged;
  final bool isDarkMode;

  const PresetThresholdSelector({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.presets,
    required this.onChanged,
    required this.isDarkMode,
  });

  @override
  State<PresetThresholdSelector> createState() => _PresetThresholdSelectorState();
}

class _PresetThresholdSelectorState extends State<PresetThresholdSelector> {
  late double _currentMin;
  late double _currentMax;

  @override
  void initState() {
    super.initState();
    _currentMin = widget.minValue;
    _currentMax = widget.maxValue;
  }

  @override
  void didUpdateWidget(PresetThresholdSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update when Firebase values change
    if (oldWidget.minValue != widget.minValue || oldWidget.maxValue != widget.maxValue) {
      setState(() {
        _currentMin = widget.minValue;
        _currentMax = widget.maxValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Use tolerance for floating point comparison (0.1 degree tolerance)
    final currentPreset = widget.presets.firstWhere(
      (p) => (p.min - _currentMin).abs() < 0.1 && (p.max - _currentMax).abs() < 0.1,
      orElse: () => ThresholdPreset(nameKey: 'custom', min: _currentMin, max: _currentMax),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.presets.map((preset) => _buildPresetChip(
                context,
                preset,
                currentPreset.nameKey == preset.nameKey,
              )),
              _buildCustomChip(context, currentPreset.nameKey == 'custom'),
            ],
          ),

          const SizedBox(height: 12),

          // Current range display with more space
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  // Forced LTR — see _statCard's comment in device_dashboard_screen.dart.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      l10n.plainRangeLabel(_currentMin.toStringAsFixed(1), _currentMax.toStringAsFixed(1), widget.unit),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.iconColor,
                        letterSpacing: 0.5, // Add letter spacing for better readability
                      ),
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(BuildContext context, ThresholdPreset preset, bool isSelected) {
    return ChoiceChip(
      label: Text(presetDisplayName(AppLocalizations.of(context), preset.nameKey)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _currentMin = preset.min;
          _currentMax = preset.max;
        });
        widget.onChanged(preset.min, preset.max);
      },
      selectedColor: widget.iconColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? widget.iconColor : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[700]),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCustomChip(BuildContext context, bool isSelected) {
    return ActionChip(
      label: Text(AppLocalizations.of(context).customLabel),
      onPressed: () {
        // Show custom input dialog
        _showCustomDialog(context);
      },
      backgroundColor: isSelected ? widget.iconColor.withValues(alpha: 0.2) : null,
      labelStyle: TextStyle(
        color: isSelected ? widget.iconColor : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[700]),
      ),
    );
  }

  void _showCustomDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minController = TextEditingController(text: _currentMin.toStringAsFixed(1));
    final maxController = TextEditingController(text: _currentMax.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.customRangeDialogTitle(widget.label)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              decoration: InputDecoration(
                labelText: l10n.minimumUnitLabel(widget.unit),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              decoration: InputDecoration(
                labelText: l10n.maximumUnitLabel(widget.unit),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelBtnGeneric),
          ),
          FilledButton(
            onPressed: () {
              final min = double.tryParse(minController.text);
              final max = double.tryParse(maxController.text);
              if (min != null && max != null) {
                setState(() {
                  _currentMin = min;
                  _currentMax = max;
                });
                widget.onChanged(min, max);
              }
              Navigator.pop(context);
            },
            child: Text(l10n.applyBtn),
          ),
        ],
      ),
    );
  }
}

/// [nameKey] is a stable identifier (not shown to the user) used for
/// selection matching and to look up the localized label via
/// [presetDisplayName] — the display text itself lives in the ARB files so
/// these presets aren't hardcoded to English.
class ThresholdPreset {
  final String nameKey;
  final double min;
  final double max;

  const ThresholdPreset({
    required this.nameKey,
    required this.min,
    required this.max,
  });
}

String presetDisplayName(AppLocalizations l10n, String nameKey) {
  switch (nameKey) {
    case 'chicks':
      return l10n.presetChicks;
    case 'young':
      return l10n.presetYoung;
    case 'growing':
      return l10n.presetGrowing;
    case 'adults':
      return l10n.presetAdults;
    case 'layers':
      return l10n.presetLayers;
    case 'dry_climate':
      return l10n.presetDryClimate;
    case 'standard':
      return l10n.presetStandard;
    case 'humid_climate':
      return l10n.presetHumidClimate;
    case 'hatching':
      return l10n.presetHatching;
    case 'custom':
      return l10n.customLabel;
    default:
      return nameKey;
  }
}

// Common presets for poultry farming (based on industry standards & scientific research)
class PoultryPresets {
  // Temperature ranges optimized for different bird ages
  // Source: Aviagen Broiler Management Guide, University of Georgia Poultry Science
  static const List<ThresholdPreset> temperature = [
    ThresholdPreset(nameKey: 'chicks', min: 32.0, max: 35.0),   // Critical - requires high heat
    ThresholdPreset(nameKey: 'young', min: 27.0, max: 30.0),    // Transition period
    ThresholdPreset(nameKey: 'growing', min: 24.0, max: 27.0),  // Active growth phase
    ThresholdPreset(nameKey: 'adults', min: 18.0, max: 24.0),   // Mature birds - lower temps
    ThresholdPreset(nameKey: 'layers', min: 20.0, max: 26.0),   // Egg production optimized
  ];

  // Humidity ranges for different climate conditions
  // Source: USDA Agricultural Research, FAO Poultry Welfare Standards
  static const List<ThresholdPreset> humidity = [
    ThresholdPreset(nameKey: 'dry_climate', min: 45.0, max: 65.0),    // Add moisture in arid regions
    ThresholdPreset(nameKey: 'standard', min: 50.0, max: 70.0),       // Ideal for most conditions
    ThresholdPreset(nameKey: 'humid_climate', min: 55.0, max: 75.0),  // Increase ventilation
    ThresholdPreset(nameKey: 'hatching', min: 50.0, max: 60.0),       // Specific for incubation
  ];
}
