import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';

/// Bottom global control bar: Output volume, BPM / Tap Tempo, and IN/OUT meters.
class EditorBottomBar extends StatefulWidget {
  const EditorBottomBar({
    super.key,
    required this.bpm,
    required this.outputLevelDb,
    required this.onBpmChanged,
    required this.onOutputLevelChanged,
  });

  final double bpm;
  final double outputLevelDb;
  final ValueChanged<double> onBpmChanged;
  final ValueChanged<double> onOutputLevelChanged;

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  Timer? _meterTimer;
  double _inLevel = 0.42;
  double _outLevel = 0.56;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _meterTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      final t = DateTime.now().millisecondsSinceEpoch / 240.0;
      final outScale = ((widget.outputLevelDb + 60.0) / 72.0).clamp(0.1, 1.0);
      setState(() {
        _inLevel = (0.45 + 0.25 * math.sin(t)).clamp(0.05, 0.95);
        _outLevel =
            ((0.52 + 0.28 * math.cos(t * 1.15)) * outScale).clamp(0.05, 0.98);
      });
    });
  }

  @override
  void dispose() {
    _meterTimer?.cancel();
    super.dispose();
  }

  void _handleTapTempo() {
    final now = DateTime.now();
    final prev = _lastTap;
    _lastTap = now;
    if (prev == null) return;
    final ms = now.difference(prev).inMilliseconds;
    if (ms >= 250 && ms <= 1500) {
      widget.onBpmChanged((60000.0 / ms).roundToDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final delayColor = ext.colorFor(EffectCategory.delay);
    final volColor = ext.colorFor(EffectCategory.volume);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ext.panelSurface,
        border: Border(top: BorderSide(color: ext.subtleBorder)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Output level
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('OUTPUT', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: volColor,
                    inactiveTrackColor: ext.subtleBorder,
                    thumbColor: volColor,
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: widget.outputLevelDb.clamp(-60.0, 12.0),
                    min: -60.0,
                    max: 12.0,
                    onChanged: widget.onOutputLevelChanged,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.outputLevelDb.toStringAsFixed(1)} dB',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ext.textPrimary,
                ),
              ),
            ],
          ),

          // BPM & Tap Tempo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TEMPO', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.remove, size: 15),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => widget.onBpmChanged(widget.bpm - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${widget.bpm.round()} BPM',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: delayColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 15),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => widget.onBpmChanged(widget.bpm + 1),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _handleTapTempo,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'TAP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ext.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          // IN / OUT Level Meters
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('IN', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 6),
              _LevelMeterBar(level: _inLevel, ext: ext),
              const SizedBox(width: 12),
              Text('OUT', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 6),
              _LevelMeterBar(level: _outLevel, ext: ext),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelMeterBar extends StatelessWidget {
  const _LevelMeterBar({required this.level, required this.ext});

  final double level;
  final FxEditorThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 10,
      child: CustomPaint(
        painter: _LevelMeterPainter(level: level, ext: ext),
      ),
    );
  }
}

class _LevelMeterPainter extends CustomPainter {
  const _LevelMeterPainter({required this.level, required this.ext});

  final double level;
  final FxEditorThemeExtension ext;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = ext.blockSurface;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3)),
      bgPaint,
    );

    const segments = 12;
    final segWidth = (size.width - (segments - 1) * 2) / segments;
    final activeCount = (level * segments).round().clamp(0, segments);

    for (var i = 0; i < activeCount; i++) {
      final color = i >= 10
          ? ext.meterPeak
          : (i >= 7 ? ext.meterMid : ext.meterLow);
      final rect = Rect.fromLTWH(
        i * (segWidth + 2),
        1.5,
        segWidth,
        size.height - 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelMeterPainter oldDelegate) =>
      oldDelegate.level != level;
}
