import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'rotary_knob.dart';

/// Interactive TDR-Nova-style frequency-response curve EQ editor.
/// Maps the 6 FX200 EQ gain bands (`0..48` => `-12..+12 dB`) onto a
/// logarithmic `20 Hz .. 20 kHz` grid with draggable band nodes.
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
  final List<BlockParameter> bands;
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

  static const List<double> _defaultBandFreqs = <double>[
    100.0,
    200.0,
    400.0,
    800.0,
    1600.0,
    3200.0,
  ];

  static const List<String> _romanLabels = <String>[
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
  ];

  int? _activeBandIndex;

  double _freqForBand(int index) {
    if (index < _defaultBandFreqs.length) return _defaultBandFreqs[index];
    return 100.0 * math.pow(2, index);
  }

  double _dbForParam(BlockParameter p) {
    final mid = (p.min + p.max) / 2.0;
    final half = (p.max - p.min) / 2.0;
    if (half <= 0) return 0.0;
    return ((p.value - mid) / half) * 12.0;
  }

  double _valueForDb(BlockParameter p, double db) {
    final clampedDb = db.clamp(-12.0, 12.0);
    final mid = (p.min + p.max) / 2.0;
    final half = (p.max - p.min) / 2.0;
    return (mid + (clampedDb / 12.0) * half).clamp(p.min, p.max);
  }

  double _xForFreq(double freq, double plotWidth) {
    final logMin = math.log(_minFreq);
    final logMax = math.log(_maxFreq);
    final t = ((math.log(freq.clamp(_minFreq, _maxFreq)) - logMin) /
            (logMax - logMin))
        .clamp(0.0, 1.0);
    return _padLeft + t * plotWidth;
  }

  double _yForDb(double db, double plotHeight) {
    final t = ((12.0 - db.clamp(-12.0, 12.0)) / 24.0).clamp(0.0, 1.0);
    return _padTop + t * plotHeight;
  }

  double _dbForY(double y, double plotHeight) {
    final t = ((y - _padTop) / plotHeight).clamp(0.0, 1.0);
    return 12.0 - t * 24.0;
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
                height: 210,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final plotW = (w - _padLeft - _padRight).clamp(1.0, w);
                    final plotH = (h - _padTop - _padBottom).clamp(1.0, h);

                    final freqs = List<double>.generate(
                      widget.bands.length,
                      _freqForBand,
                    );
                    final gainsDb = widget.bands.map(_dbForParam).toList();

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
                          _buildBandHandle(
                            context: context,
                            index: i,
                            band: widget.bands[i],
                            x: _xForFreq(freqs[i], plotW),
                            y: _yForDb(gainsDb[i], plotH),
                            plotHeight: plotH,
                            nodeColor: nodeColor,
                            ext: ext,
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
                  border: Border(
                    top: BorderSide(color: ext.subtleBorder),
                  ),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < widget.bands.length; i++)
                      _BandReadoutChip(
                        roman: i < _romanLabels.length
                            ? _romanLabels[i]
                            : '${i + 1}',
                        freqLabel: widget.bands[i].label,
                        db: _dbForParam(widget.bands[i]),
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
            onChanged: (v) => widget.onParameterChanged(
              param.id,
              v,
              recordHistory: false,
            ),
            onChangeEnd: (v) => widget.onParameterChanged(
              param.id,
              v,
              recordHistory: true,
            ),
          ),
      ],
    );
  }

  Widget _buildBandHandle({
    required BuildContext context,
    required int index,
    required BlockParameter band,
    required double x,
    required double y,
    required double plotHeight,
    required Color nodeColor,
    required FxEditorThemeExtension ext,
  }) {
    final isActive = _activeBandIndex == index;
    const handleSize = 24.0;
    final roman = index < _romanLabels.length ? _romanLabels[index] : '${index + 1}';

    return Positioned(
      left: x - handleSize / 2,
      top: y - handleSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          widget.onParameterChanged(
            band.id,
            band.defaultValue,
            recordHistory: true,
          );
        },
        onVerticalDragStart: (_) => setState(() => _activeBandIndex = index),
        onVerticalDragUpdate: (details) {
          final currentY = _yForDb(_dbForParam(band), plotHeight);
          final nextDb = _dbForY(currentY + details.delta.dy, plotHeight);
          final nextVal = _valueForDb(band, nextDb).roundToDouble();
          widget.onParameterChanged(
            band.id,
            nextVal,
            recordHistory: false,
          );
        },
        onVerticalDragEnd: (_) {
          widget.onParameterChanged(
            band.id,
            band.value,
            recordHistory: true,
          );
          setState(() => _activeBandIndex = null);
        },
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: nodeColor,
            border: Border.all(
              color: ext.textPrimary,
              width: isActive ? 2.0 : 1.2,
            ),
            boxShadow: ext.glowFor(nodeColor, active: isActive),
          ),
          alignment: Alignment.center,
          child: Text(
            roman,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ext.textPrimary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
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
        border: Border.all(
          color: isActive ? nodeColor : ext.subtleBorder,
        ),
      ),
      child: Text(
        '$roman $freqLabel: $sign${db.toStringAsFixed(1)}',
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

  double _responseAtFreq(double f) {
    final logF = math.log(f) / math.ln2;
    var sum = 0.0;
    const sigmaOctaves = 0.55;
    for (var i = 0; i < freqs.length; i++) {
      final logCenter = math.log(freqs[i]) / math.ln2;
      final d = (logF - logCenter) / sigmaOctaves;
      sum += gainsDb[i] * math.exp(-0.5 * d * d);
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

    // Horizontal dB lines and labels
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

    // Vertical log-frequency lines and labels
    for (final f in _gridFreqs) {
      final x = _xForFreq(f, plotW);
      canvas.drawLine(
        Offset(x, padTop),
        Offset(x, padTop + plotH),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _formatFreq(f),
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padTop + plotH + 5));
    }

    // Build frequency response curve
    final curvePath = Path();
    final fillPath = Path();
    final zeroY = _yForDb(0.0, plotH);
    const steps = 140;
    final logMin = math.log(20.0);
    final logMax = math.log(20000.0);

    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final f = math.exp(logMin + t * (logMax - logMin));
      final x = padLeft + t * plotW;
      final y = _yForDb(_responseAtFreq(f), plotH);
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

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          curveColor.withValues(alpha: 0.24),
          curveColor.withValues(alpha: 0.03),
        ],
      ).createShader(Rect.fromLTWH(padLeft, padTop, plotW, plotH));
    canvas.drawPath(fillPath, fillPaint);

    final glowPaint = Paint()
      ..color = curveColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(curvePath, glowPaint);

    final linePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(curvePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) {
    if (oldDelegate.gainsDb.length != gainsDb.length) return true;
    for (var i = 0; i < gainsDb.length; i++) {
      if (oldDelegate.gainsDb[i] != gainsDb[i]) return true;
    }
    return oldDelegate.curveColor != curveColor ||
        oldDelegate.gridColor != gridColor;
  }
}
