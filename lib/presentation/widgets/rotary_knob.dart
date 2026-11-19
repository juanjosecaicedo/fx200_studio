import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';

/// Arc geometry shared by the painter and the click-to-set hit test:
/// 270° clockwise from bottom-left (135°) to bottom-right (45°).
const double _kStartAngle = 135 * math.pi / 180;
const double _kSweepTotal = 270 * math.pi / 180;

/// Reusable hardware-style rotary knob rendered with [CustomPainter].
///
/// Supports vertical drag, clicking a point of the arc to jump there,
/// double-click to reset to [defaultValue], and an editable value field
/// above the knob for typing an exact value.
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
    this.formatter,
    this.parser,
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

  /// Optional text for a value (e.g. raw 480 → "500 ms").
  final String Function(double value)? formatter;

  /// Optional inverse of [formatter]: raw value for typed text, or null if
  /// the text is not a valid value. Without it the first number in the text
  /// is taken as the raw value.
  final double? Function(String text)? parser;

  @override
  State<RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<RotaryKnob> {
  bool _isDragging = false;
  double _dragStartValue = 0;
  double _dragStartDy = 0;

  /// Manual double-click detection, so a single click on the arc applies
  /// immediately instead of waiting for the double-tap timeout.
  DateTime? _lastTapTime;
  Offset? _lastTapPos;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController.text = _formatValue(widget.value);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant RotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow external changes (drag, pedal, undo) unless the user is typing.
    if (!_focusNode.hasFocus) {
      final text = _formatValue(widget.value);
      if (_textController.text != text) _textController.text = text;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  double get _normalized {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    return ((widget.value - widget.min) / span).clamp(0.0, 1.0);
  }

  String _formatValue(double v) {
    final f = widget.formatter;
    if (f != null) return f(v);
    final decimals = (widget.max - widget.min) <= 30 ? 1 : 0;
    final numStr = v.toStringAsFixed(decimals);
    return widget.unit.isEmpty ? numStr : '$numStr ${widget.unit}';
  }

  double? _parseValue(String text) {
    final p = widget.parser;
    if (p != null) return p(text);
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(text);
    if (m == null) return null;
    final v = double.parse(m.group(0)!.replaceAll(',', '.'));
    return v.roundToDouble().clamp(widget.min, widget.max);
  }

  void _commit(double v) {
    widget.onChanged(v);
    widget.onChangeEnd?.call(v);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    } else {
      _submitText();
    }
    setState(() {});
  }

  /// Applies the typed text; invalid text just reverts to the current value.
  void _submitText() {
    final v = _parseValue(_textController.text);
    if (v != null && v != widget.value) _commit(v);
    _textController.text = _formatValue(v ?? widget.value);
  }

  void _cancelEdit() {
    _textController.text = _formatValue(widget.value);
    _focusNode.unfocus();
  }

  /// Value for a click at [local] (knob coordinates), or null when the
  /// click is too close to the centre to have a meaningful angle.
  double? _valueAt(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final d = local - center;
    if (d.distance < widget.size * 0.12) return null;
    var rel = (math.atan2(d.dy, d.dx) - _kStartAngle) % (2 * math.pi);
    if (rel < 0) rel += 2 * math.pi;
    final double n;
    if (rel <= _kSweepTotal) {
      n = rel / _kSweepTotal;
    } else {
      // Bottom gap: snap to the nearer end of the arc.
      n = rel < _kSweepTotal + (2 * math.pi - _kSweepTotal) / 2 ? 1.0 : 0.0;
    }
    final v = widget.min + n * (widget.max - widget.min);
    return v.roundToDouble().clamp(widget.min, widget.max);
  }

  void _onTapUp(TapUpDetails details) {
    final now = DateTime.now();
    final last = _lastTapTime;
    final lastPos = _lastTapPos;
    final isDouble =
        last != null &&
        lastPos != null &&
        now.difference(last) < const Duration(milliseconds: 300) &&
        (details.localPosition - lastPos).distance < 12;
    if (isDouble) {
      _lastTapTime = null;
      _lastTapPos = null;
      _commit(widget.defaultValue);
      return;
    }
    _lastTapTime = now;
    _lastTapPos = details.localPosition;
    final v = _valueAt(details.localPosition);
    if (v != null && v != widget.value) _commit(v);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final active = _isDragging || _focusNode.hasFocus;
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: active ? widget.accentColor : ext.textPrimary,
      letterSpacing: 0.4,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: ext.transitionDuration,
          opacity: active ? 1.0 : 0.78,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: active ? ext.elevatedSurface : ext.blockSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: active ? widget.accentColor : ext.subtleBorder,
              ),
            ),
            constraints: BoxConstraints(
              minWidth: 32,
              maxWidth: math.max(widget.size + 16, 72),
            ),
            child: IntrinsicWidth(
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.escape): _cancelEdit,
                },
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  cursorColor: widget.accentColor,
                  cursorHeight: (valueStyle?.fontSize ?? 11) + 2,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  // Losing focus applies the text (see _onFocusChange).
                  onSubmitted: (_) => _focusNode.unfocus(),
                  onTapOutside: (_) => _focusNode.unfocus(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTapUp: _onTapUp,
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
            final next = (_dragStartValue + (dy / 140.0) * span).clamp(
              widget.min,
              widget.max,
            );
            widget.onChanged(next.roundToDouble());
          },
          onVerticalDragEnd: (_) {
            setState(() => _isDragging = false);
            widget.onChangeEnd?.call(widget.value);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
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
    const startAngle = _kStartAngle;
    const sweepTotal = _kSweepTotal;

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
    final p1 =
        center + Offset(math.cos(angle), math.sin(angle)) * (knobRadius * 0.28);
    final p2 =
        center + Offset(math.cos(angle), math.sin(angle)) * (knobRadius * 0.84);

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
