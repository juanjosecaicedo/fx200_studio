import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:material_ui/material_ui.dart';

import '../../core/fx200_models.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'biquad_response.dart';
import 'rotary_knob.dart';
import '../../core/l10n/l10n.dart';

/// One EQ band: a gain parameter plus either a fixed centre frequency
/// (6-band models) or a frequency parameter (4 BAND CUSTOM).
class EqBandSpec {
  const EqBandSpec({required this.gain, this.freq, this.fixedHz});

  final BlockParameter gain;
  final BlockParameter? freq;
  final double? fixedHz;

  double get hz => freq?.displayValue ?? fixedHz ?? 1000;
  bool get movable => freq != null;
}

/// Splits an EQ block into bands and the remaining knobs (LEVEL) according
/// to its model's layout (see [Fx200Models.eqParameters]).
({List<EqBandSpec> bands, List<BlockParameter> knobs}) eqLayoutFor(
  EffectBlock block,
) {
  final params = Fx200Models.withModelLayout(block).parameters;
  if (Fx200Models.isEqCustom(block.modelName)) {
    return (
      bands: <EqBandSpec>[
        for (var b = 0; b < 4; b++)
          EqBandSpec(gain: params[b * 2 + 1], freq: params[b * 2]),
      ],
      knobs: <BlockParameter>[params[8]],
    );
  }
  final hz =
      Fx200Models.eqBandHz[block.modelName] ??
      Fx200Models.eqBandHz.values.first;
  return (
    bands: <EqBandSpec>[
      for (var b = 0; b < 6; b++) EqBandSpec(gain: params[b], fixedHz: hz[b]),
    ],
    knobs: <BlockParameter>[params[6]],
  );
}

/// Interactive frequency-response EQ editor for the FX200 EQ block.
/// Gains are `0..48` (24 = 0 dB, ±12 dB). Nodes drag vertically for GAIN;
/// on 4 BAND CUSTOM they also drag horizontally for FREQ. Double-click a
/// node to reset it.
class ParametricEqGraph extends StatefulWidget {
  const ParametricEqGraph({
    super.key,
    required this.blockId,
    required this.bands,
    required this.extraKnobs,
    required this.accent,
    required this.onParameterChanged,
  });

  final String blockId;
  final List<EqBandSpec> bands;
  final List<BlockParameter> extraKnobs;
  final Color accent;
  final void Function(String parameterId, double value, {bool recordHistory})
  onParameterChanged;

  @override
  State<ParametricEqGraph> createState() => _ParametricEqGraphState();
}

class _ParametricEqGraphState extends State<ParametricEqGraph> {
  static const double _minFreq = 20.0;
  static const double _maxFreq = 20000.0;
  static const double _padLeft = 34.0;
  static const double _padRight = 18.0;
  static const double _padTop = 14.0;
  static const double _padBottom = 24.0;
  static const double _handleSize = 24.0;

  static const List<String> _romanLabels = <String>[
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
  ];

  int? _activeBandIndex;
  Offset? _dragStart;
  double _startHz = 0;
  double _startDb = 0;
  double? _dragGain;
  double? _dragHz;
  DateTime? _lastDown;
  int? _lastDownBand;

  static double _dbFor(BlockParameter p) => p.displayValue;

  static double _valueForDb(BlockParameter p, double db) =>
      p.rawFor(db.clamp(-12.0, 12.0));

  static double _tForFreq(double f) =>
      ((math.log(f.clamp(_minFreq, _maxFreq)) - math.log(_minFreq)) /
              (math.log(_maxFreq) - math.log(_minFreq)))
          .clamp(0.0, 1.0);

  static double _freqForT(double t) => math.exp(
    math.log(_minFreq) +
        t.clamp(0.0, 1.0) * (math.log(_maxFreq) - math.log(_minFreq)),
  );

  static double _yForDb(double db, double plotH) =>
      _padTop + ((12.0 - db.clamp(-12.0, 12.0)) / 24.0) * plotH;

  String _roman(int i) =>
      i < _romanLabels.length ? _romanLabels[i] : '${i + 1}';

  void _onDown(int index, PointerDownEvent e) {
    if (e.buttons != kPrimaryButton) return;
    final band = widget.bands[index];
    final now = DateTime.now();
    final isDouble =
        _lastDownBand == index &&
        _lastDown != null &&
        now.difference(_lastDown!) < const Duration(milliseconds: 350);
    _lastDown = now;
    _lastDownBand = index;
    if (isDouble) {
      widget.onParameterChanged(band.gain.id, band.gain.defaultValue);
      final f = band.freq;
      if (f != null) widget.onParameterChanged(f.id, f.defaultValue);
      _dragStart = null;
      setState(() => _activeBandIndex = null);
      return;
    }
    _dragStart = e.position;
    _startHz = band.hz;
    _startDb = _dbFor(band.gain);
    _dragGain = band.gain.value;
    _dragHz = band.freq?.value;
    setState(() => _activeBandIndex = index);
  }

  void _onMove(int index, PointerMoveEvent e, double plotW, double plotH) {
    final start = _dragStart;
    if (start == null) return;
    final band = widget.bands[index];
    final delta = e.position - start;
    final db = _startDb - delta.dy / plotH * 24.0;
    _dragGain = _valueForDb(band.gain, db);
    widget.onParameterChanged(band.gain.id, _dragGain!, recordHistory: false);
    final f = band.freq;
    if (f != null) {
      final hz = _freqForT(_tForFreq(_startHz) + delta.dx / plotW);
      _dragHz = f.rawFor(hz);
      widget.onParameterChanged(f.id, _dragHz!, recordHistory: false);
    }
  }

  void _onUp(int index) {
    if (_dragStart == null) return;
    _dragStart = null;
    final band = widget.bands[index];
    widget.onParameterChanged(band.gain.id, _dragGain ?? band.gain.value);
    final f = band.freq;
    if (f != null) widget.onParameterChanged(f.id, _dragHz ?? f.value);
    setState(() => _activeBandIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final curveColor = ext.colorFor(EffectCategory.drive);
    final nodeColor = ext.colorFor(EffectCategory.delay);

    return Wrap(
      spacing: 20,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 620),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ext.chassisBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ext.subtleBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const ValueKey<String>('eq_plot'),
                  height: 210,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final plotW = (w - _padLeft - _padRight).clamp(1.0, w);
                      final plotH = (h - _padTop - _padBottom).clamp(1.0, h);
                      final freqs = [for (final b in widget.bands) b.hz];
                      final gainsDb = [
                        for (final b in widget.bands) _dbFor(b.gain),
                      ];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _EqCurvePainter(
                                freqs: freqs,
                                gainsDb: gainsDb,
                                padLeft: _padLeft,
                                padRight: _padRight,
                                padTop: _padTop,
                                padBottom: _padBottom,
                                curveColor: curveColor,
                                gridColor: ext.subtleBorder,
                                labelColor: ext.textMuted,
                              ),
                            ),
                          ),
                          for (var i = 0; i < widget.bands.length; i++)
                            Positioned(
                              left:
                                  _padLeft +
                                  _tForFreq(freqs[i]) * plotW -
                                  _handleSize / 2,
                              top: _yForDb(gainsDb[i], plotH) - _handleSize / 2,
                              child: Listener(
                                key: ValueKey<String>('eq_node_$i'),
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (e) => _onDown(i, e),
                                onPointerMove: (e) =>
                                    _onMove(i, e, plotW, plotH),
                                onPointerUp: (_) => _onUp(i),
                                onPointerCancel: (_) => _onUp(i),
                                child: MouseRegion(
                                  cursor: widget.bands[i].movable
                                      ? SystemMouseCursors.move
                                      : SystemMouseCursors.resizeUpDown,
                                  child: _node(context, i, nodeColor, ext),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ext.blockSurface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(9),
                    ),
                    border: Border(top: BorderSide(color: ext.subtleBorder)),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < widget.bands.length; i++)
                        _BandReadoutChip(
                          roman: _roman(i),
                          freqLabel: Fx200Models.formatHz(widget.bands[i].hz),
                          db: _dbFor(widget.bands[i].gain),
                          isActive: _activeBandIndex == i,
                          nodeColor: nodeColor,
                          ext: ext,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final param in widget.extraKnobs)
          RotaryKnob(
            key: ValueKey<String>('${widget.blockId}_${param.id}'),
            label: param.label,
            value: param.value,
            defaultValue: param.defaultValue,
            min: param.min,
            max: param.max,
            unit: param.unit,
            accentColor: widget.accent,
            onChanged: (v) =>
                widget.onParameterChanged(param.id, v, recordHistory: false),
            onChangeEnd: (v) =>
                widget.onParameterChanged(param.id, v, recordHistory: true),
          ),
      ],
    );
  }

  Widget _node(
    BuildContext context,
    int index,
    Color nodeColor,
    FxEditorThemeExtension ext,
  ) {
    final isActive = _activeBandIndex == index;
    return Container(
      width: _handleSize,
      height: _handleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: nodeColor,
        border: Border.all(color: ext.textPrimary, width: isActive ? 2.0 : 1.2),
        boxShadow: ext.glowFor(nodeColor, active: isActive),
      ),
      alignment: Alignment.center,
      child: Text(
        _roman(index),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ext.textPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BandReadoutChip extends StatelessWidget {
  const _BandReadoutChip({
    required this.roman,
    required this.freqLabel,
    required this.db,
    required this.isActive,
    required this.nodeColor,
    required this.ext,
  });

  final String roman;
  final String freqLabel;
  final double db;
  final bool isActive;
  final Color nodeColor;
  final FxEditorThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final sign = db > 0.05 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? nodeColor.withValues(alpha: 0.2) : ext.panelSurface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: isActive ? nodeColor : ext.subtleBorder),
      ),
      child: Text(
        tr('{0} {1}: {2}{3} dB', [
          roman,
          freqLabel,
          sign,
          db.toStringAsFixed(1),
        ]),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isActive ? ext.textPrimary : ext.textMuted,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  const _EqCurvePainter({
    required this.freqs,
    required this.gainsDb,
    required this.padLeft,
    required this.padRight,
    required this.padTop,
    required this.padBottom,
    required this.curveColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> freqs;
  final List<double> gainsDb;
  final double padLeft;
  final double padRight;
  final double padTop;
  final double padBottom;
  final Color curveColor;
  final Color gridColor;
  final Color labelColor;

  static const List<double> _gridFreqs = <double>[
    20,
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
  ];

  static const List<double> _gridDbs = <double>[12, 6, 0, -6, -12];

  double _xForFreq(double freq, double plotW) {
    final logMin = math.log(20.0);
    final logMax = math.log(20000.0);
    final t = (math.log(freq) - logMin) / (logMax - logMin);
    return padLeft + t * plotW;
  }

  double _yForDb(double db, double plotH) {
    final t = ((12.0 - db.clamp(-12.0, 12.0)) / 24.0).clamp(0.0, 1.0);
    return padTop + t * plotH;
  }

  /// Sum of peaking filters at each band (visual approximation).
  double _responseAtFreq(double f, List<BiquadResponse> filters) {
    var sum = 0.0;
    for (final b in filters) {
      sum += b.dbAt(f);
    }
    return sum.clamp(-12.0, 12.0);
  }

  String _formatFreq(double f) {
    if (f >= 1000) return '${(f / 1000).round()}k';
    return '${f.round()}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = (size.width - padLeft - padRight).clamp(1.0, size.width);
    final plotH = (size.height - padTop - padBottom).clamp(1.0, size.height);

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    final zeroPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.2;

    for (final db in _gridDbs) {
      final y = _yForDb(db, plotH);
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + plotW, y),
        db == 0 ? zeroPaint : gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${db.round()}',
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padLeft - tp.width - 6, y - tp.height / 2));
    }

    for (final f in _gridFreqs) {
      final x = _xForFreq(f, plotW);
      canvas.drawLine(Offset(x, padTop), Offset(x, padTop + plotH), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: _formatFreq(f),
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padTop + plotH + 5));
    }

    final filters = <BiquadResponse>[
      for (var i = 0; i < freqs.length; i++)
        if (gainsDb[i].abs() > 0.01)
          BiquadResponse.peaking(freqs[i], gainsDb[i], q: 1.1),
    ];
    final curvePath = Path();
    final fillPath = Path();
    final zeroY = _yForDb(0.0, plotH);
    const steps = 160;
    final logMin = math.log(20.0);
    final logMax = math.log(20000.0);
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final f = math.exp(logMin + t * (logMax - logMin));
      final x = padLeft + t * plotW;
      final y = _yForDb(_responseAtFreq(f, filters), plotH);
      if (s == 0) {
        curvePath.moveTo(x, y);
        fillPath.moveTo(x, zeroY);
        fillPath.lineTo(x, y);
      } else {
        curvePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(padLeft + plotW, zeroY);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            curveColor.withValues(alpha: 0.24),
            curveColor.withValues(alpha: 0.03),
          ],
        ).createShader(Rect.fromLTWH(padLeft, padTop, plotW, plotH)),
    );
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = curveColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter old) {
    if (old.gainsDb.length != gainsDb.length) return true;
    for (var i = 0; i < gainsDb.length; i++) {
      if (old.gainsDb[i] != gainsDb[i] || old.freqs[i] != freqs[i]) {
        return true;
      }
    }
    return old.curveColor != curveColor || old.gridColor != gridColor;
  }
}
