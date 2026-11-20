import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:material_ui/material_ui.dart';

import '../../core/fx200_models.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'biquad_response.dart';
import 'model_art_view.dart';
import 'rotary_knob.dart';
import '../../core/l10n/l10n.dart';

typedef CabParamChanged = void Function(
  String parameterId,
  double value, {
  bool recordHistory,
});

/// Interactive CAB editor for the pedal's real CAB page
/// (TUBE, LOW CUT, HI CUT, SPACE, LEVEL):
///
/// * **Room** — the cabinet inside a room drawn in perspective; drag up/down
///   (or scroll) to change SPACE, double-click to reset it.
/// * **Response** — frequency curve with draggable LC / HC handles; drag a
///   handle past the edge of the plot to turn that cut OFF.
/// * **TUBE** selector and **LEVEL** knob.
///
/// The FX200 has no microphone placement, so the room / curve stand in for
/// the mic view other modelers show.
class CabDesigner extends StatelessWidget {
  const CabDesigner({
    super.key,
    required this.block,
    required this.accent,
    required this.onParameterChanged,
  });

  final EffectBlock block;
  final Color accent;
  final CabParamChanged onParameterChanged;

  /// True when [block] carries the 5 CAB parameters this editor expects.
  static bool supports(EffectBlock block) =>
      block.category == EffectCategory.cab && block.parameters.length >= 5;

  BlockParameter _param(int index) => block.parameters[index];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final tube = _param(0);
    final lowCut = _param(1);
    final hiCut = _param(2);
    final space = _param(3);
    final level = _param(4);

    void set(BlockParameter p, double v, {bool commit = true}) =>
        onParameterChanged(p.id, v, recordHistory: commit);

    final tubeIndex = tube.value.round().clamp(0, 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(tr('TUBE'), style: text.labelSmall),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (var i = 0; i < Fx200Models.cabTubeOptions.length; i++)
                  ButtonSegment<int>(
                    value: i,
                    label: Text(Fx200Models.cabTubeOptions[i]),
                  ),
              ],
              selected: <int>{tubeIndex},
              onSelectionChanged: (sel) => set(tube, sel.first.toDouble()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _Labeled(
              label: tr('SPACE {0}', [space.value.round()]),
              hint: tr('Drag up/down · double-click resets'),
              child: _RoomView(
                block: block,
                space: space,
                accent: accent,
                onChanged: (v, commit) => set(space, v, commit: commit),
              ),
            ),
            _Labeled(
              label: tr('LOW CUT {0} · HI CUT {1}', [
                _hzLabel(lowCut.value),
                _hzLabel(hiCut.value),
              ]),
              hint: tr('Drag LC / HC · past the edge = OFF'),
              child: _ResponseView(
                lowCut: lowCut,
                hiCut: hiCut,
                accent: accent,
                onLowCut: (v, commit) => set(lowCut, v, commit: commit),
                onHiCut: (v, commit) => set(hiCut, v, commit: commit),
              ),
            ),
            RotaryKnob(
              key: ValueKey<String>('${block.id}_${level.id}'),
              label: level.label,
              value: level.value,
              defaultValue: level.defaultValue,
              min: level.min,
              max: level.max,
              unit: level.unit,
              accentColor: accent,
              onChanged: (v) => set(level, v, commit: false),
              onChangeEnd: (v) => set(level, v),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'The FX200 has no microphone placement: SPACE adds room ambience, LOW / HI CUT shape the cabinet response.',
          ),
          style: text.bodySmall?.copyWith(color: ext.textMuted),
        ),
      ],
    );
  }

  static String _hzLabel(double hz) {
    if (hz <= 0) return 'OFF';
    return hz >= 1000
        ? '${(hz / 1000).toStringAsFixed(1)} kHz'
        : '${hz.round()} Hz';
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.label,
    required this.hint,
    required this.child,
  });

  final String label;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall),
        Text(
          hint,
          style: text.bodySmall?.copyWith(color: ext.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// ------------------------------------------------------------------- room

class _RoomView extends StatefulWidget {
  const _RoomView({
    required this.block,
    required this.space,
    required this.accent,
    required this.onChanged,
  });

  final EffectBlock block;
  final BlockParameter space;
  final Color accent;
  final void Function(double value, bool commit) onChanged;

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> {
  static const double _w = 280;
  static const double _h = 180;

  double? _dragStartY;
  double? _dragStartValue;
  double? _live;
  DateTime? _lastDown;

  double get _value => _live ?? widget.space.value;

  void _set(double v, {required bool commit}) {
    final clamped = v.clamp(widget.space.min, widget.space.max).roundToDouble();
    setState(() => _live = commit ? null : clamped);
    widget.onChanged(clamped, commit);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final t =
        (_value - widget.space.min) /
        math.max(1, widget.space.max - widget.space.min);
    // The cabinet moves back and shrinks as the room grows.
    final cabW = 118 - 46 * t;
    final cabH = cabW * 0.78;
    final floorY = _h * (0.86 - 0.22 * t);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: Listener(
        onPointerDown: (e) {
          final now = DateTime.now();
          if (_lastDown != null &&
              now.difference(_lastDown!) < const Duration(milliseconds: 350)) {
            _lastDown = null;
            _set(widget.space.defaultValue, commit: true);
            return;
          }
          _lastDown = now;
          _dragStartY = e.localPosition.dy;
          _dragStartValue = _value;
        },
        onPointerMove: (e) {
          if (_dragStartY == null) return;
          final dy = _dragStartY! - e.localPosition.dy;
          final range = widget.space.max - widget.space.min;
          _set(_dragStartValue! + dy / _h * range, commit: false);
        },
        onPointerUp: (_) {
          if (_dragStartY != null && _live != null) _set(_live!, commit: true);
          _dragStartY = null;
        },
        onPointerCancel: (_) {
          if (_dragStartY != null && _live != null) _set(_live!, commit: true);
          _dragStartY = null;
        },
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            _set(_value - e.scrollDelta.dy.sign * 2, commit: true);
          }
        },
        child: Container(
          key: ValueKey<String>('cab_room'),
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: ext.chassisBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ext.subtleBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoomPainter(
                    t: t,
                    accent: widget.accent,
                    line: ext.subtleBorder,
                    floorY: floorY,
                  ),
                ),
              ),
              Positioned(
                left: (_w - cabW) / 2,
                top: floorY - cabH,
                child: ModelArtView(
                  category: widget.block.category,
                  modelName: widget.block.modelName,
                  width: cabW,
                  height: cabH,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({
    required this.t,
    required this.accent,
    required this.line,
    required this.floorY,
  });

  /// SPACE normalised to 0..1.
  final double t;
  final Color accent;
  final Color line;
  final double floorY;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Back wall shrinks (room gets deeper) as SPACE grows.
    final backW = w * (0.78 - 0.5 * t);
    final backH = h * (0.7 - 0.38 * t);
    final back = Rect.fromCenter(
      center: Offset(w / 2, h * 0.42),
      width: backW,
      height: backH,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    canvas.drawRect(back, p);
    for (final corner in [
      (back.topLeft, Offset.zero),
      (back.topRight, Offset(w, 0)),
      (back.bottomLeft, Offset(0, h)),
      (back.bottomRight, Offset(w, h)),
    ]) {
      canvas.drawLine(corner.$1, corner.$2, p);
    }
    // Floor grid.
    final grid = Paint()
      ..strokeWidth = 1
      ..color = line.withValues(alpha: 0.6);
    for (var i = 1; i < 6; i++) {
      final k = i / 6;
      final y = back.bottom + (h - back.bottom) * k * k;
      final x0 = back.left * (1 - k * k);
      final x1 = w - (w - back.right) * (1 - k * k);
      canvas.drawLine(Offset(x0, y), Offset(x1, y), grid);
    }
    for (var i = 0; i <= 6; i++) {
      final fx = back.left + back.width * i / 6;
      canvas.drawLine(Offset(fx, back.bottom), Offset(w * i / 6, h), grid);
    }
    // Ambience: reflections spreading from the cabinet.
    final src = Offset(w / 2, floorY - 30 * (1 - 0.4 * t));
    final rings = (1 + t * 5).round();
    for (var i = 0; i < rings; i++) {
      final r = 34 + i * (12 + 26 * t);
      canvas.drawArc(
        Rect.fromCircle(center: src, radius: r),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accent.withValues(
            alpha: (0.55 - i * 0.08).clamp(0.08, 0.6) * (0.3 + 0.7 * t),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.t != t || old.accent != accent || old.floorY != floorY;
}

// --------------------------------------------------------------- response

enum _Handle { lowCut, hiCut }

class _ResponseView extends StatefulWidget {
  const _ResponseView({
    required this.lowCut,
    required this.hiCut,
    required this.accent,
    required this.onLowCut,
    required this.onHiCut,
  });

  final BlockParameter lowCut;
  final BlockParameter hiCut;
  final Color accent;
  final void Function(double value, bool commit) onLowCut;
  final void Function(double value, bool commit) onHiCut;

  @override
  State<_ResponseView> createState() => _ResponseViewState();
}

class _ResponseViewState extends State<_ResponseView> {
  static const double _w = 380;
  static const double _h = 180;

  _Handle? _dragging;
  _Handle? _hover;
  double? _liveLow;
  double? _liveHi;

  double get _low => _liveLow ?? widget.lowCut.value;
  double get _hi => _liveHi ?? widget.hiCut.value;

  _CutGeometry get _g => const _CutGeometry(Size(_w, _h));

  Offset _handlePos(_Handle h) {
    final g = _g;
    if (h == _Handle.lowCut) {
      final x = _low <= 0 ? g.offLowX : g.xForHz(_low);
      return Offset(x, g.bottom - 14);
    }
    final x = _hi <= 0 ? g.offHiX : g.xForHz(_hi);
    return Offset(x, g.bottom - 14);
  }

  _Handle? _hit(Offset p) {
    _Handle? best;
    var bestD = 26.0;
    for (final h in _Handle.values) {
      final d = (_handlePos(h).dx - p.dx).abs();
      if (d < bestD && p.dy > _g.top - 6) {
        bestD = d;
        best = h;
      }
    }
    return best;
  }

  double _valueFor(_Handle h, double x) {
    final g = _g;
    final hz = g.hzForX(x);
    if (h == _Handle.lowCut) {
      if (hz < Fx200Models.cabLowCutMinHz) return 0; // OFF zone
      return hz
          .clamp(Fx200Models.cabLowCutMinHz, Fx200Models.cabLowCutMaxHz)
          .roundToDouble();
    }
    if (hz > Fx200Models.cabHiCutMaxHz) return 0; // OFF zone
    return hz
        .clamp(Fx200Models.cabHiCutMinHz, Fx200Models.cabHiCutMaxHz)
        .roundToDouble();
  }

  void _move(double x, {required bool commit}) {
    final h = _dragging;
    if (h == null) return;
    final v = _valueFor(h, x);
    setState(() {
      if (h == _Handle.lowCut) {
        _liveLow = commit ? null : v;
      } else {
        _liveHi = commit ? null : v;
      }
    });
    (h == _Handle.lowCut ? widget.onLowCut : widget.onHiCut)(v, commit);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final active = _dragging ?? _hover;
    return MouseRegion(
      cursor: active != null
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.basic,
      onHover: (e) {
        final h = _hit(e.localPosition);
        if (h != _hover) setState(() => _hover = h);
      },
      onExit: (_) => setState(() => _hover = null),
      child: Listener(
        onPointerDown: (e) => setState(() => _dragging = _hit(e.localPosition)),
        onPointerMove: (e) => _move(e.localPosition.dx, commit: false),
        onPointerUp: (e) {
          _move(e.localPosition.dx, commit: true);
          setState(() => _dragging = null);
        },
        onPointerCancel: (e) {
          _move(e.localPosition.dx, commit: true);
          setState(() => _dragging = null);
        },
        child: Container(
          key: ValueKey<String>('cab_response'),
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: ext.chassisBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ext.subtleBorder),
          ),
          child: CustomPaint(
            painter: _ResponsePainter(
              geometry: _g,
              lowCut: _low,
              hiCut: _hi,
              accent: widget.accent,
              ext: ext,
              active: active,
              lowPos: _handlePos(_Handle.lowCut),
              hiPos: _handlePos(_Handle.hiCut),
              labelStyle:
                  Theme.of(context).textTheme.labelSmall ??
                  const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }
}

class _CutGeometry {
  const _CutGeometry(this.size);

  final Size size;

  static const double minHz = 14;
  static const double maxHz = 24000;

  double get left => 30;
  double get right => size.width - 10;
  double get top => 12;
  double get bottom => size.height - 22;
  double get width => right - left;
  double get height => bottom - top;

  /// Parked positions for OFF (outside the 20 Hz .. 20 kHz span).
  double get offLowX => xForHz(16);
  double get offHiX => xForHz(21000);

  double xForHz(double hz) {
    final t =
        (math.log(hz.clamp(minHz, maxHz)) - math.log(minHz)) /
        (math.log(maxHz) - math.log(minHz));
    return left + t * width;
  }

  double hzForX(double x) {
    final t = ((x - left) / width).clamp(0.0, 1.0);
    return math.exp(math.log(minHz) + t * (math.log(maxHz) - math.log(minHz)));
  }

  static const double maxDb = 6;
  static const double minDb = -24;

  double yForDb(double db) =>
      top + (maxDb - db.clamp(minDb, maxDb)) / (maxDb - minDb) * height;
}

class _ResponsePainter extends CustomPainter {
  _ResponsePainter({
    required this.geometry,
    required this.lowCut,
    required this.hiCut,
    required this.accent,
    required this.ext,
    required this.active,
    required this.lowPos,
    required this.hiPos,
    required this.labelStyle,
  });

  final _CutGeometry geometry;
  final double lowCut;
  final double hiCut;
  final Color accent;
  final FxEditorThemeExtension ext;
  final _Handle? active;
  final Offset lowPos;
  final Offset hiPos;
  final TextStyle labelStyle;

  void _text(Canvas c, String s, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: labelStyle.copyWith(color: color, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final grid = Paint()
      ..strokeWidth = 1
      ..color = ext.subtleBorder.withValues(alpha: 0.6);
    for (final hz in const [
      50.0,
      100.0,
      200.0,
      500.0,
      1000.0,
      2000.0,
      5000.0,
      10000.0,
      20000.0,
    ]) {
      final x = g.xForHz(hz);
      canvas.drawLine(Offset(x, g.top), Offset(x, g.bottom), grid);
      _text(
        canvas,
        hz >= 1000 ? '${(hz / 1000).round()}k' : '${hz.round()}',
        Offset(x, g.bottom + 11),
        ext.textMuted,
      );
    }
    for (final db in const [0.0, -12.0, -24.0]) {
      final y = g.yForDb(db);
      canvas.drawLine(Offset(g.left, y), Offset(g.right, y), grid);
      _text(
        canvas,
        db == 0 ? '0' : db.round().toString(),
        Offset(g.left - 14, y),
        ext.textMuted,
      );
    }
    // OFF zones.
    final offPaint = Paint()..color = ext.subtleBorder.withValues(alpha: 0.25);
    canvas.drawRect(
      Rect.fromLTRB(g.left, g.top, g.xForHz(20), g.bottom),
      offPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(g.xForHz(20000), g.top, g.right, g.bottom),
      offPaint,
    );

    final filters = <BiquadResponse>[
      if (lowCut > 0) BiquadResponse.highPass(lowCut),
      if (hiCut > 0) BiquadResponse.lowPass(hiCut),
    ];
    final path = Path();
    const steps = 200;
    for (var i = 0; i <= steps; i++) {
      final x = g.left + g.width * i / steps;
      final hz = g.hzForX(x);
      var db = 0.0;
      for (final f in filters) {
        db += f.dbAt(math.min(hz, 21000));
      }
      final y = g.yForDb(db);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(g.right, g.bottom)
      ..lineTo(g.left, g.bottom)
      ..close();
    canvas.drawPath(fill, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );

    void handle(Offset pos, String label, bool on, bool isActive) {
      canvas.drawLine(
        Offset(pos.dx, g.top),
        Offset(pos.dx, g.bottom),
        Paint()
          ..strokeWidth = 1
          ..color = accent.withValues(
            alpha: on ? (isActive ? 0.7 : 0.4) : 0.15,
          ),
      );
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: on ? 26 : 42, height: 17),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = ext.elevatedSurface);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 2 : 1.2
          ..color = on ? accent : ext.textMuted,
      );
      _text(
        canvas,
        on ? label : '$label OFF',
        pos,
        on ? ext.textPrimary : ext.textMuted,
      );
    }

    handle(lowPos, 'LC', lowCut > 0, active == _Handle.lowCut);
    handle(hiPos, 'HC', hiCut > 0, active == _Handle.hiCut);
  }

  @override
  bool shouldRepaint(covariant _ResponsePainter old) =>
      old.lowCut != lowCut ||
      old.hiCut != hiCut ||
      old.active != active ||
      old.accent != accent;
}
