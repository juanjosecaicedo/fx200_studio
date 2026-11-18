import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_protocol.dart';
import 'biquad_response.dart';

/// Draggable nodes of the global EQ graph.
enum GlobalEqNode { lowCut, low, mid, high, highCut }

/// Interactive graphic editor for the pedal's GLOBAL EQ (`0xA1`):
/// three peaking bands (drag horizontally = frequency, vertically = gain)
/// plus LOW CUT / HIGH CUT handles (drag horizontally).
///
/// The response curve is drawn with RBJ biquads at 44.1 kHz (peaking Q 0.9,
/// 12 dB/oct cuts). The pedal's exact filter shapes are not known, so the
/// curve is a visual guide; the values sent are exact.
class GlobalEqGraph extends StatefulWidget {
  const GlobalEqGraph({
    super.key,
    required this.settings,
    required this.enabled,
    required this.onChanged,
    this.height = 240,
  });

  final Fx200GlobalSettings settings;
  final bool enabled;
  final ValueChanged<Fx200GlobalSettings> onChanged;
  final double height;

  @override
  State<GlobalEqGraph> createState() => _GlobalEqGraphState();
}

class _GlobalEqGraphState extends State<GlobalEqGraph> {
  GlobalEqNode? _dragging;
  GlobalEqNode? _hovered;
  GlobalEqNode? _lastDownNode;
  DateTime? _lastDownAt;

  static const Duration _doubleClickWindow = Duration(milliseconds: 350);

  static const double _hitRadius = 22;

  _EqGeometry _geometry(Size size) => _EqGeometry(size);

  Map<GlobalEqNode, Offset> _nodePositions(_EqGeometry g) {
    final s = widget.settings;
    double gainDb(int raw) => Fx200GlobalSettings.gainToDb(raw);
    return <GlobalEqNode, Offset>{
      GlobalEqNode.low: Offset(
        g.xForFreq(s.eqLowFreqHz.toDouble()),
        g.yForDb(gainDb(s.eqLowGain)),
      ),
      GlobalEqNode.mid: Offset(
        g.xForFreq(s.eqMidFreqHz.toDouble()),
        g.yForDb(gainDb(s.eqMidGain)),
      ),
      GlobalEqNode.high: Offset(
        g.xForFreq(s.eqHighFreqHz.toDouble()),
        g.yForDb(gainDb(s.eqHighGain)),
      ),
      GlobalEqNode.lowCut: Offset(
        g.xForFreq(s.eqLowCutHz.toDouble()),
        g.bottom - 10,
      ),
      GlobalEqNode.highCut: Offset(
        g.xForFreq(s.eqHighCutHz.toDouble()),
        g.bottom - 10,
      ),
    };
  }

  GlobalEqNode? _hit(Offset p, Size size) {
    final positions = _nodePositions(_geometry(size));
    GlobalEqNode? best;
    var bestDist = _hitRadius;
    positions.forEach((node, pos) {
      final d = (pos - p).distance;
      if (d < bestDist) {
        bestDist = d;
        best = node;
      }
    });
    return best;
  }

  void _moveTo(GlobalEqNode node, Offset p, Size size) {
    final g = _geometry(size);
    final s = widget.settings;
    final hz = g.freqForX(p.dx).round();
    final gain = Fx200GlobalSettings.dbToGain(g.dbForY(p.dy));
    final next = switch (node) {
      GlobalEqNode.low => s.withEqLowFreqHz(hz).withEqLowGain(gain),
      GlobalEqNode.mid => s.withEqMidFreqHz(hz).withEqMidGain(gain),
      GlobalEqNode.high => s.withEqHighFreqHz(hz).withEqHighGain(gain),
      GlobalEqNode.lowCut => s.withEqLowCutHz(hz),
      GlobalEqNode.highCut => s.withEqHighCutHz(hz),
    };
    if (next != s) widget.onChanged(next);
  }

  void _resetGain(GlobalEqNode node) {
    final s = widget.settings;
    const zero = Fx200GlobalSettings.eqGainCenter;
    final next = switch (node) {
      GlobalEqNode.low => s.withEqLowGain(zero),
      GlobalEqNode.mid => s.withEqMidGain(zero),
      GlobalEqNode.high => s.withEqHighGain(zero),
      GlobalEqNode.lowCut => s.withEqLowCutHz(40),
      GlobalEqNode.highCut => s.withEqHighCutHz(20000),
    };
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final accent = ext.colorFor(EffectCategory.eq);
    final enabled = widget.enabled;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: ext.chassisBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.subtleBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final active = _dragging ?? _hovered;
          return MouseRegion(
            cursor: !enabled
                ? SystemMouseCursors.basic
                : _dragging != null
                ? SystemMouseCursors.grabbing
                : _hovered != null
                ? SystemMouseCursors.grab
                : SystemMouseCursors.basic,
            onHover: enabled
                ? (e) {
                    final hit = _hit(e.localPosition, size);
                    if (hit != _hovered) setState(() => _hovered = hit);
                  }
                : null,
            onExit: (_) {
              if (_hovered != null) setState(() => _hovered = null);
            },
            // Raw pointer events instead of GestureDetector: a double-tap
            // recognizer would hold the gesture arena and delay the drag
            // until the pointer is released.
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: enabled
                  ? (e) {
                      final hit = _hit(e.localPosition, size);
                      final now = DateTime.now();
                      final isDoubleClick =
                          hit != null &&
                          hit == _lastDownNode &&
                          _lastDownAt != null &&
                          now.difference(_lastDownAt!) < _doubleClickWindow;
                      _lastDownNode = hit;
                      _lastDownAt = now;
                      if (isDoubleClick) {
                        _lastDownAt = null;
                        _resetGain(hit);
                        return;
                      }
                      setState(() => _dragging = hit);
                    }
                  : null,
              onPointerMove: enabled
                  ? (e) {
                      final node = _dragging;
                      if (node != null) _moveTo(node, e.localPosition, size);
                    }
                  : null,
              onPointerUp: (_) {
                if (_dragging != null) setState(() => _dragging = null);
              },
              onPointerCancel: (_) {
                if (_dragging != null) setState(() => _dragging = null);
              },
              child: CustomPaint(
                size: size,
                painter: _GlobalEqPainter(
                  settings: widget.settings,
                  enabled: enabled,
                  active: active,
                  accent: accent,
                  ext: ext,
                  nodePositions: _nodePositions(_geometry(size)),
                  labelStyle:
                      Theme.of(context).textTheme.labelSmall ??
                      const TextStyle(fontSize: 10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Log-frequency / linear-dB plot mapping shared by gestures and painter.
class _EqGeometry {
  _EqGeometry(this.size);

  static const double minHz = 20;
  static const double maxHz = 20000;
  static const double maxDb = 15;
  static const double padLeft = 34;
  static const double padRight = 12;
  static const double padTop = 12;
  static const double padBottom = 22;

  final Size size;

  double get left => padLeft;
  double get right => size.width - padRight;
  double get top => padTop;
  double get bottom => size.height - padBottom;
  double get width => math.max(1, right - left);
  double get height => math.max(1, bottom - top);

  static final double _logMin = math.log(minHz);
  static final double _logMax = math.log(maxHz);

  double xForFreq(double hz) {
    final t =
        (math.log(hz.clamp(minHz, maxHz)) - _logMin) / (_logMax - _logMin);
    return left + t * width;
  }

  double freqForX(double x) {
    final t = ((x - left) / width).clamp(0.0, 1.0);
    return math.exp(_logMin + t * (_logMax - _logMin));
  }

  double yForDb(double db) {
    final t = (maxDb - db.clamp(-maxDb, maxDb)) / (2 * maxDb);
    return top + t * height;
  }

  double dbForY(double y) {
    final t = ((y - top) / height).clamp(0.0, 1.0);
    return maxDb - t * 2 * maxDb;
  }
}

class _GlobalEqPainter extends CustomPainter {
  _GlobalEqPainter({
    required this.settings,
    required this.enabled,
    required this.active,
    required this.accent,
    required this.ext,
    required this.nodePositions,
    required this.labelStyle,
  });

  final Fx200GlobalSettings settings;
  final bool enabled;
  final GlobalEqNode? active;
  final Color accent;
  final FxEditorThemeExtension ext;
  final Map<GlobalEqNode, Offset> nodePositions;
  final TextStyle labelStyle;

  static const List<double> _gridHz = <double>[
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
  ];
  static const List<double> _gridDb = <double>[-12, -6, 0, 6, 12];

  List<BiquadResponse> get _bands {
    double db(int raw) => Fx200GlobalSettings.gainToDb(raw);
    return <BiquadResponse>[
      BiquadResponse.peaking(
        settings.eqLowFreqHz.toDouble(),
        db(settings.eqLowGain),
      ),
      BiquadResponse.peaking(
        settings.eqMidFreqHz.toDouble(),
        db(settings.eqMidGain),
      ),
      BiquadResponse.peaking(
        settings.eqHighFreqHz.toDouble(),
        db(settings.eqHighGain),
      ),
    ];
  }

  List<BiquadResponse> get _cuts => <BiquadResponse>[
    BiquadResponse.highPass(settings.eqLowCutHz.toDouble()),
    BiquadResponse.lowPass(settings.eqHighCutHz.toDouble()),
  ];

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    Color color, {
    bool alignRight = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: labelStyle.copyWith(color: color, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    if (center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _EqGeometry(size);
    final dim = enabled ? 1.0 : 0.35;
    final curveColor = accent.withValues(alpha: dim);

    // Grid.
    final grid = Paint()
      ..color = ext.subtleBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final db in _gridDb) {
      final y = g.yForDb(db);
      canvas.drawLine(
        Offset(g.left, y),
        Offset(g.right, y),
        db == 0
            ? (Paint()
                ..color = ext.textMuted.withValues(alpha: 0.5)
                ..strokeWidth = 1)
            : grid,
      );
      _text(
        canvas,
        '${db > 0 ? '+' : ''}${db.round()}',
        Offset(g.left - 6, y),
        ext.textMuted,
        alignRight: true,
      );
    }
    for (final hz in _gridHz) {
      final x = g.xForFreq(hz);
      canvas.drawLine(Offset(x, g.top), Offset(x, g.bottom), grid);
      _text(
        canvas,
        hz >= 1000 ? '${(hz / 1000).round()}k' : '${hz.round()}',
        Offset(x, g.bottom + 11),
        ext.textMuted,
        center: true,
      );
    }

    // Response.
    final bands = _bands;
    final cuts = _cuts;
    const steps = 240;
    final path = Path();
    final bandPaths = List<Path>.generate(3, (_) => Path());
    for (var i = 0; i <= steps; i++) {
      final x = g.left + g.width * i / steps;
      final hz = g.freqForX(x);
      var total = 0.0;
      for (var b = 0; b < bands.length; b++) {
        final d = bands[b].dbAt(hz);
        total += d;
        final y = g.yForDb(d);
        i == 0 ? bandPaths[b].moveTo(x, y) : bandPaths[b].lineTo(x, y);
      }
      for (final c in cuts) {
        total += c.dbAt(hz);
      }
      final y = g.yForDb(total);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(g.left, g.top, g.right, g.bottom));
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = curveColor.withValues(alpha: 0.28 * dim);
    for (final p in bandPaths) {
      canvas.drawPath(p, bandPaint);
    }
    final zeroY = g.yForDb(0);
    final fill = Path.from(path)
      ..lineTo(g.right, zeroY)
      ..lineTo(g.left, zeroY)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = curveColor.withValues(alpha: 0.14 * dim),
    );
    if (enabled) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = curveColor.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = curveColor,
    );
    canvas.restore();

    // Nodes.
    const labels = <GlobalEqNode, String>{
      GlobalEqNode.low: 'L',
      GlobalEqNode.mid: 'M',
      GlobalEqNode.high: 'H',
      GlobalEqNode.lowCut: 'LC',
      GlobalEqNode.highCut: 'HC',
    };
    nodePositions.forEach((node, pos) {
      final isActive = node == active && enabled;
      final isCut = node == GlobalEqNode.lowCut || node == GlobalEqNode.highCut;
      final r = isActive ? 11.0 : 9.0;
      if (isCut) {
        final x = pos.dx;
        canvas.drawLine(
          Offset(x, g.top),
          Offset(x, g.bottom),
          Paint()
            ..color = curveColor.withValues(alpha: isActive ? 0.55 : 0.25)
            ..strokeWidth = 1,
        );
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: pos, width: 26, height: 16),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = ext.elevatedSurface);
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isActive ? 2 : 1.2
            ..color = curveColor,
        );
      } else {
        if (isActive) {
          canvas.drawCircle(
            pos,
            r + 6,
            Paint()..color = curveColor.withValues(alpha: 0.18),
          );
        }
        canvas.drawCircle(pos, r, Paint()..color = ext.elevatedSurface);
        canvas.drawCircle(
          pos,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isActive ? 2.4 : 1.6
            ..color = curveColor,
        );
      }
      _text(
        canvas,
        labels[node]!,
        pos,
        ext.textPrimary.withValues(alpha: dim),
        center: true,
      );
    });
  }

  @override
  bool shouldRepaint(covariant _GlobalEqPainter old) =>
      old.settings != settings ||
      old.enabled != enabled ||
      old.active != active ||
      old.accent != accent;
}
