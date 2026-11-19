import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../core/l10n/l10n.dart';

/// Bottom global control bar: BPM / Tap Tempo and IN/OUT meters.
///
/// There is no OUTPUT control: the `0xAE` frame it used to write is the
/// expression pedal's VOLUME range, not a global output level.
class EditorBottomBar extends StatefulWidget {
  const EditorBottomBar({
    super.key,
    required this.bpm,
    required this.outputLevelDb,
    required this.onBpmChanged,
  });

  final double bpm;
  final double outputLevelDb;
  final ValueChanged<double> onBpmChanged;

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  DateTime? _lastTap;

  double get _outLevel =>
      (((widget.outputLevelDb + 60.0) / 66.0) * 0.72).clamp(0.0, 0.85);

  void _handleTapTempo() {
    final now = DateTime.now();
    final prev = _lastTap;
    _lastTap = now;
    if (prev == null) return;
    final ms = now.difference(prev).inMilliseconds;
    if (ms >= 230 && ms <= 1500) {
      widget.onBpmChanged((60000.0 / ms).roundToDouble().clamp(40.0, 260.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final delayColor = ext.colorFor(EffectCategory.delay);

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
          // BPM & Tap Tempo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('TEMPO'), style: Theme.of(context).textTheme.labelSmall),
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
                  tr('{0} BPM', [widget.bpm.round()]),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  tr('TAP'),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: ext.textPrimary),
                ),
              ),
            ],
          ),

          // IN / OUT Level Meters
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('IN'), style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 6),
              _LevelMeterBar(level: 0.0, ext: ext),
              const SizedBox(width: 12),
              Text(tr('OUT'), style: Theme.of(context).textTheme.labelSmall),
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
