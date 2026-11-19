import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'rotary_knob.dart';
import '../../core/l10n/l10n.dart';

typedef CompParamChanged = void Function(
  String parameterId,
  double value, {
  bool recordHistory,
});

/// Graphic editor for the FX module's compressors (CS COMP / JR COMP):
/// THRESHOLD (-60..0 dB), RATIO (1.0..10.0:1), ATTACK and LEVEL.
///
/// * **Transfer curve** — input vs output level. Drag the **T** node to set
///   THRESHOLD, drag the **R** node (right edge) up/down to set RATIO.
///   Double-click a node to reset it.
/// * **Attack** — shape of the gain-reduction onset (relative; the pedal
///   does not publish attack times).
/// * Knobs for all four parameters.
class CompressorDesigner extends StatelessWidget {
  const CompressorDesigner({
    super.key,
    required this.block,
    required this.accent,
    required this.onParameterChanged,
  });

  final EffectBlock block;
  final Color accent;
  final CompParamChanged onParameterChanged;

  /// CS COMP / JR COMP page: THRESHOLD, RATIO, ATTACK, LEVEL.
  static bool supports(EffectBlock block) =>
      block.category == EffectCategory.compressor &&
      block.parameters.length >= 4 &&
      block.parameters[0].label == 'THRESHOLD' &&
      block.parameters[1].label == 'RATIO';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final threshold = block.parameters[0];
    final ratio = block.parameters[1];
    final attack = block.parameters[2];
    final level = block.parameters[3];

    void set(BlockParameter p, double raw, {bool commit = true}) =>
        onParameterChanged(p.id, raw, recordHistory: commit);

    final t = threshold.displayValue;
    final r = ratio.displayValue;
    final reductionAt0 = -t * (1 - 1 / r);

    Widget knob(BlockParameter p) => RotaryKnob(
      key: ValueKey<String>('${block.id}_${p.id}'),
      label: p.label,
      value: p.value,
      defaultValue: p.defaultValue,
      min: p.min,
      max: p.max,
      unit: p.unit,
      formatter: p.textOf,
      parser: p.rawFromText,
      accentColor: accent,
      onChanged: (v) => set(p, v, commit: false),
      onChangeEnd: (v) => set(p, v),
    );

    return Wrap(
      spacing: 18,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('THRESHOLD {0} · RATIO {1}', [
                  threshold.displayText,
                  ratio.displayText,
                ]),
                style: text.labelSmall,
              ),
              Text(
                tr('Drag T (threshold) and R (ratio) · double-click resets'),
                style: text.bodySmall?.copyWith(
                  color: ext.textMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              _TransferCurve(
                threshold: threshold,
                ratio: ratio,
                accent: accent,
                onThreshold: (v, c) => set(threshold, v, commit: c),
                onRatio: (v, c) => set(ratio, v, commit: c),
              ),
              const SizedBox(height: 4),
              Text(
                tr('Max gain reduction (0 dB in): {0} dB', [
                  reductionAt0.toStringAsFixed(1),
                ]),
                style: text.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [knob(threshold), knob(ratio)],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [knob(attack), knob(level)],
            ),
            const SizedBox(height: 12),
            Text(
              tr('ATTACK {0}', [attack.displayText]),
              style: text.labelSmall,
            ),
            Text(
              tr('Gain-reduction onset (relative shape)'),
              style: text.bodySmall?.copyWith(
                color: ext.textMuted,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              key: ValueKey<String>('comp_attack'),
              width: 200,
              height: 70,
              child: CustomPaint(
                painter: _AttackPainter(
                  attack:
                      (attack.value - attack.min) /
                      math.max(1, attack.max - attack.min),
                  depthDb: reductionAt0,
                  accent: accent,
                  grid: ext.subtleBorder,
                  surface: ext.chassisBackground,
                  label: ext.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransferCurve extends StatefulWidget {
  const _TransferCurve({
    required this.threshold,
    required this.ratio,
    required this.accent,
    required this.onThreshold,
    required this.onRatio,
  });

  final BlockParameter threshold;
  final BlockParameter ratio;
  final Color accent;
  final void Function(double raw, bool commit) onThreshold;
  final void Function(double raw, bool commit) onRatio;

  @override
  State<_TransferCurve> createState() => _TransferCurveState();
}

enum _Node { threshold, ratio }

class _TransferCurveState extends State<_TransferCurve> {
  static const double size = 280;
  static const double pad = 30;
  static const double plot = size - pad - 10;

  _Node? _drag;
  double? _lastRaw;
  DateTime? _lastDown;
  _Node? _lastDownNode;

  static double xFor(double db) => pad + (db + 60) / 60 * plot;
  static double yFor(double db) => 10 + (0 - db) / 60 * plot;
  static double dbForX(double x) => ((x - pad) / plot * 60 - 60).clamp(-60, 0);
  static double dbForY(double y) => (-(y - 10) / plot * 60).clamp(-60, 0);

  double get _t => widget.threshold.displayValue;
  double get _r => widget.ratio.displayValue;

  Offset get _tNode => Offset(xFor(_t), yFor(_t));
  Offset get _rNode => Offset(xFor(0), yFor(_t + (0 - _t) / _r));

  _Node? _hit(Offset p) {
    if ((p - _rNode).distance <= 16) return _Node.ratio;
    if ((p - _tNode).distance <= 16) return _Node.threshold;
    return null;
  }

  void _down(PointerDownEvent e) {
    if (e.buttons != kPrimaryButton) return;
    final node = _hit(e.localPosition);
    final now = DateTime.now();
    final isDouble =
        node != null &&
        node == _lastDownNode &&
        _lastDown != null &&
        now.difference(_lastDown!) < const Duration(milliseconds: 350);
    _lastDown = now;
    _lastDownNode = node;
    if (isDouble) {
      if (node == _Node.threshold) {
        widget.onThreshold(widget.threshold.defaultValue, true);
      } else {
        widget.onRatio(widget.ratio.defaultValue, true);
      }
      setState(() => _drag = null);
      return;
    }
    setState(() {
      _drag = node;
      _lastRaw = null;
    });
  }

  void _move(PointerMoveEvent e) {
    final p = e.localPosition;
    switch (_drag) {
      case _Node.threshold:
        // Follow the unity line: use the mean of the x and y readings.
        final db = (dbForX(p.dx) + dbForY(p.dy)) / 2;
        _lastRaw = widget.threshold.rawFor(db);
        widget.onThreshold(_lastRaw!, false);
      case _Node.ratio:
        final t = _t;
        final out = dbForY(p.dy);
        // out = t + (0 - t) / r  →  r = -t / (out - t)
        final above = out - t;
        final r = above <= 0.01 ? 10.0 : (-t / above).clamp(1.0, 10.0);
        _lastRaw = widget.ratio.rawFor(r);
        widget.onRatio(_lastRaw!, false);
      case null:
        break;
    }
  }

  void _up() {
    final raw = _lastRaw;
    if (raw != null) {
      if (_drag == _Node.threshold) widget.onThreshold(raw, true);
      if (_drag == _Node.ratio) widget.onRatio(raw, true);
    }
    setState(() {
      _drag = null;
      _lastRaw = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    return Listener(
      key: ValueKey<String>('comp_curve'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: MouseRegion(
        cursor: _drag == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.grabbing,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CurvePainter(
              threshold: _t,
              ratio: _r,
              activeNode: _drag,
              accent: widget.accent,
              grid: ext.subtleBorder,
              surface: ext.chassisBackground,
              label: ext.textMuted,
              text: ext.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.threshold,
    required this.ratio,
    required this.activeNode,
    required this.accent,
    required this.grid,
    required this.surface,
    required this.label,
    required this.text,
  });

  final double threshold;
  final double ratio;
  final _Node? activeNode;
  final Color accent;
  final Color grid;
  final Color surface;
  final Color label;
  final Color text;

  double _x(double db) => _TransferCurveState.xFor(db);
  double _y(double db) => _TransferCurveState.yFor(db);

  void _text(Canvas c, String s, Offset at, {double size = 9, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color ?? label, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTRB(_x(-60), _y(0), _x(0), _y(-60));
    canvas.drawRRect(
      RRect.fromRectAndRadius(area.inflate(2), const Radius.circular(6)),
      Paint()..color = surface,
    );
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var db = -60; db <= 0; db += 10) {
      canvas.drawLine(
        Offset(_x(db.toDouble()), area.top),
        Offset(_x(db.toDouble()), area.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(area.left, _y(db.toDouble())),
        Offset(area.right, _y(db.toDouble())),
        gridPaint,
      );
      _text(canvas, '$db', Offset(_x(db.toDouble()), area.bottom + 9));
      _text(canvas, '$db', Offset(area.left - 14, _y(db.toDouble())));
    }
    _text(canvas, 'IN dB', Offset(area.center.dx, area.bottom + 20));

    // Unity line.
    canvas.drawLine(
      Offset(_x(-60), _y(-60)),
      Offset(_x(0), _y(0)),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    // Gain-reduction area between unity and the curve.
    final t = threshold;
    final outAt0 = t + (0 - t) / ratio;
    final gr = Path()
      ..moveTo(_x(t), _y(t))
      ..lineTo(_x(0), _y(0))
      ..lineTo(_x(0), _y(outAt0))
      ..close();
    canvas.drawPath(gr, Paint()..color = accent.withValues(alpha: 0.16));

    // Threshold guide.
    final dash = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var y = area.top; y < area.bottom; y += 6) {
      canvas.drawLine(
        Offset(_x(t), y),
        Offset(_x(t), math.min(y + 3, area.bottom)),
        dash,
      );
    }

    // Transfer curve (hard knee).
    final curve = Path()
      ..moveTo(_x(-60), _y(-60))
      ..lineTo(_x(t), _y(t))
      ..lineTo(_x(0), _y(outAt0));
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );

    void node(Offset c, String s, bool active) {
      canvas.drawCircle(c, active ? 10 : 8.5, Paint()..color = accent);
      canvas.drawCircle(
        c,
        active ? 10 : 8.5,
        Paint()
          ..color = text
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1.2,
      );
      _text(canvas, s, c, size: 9, color: text);
    }

    node(Offset(_x(t), _y(t)), 'T', activeNode == _Node.threshold);
    node(Offset(_x(0), _y(outAt0)), 'R', activeNode == _Node.ratio);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.threshold != threshold ||
      old.ratio != ratio ||
      old.activeNode != activeNode ||
      old.accent != accent;
}

class _AttackPainter extends CustomPainter {
  _AttackPainter({
    required this.attack,
    required this.depthDb,
    required this.accent,
    required this.grid,
    required this.surface,
    required this.label,
  });

  /// 0..1 position of the ATTACK control.
  final double attack;
  final double depthDb;
  final Color accent;
  final Color grid;
  final Color surface;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()..color = surface,
    );
    final top = 8.0, bottom = size.height - 8;
    final onset = size.width * 0.18;
    // Depth of the dip scales with the max gain reduction (up to ~54 dB).
    final depth = (depthDb / 54).clamp(0.08, 1.0) * (bottom - top);
    final tau = 0.02 + attack * 0.45; // fraction of the width
    canvas.drawLine(
      Offset(0, top),
      Offset(size.width, top),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    final path = Path()..moveTo(0, top);
    path.lineTo(onset, top);
    for (var x = onset; x <= size.width; x += 2) {
      final k = 1 - math.exp(-((x - onset) / size.width) / tau);
      path.lineTo(x, top + depth * k);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: tr('GR'),
        style: TextStyle(color: label, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(4, bottom - tp.height));
  }

  @override
  bool shouldRepaint(covariant _AttackPainter old) =>
      old.attack != attack || old.depthDb != depthDb || old.accent != accent;
}
