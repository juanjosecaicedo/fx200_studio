import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';

/// Reusable hardware-style rotary knob rendered with [CustomPainter].
///
/// Supports vertical drag, double-tap to reset to [defaultValue], and displays
/// the live numeric value while interacting.
class RotaryKnob extends StatefulWidget {
  const RotaryKnob({
    super.key,
    required this.label,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.accentColor,
    required this.onChanged,
    this.onChangeEnd,
    this.unit = '',
    this.size = 64,
  });

  final String label;
  final double value;
  final double defaultValue;
  final double min;
  final double max;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String unit;
  final double size;

  @override
  State<RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<RotaryKnob> {
  bool _isDragging = false;
  double _dragStartValue = 0;
  double _dragStartDy = 0;

  double get _normalized {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    return ((widget.value - widget.min) / span).clamp(0.0, 1.0);
  }

  String _formatValue(double v) {
    final decimals = (widget.max - widget.min) <= 30 ? 1 : 0;
    final numStr = v.toStringAsFixed(decimals);
    return widget.unit.isEmpty ? numStr : '$numStr ${widget.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: ext.transitionDuration,
          opacity: _isDragging ? 1.0 : 0.78,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _isDragging ? ext.elevatedSurface : ext.blockSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isDragging ? widget.accentColor : ext.subtleBorder,
              ),
            ),
            child: Text(
              _formatValue(widget.value),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _isDragging ? widget.accentColor : ext.textPrimary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onDoubleTap: () {
            widget.onChanged(widget.defaultValue);
            widget.onChangeEnd?.call(widget.defaultValue);
          },
          onVerticalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragStartValue = widget.value;
              _dragStartDy = details.globalPosition.dy;
            });
          },
          onVerticalDragUpdate: (details) {
            final dy = _dragStartDy - details.globalPosition.dy;
            final span = widget.max - widget.min;
            final next =
                (_dragStartValue + (dy / 140.0) * span).clamp(widget.min, widget.max);
            widget.onChanged(next);
          },
          onVerticalDragEnd: (_) {
            setState(() => _isDragging = false);
            widget.onChangeEnd?.call(widget.value);
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _RotaryKnobPainter(
                normalized: _normalized,
                accentColor: widget.accentColor,
                trackColor: ext.subtleBorder,
                bodyColor: ext.elevatedSurface,
                capColor: ext.blockSurface,
                indicatorColor: ext.textPrimary,
                isDragging: _isDragging,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _RotaryKnobPainter extends CustomPainter {
  const _RotaryKnobPainter({
    required this.normalized,
    required this.accentColor,
    required this.trackColor,
    required this.bodyColor,
    required this.capColor,
    required this.indicatorColor,
    required this.isDragging,
  });

  final double normalized;
  final Color accentColor;
  final Color trackColor;
  final Color bodyColor;
  final Color capColor;
  final Color indicatorColor;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (math.min(size.width, size.height) / 2) - 4;
    const startAngle = 135 * math.pi / 180;
    const sweepTotal = 270 * math.pi / 180;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: outerRadius);
    canvas.drawArc(arcRect, startAngle, sweepTotal, false, trackPaint);

    if (normalized > 0) {
      final activePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDragging ? 4.2 : 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        arcRect,
        startAngle,
        sweepTotal * normalized,
        false,
        activePaint,
      );
    }

    final knobRadius = outerRadius - 6;
    final bodyPaint = Paint()..color = bodyColor;
    canvas.drawCircle(center, knobRadius, bodyPaint);

    final capPaint = Paint()
      ..color = capColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, knobRadius, capPaint);

    final angle = startAngle + sweepTotal * normalized;
    final p1 = center + Offset(math.cos(angle), math.sin(angle)) * (knobRadius * 0.28);
    final p2 = center + Offset(math.cos(angle), math.sin(angle)) * (knobRadius * 0.84);

    final pointerPaint = Paint()
      ..color = isDragging ? accentColor : indicatorColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, pointerPaint);
  }

  @override
  bool shouldRepaint(covariant _RotaryKnobPainter oldDelegate) {
    return oldDelegate.normalized != normalized ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDragging != isDragging;
  }
}
