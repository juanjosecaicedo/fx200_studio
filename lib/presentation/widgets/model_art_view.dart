import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/fx200_model_art.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';

/// Original vector illustration of an FX200 model (amp, cab, pedal or effect
/// glyph). See [Fx200ModelArt] for the per-model specs.
class ModelArtView extends StatelessWidget {
  const ModelArtView({
    super.key,
    required this.category,
    required this.modelName,
    this.width,
    this.height,
  });

  final EffectCategory category;
  final String modelName;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final art = Fx200ModelArt.artFor(category, modelName);
    return Semantics(
      label: '$modelName illustration',
      image: true,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: ModelArtPainter(
            art: art,
            accent: ext.colorFor(category),
            plate: ext.chassisBackground,
            edge: ext.subtleBorder,
          ),
        ),
      ),
    );
  }
}

class ModelArtPainter extends CustomPainter {
  ModelArtPainter({
    required this.art,
    required this.accent,
    required this.plate,
    required this.edge,
  });

  final ModelArt art;
  final Color accent;
  final Color plate;
  final Color edge;

  double get _aspect {
    switch (art.kind) {
      case ModelArtKind.combo:
        return art.wide ? 1.55 : 1.2;
      case ModelArtKind.head:
        return 2.4;
      case ModelArtKind.rack:
        return 3.4;
      case ModelArtKind.cab:
        if (art.speakerRows == 1) return art.speakerCols == 1 ? 1.0 : 1.7;
        return 1.08;
      case ModelArtKind.stomp:
      case ModelArtKind.compact:
        return 0.7;
      case ModelArtKind.wah:
        return 0.62;
      case ModelArtKind.round:
        return 1.0;
      case ModelArtKind.glyph:
        return 1.5;
    }
  }

  Rect _fit(Size size) {
    final avail = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    var w = avail.width;
    var h = w / _aspect;
    if (h > avail.height) {
      h = avail.height;
      w = h * _aspect;
    }
    return Rect.fromCenter(center: avail.center, width: w, height: h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = _fit(size);
    switch (art.kind) {
      case ModelArtKind.combo:
        _combo(canvas, r);
      case ModelArtKind.head:
        _head(canvas, r);
      case ModelArtKind.rack:
        _rack(canvas, r);
      case ModelArtKind.cab:
        _cab(canvas, r);
      case ModelArtKind.stomp:
        _stomp(canvas, r);
      case ModelArtKind.compact:
        _compact(canvas, r);
      case ModelArtKind.wah:
        _wah(canvas, r);
      case ModelArtKind.round:
        _round(canvas, r);
      case ModelArtKind.glyph:
        _glyphPlate(canvas, r);
    }
  }

  // ---------------------------------------------------------------- helpers

  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  void _box(Canvas c, RRect rr, Color fill, {double edgeAmount = -0.18}) {
    c.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(fill, 0.06), _shade(fill, -0.05)],
        ).createShader(rr.outerRect),
    );
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, rr.width * 0.012)
        ..color = _shade(fill, edgeAmount),
    );
  }

  void _knob(Canvas c, Offset center, double radius, Color color) {
    c.drawCircle(
      center.translate(0, radius * 0.25),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [_shade(color, 0.18), _shade(color, -0.12)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final light = HSLColor.fromColor(color).lightness > 0.55;
    c.drawLine(
      center,
      center.translate(-radius * 0.45, -radius * 0.75),
      Paint()
        ..strokeWidth = math.max(0.7, radius * 0.28)
        ..strokeCap = StrokeCap.round
        ..color = light ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2),
    );
  }

  void _knobRow(Canvas c, Rect area, int count, Color color, {double? radius}) {
    if (count <= 0) return;
    final rad =
        radius ?? math.min(area.height * 0.32, area.width / count * 0.32);
    final step = area.width / count;
    for (var i = 0; i < count; i++) {
      _knob(
        c,
        Offset(area.left + step * (i + 0.5), area.center.dy),
        rad,
        color,
      );
    }
  }

  void _led(Canvas c, Offset at, double radius, Color color) {
    c.drawCircle(
      at,
      radius * 2.2,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.4),
    );
    c.drawCircle(at, radius, Paint()..color = color);
    c.drawCircle(
      at.translate(-radius * 0.3, -radius * 0.3),
      radius * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _texture(Canvas c, Rect area, ModelArtTexture t, Color base) {
    if (t == ModelArtTexture.plain) return;
    c.save();
    c.clipRect(area);
    final p = Paint()
      ..strokeWidth = math.max(0.5, area.shortestSide * 0.025)
      ..color = _shade(base, -0.16).withValues(alpha: 0.75);
    final step = math.max(2.5, area.shortestSide * 0.09);
    switch (t) {
      case ModelArtTexture.tweed:
        for (var x = area.left - area.height; x < area.right; x += step) {
          c.drawLine(
            Offset(x, area.bottom),
            Offset(x + area.height, area.top),
            p,
          );
        }
      case ModelArtTexture.diamond:
        p.color = _shade(base, 0.12).withValues(alpha: 0.6);
        for (var x = area.left - area.height; x < area.right; x += step * 1.4) {
          c.drawLine(
            Offset(x, area.bottom),
            Offset(x + area.height, area.top),
            p,
          );
          c.drawLine(
            Offset(x, area.top),
            Offset(x + area.height, area.bottom),
            p,
          );
        }
      case ModelArtTexture.basketweave:
        p.color = _shade(base, -0.1).withValues(alpha: 0.55);
        for (var y = area.top; y < area.bottom; y += step) {
          c.drawLine(Offset(area.left, y), Offset(area.right, y), p);
        }
        for (var x = area.left; x < area.right; x += step) {
          c.drawLine(Offset(x, area.top), Offset(x, area.bottom), p);
        }
      case ModelArtTexture.diamondPlate:
        p
          ..color = _shade(base, 0.2).withValues(alpha: 0.8)
          ..strokeCap = StrokeCap.round;
        var row = 0;
        for (var y = area.top + step / 2; y < area.bottom; y += step) {
          for (
            var x = area.left + (row.isEven ? 0 : step / 2);
            x < area.right;
            x += step
          ) {
            final d = step * 0.22;
            if ((row + (x / step).floor()).isEven) {
              c.drawLine(Offset(x - d, y + d), Offset(x + d, y - d), p);
            } else {
              c.drawLine(Offset(x - d, y - d), Offset(x + d, y + d), p);
            }
          }
          row++;
        }
      case ModelArtTexture.plain:
        break;
    }
    c.restore();
  }

  void _pilotOrLed(Canvas c, Offset at, double radius) {
    _led(c, at, radius, art.led ?? const Color(0xFFDC2626));
  }

  // ------------------------------------------------------------------ amps

  void _combo(Canvas c, Rect r) {
    final rad = Radius.circular(r.width * 0.05);
    final body = RRect.fromRectAndRadius(r, rad);
    _box(c, body, art.body);
    _texture(
      c,
      r.deflate(r.width * 0.01),
      art.texture == ModelArtTexture.tweed
          ? ModelArtTexture.tweed
          : ModelArtTexture.plain,
      art.body,
    );

    final m = r.width * 0.06;
    final panel = Rect.fromLTWH(
      r.left + m,
      r.top + m,
      r.width - 2 * m,
      r.height * 0.22,
    );
    _box(
      c,
      RRect.fromRectAndRadius(panel, Radius.circular(r.width * 0.015)),
      art.panel,
    );
    final knobsArea = Rect.fromLTRB(
      panel.left + panel.width * 0.04,
      panel.top,
      panel.right - panel.width * 0.14,
      panel.bottom,
    );
    _knobRow(c, knobsArea, art.knobs, art.knob);
    _pilotOrLed(
      c,
      Offset(panel.right - panel.width * 0.07, panel.center.dy),
      panel.height * 0.16,
    );

    final grille = Rect.fromLTRB(
      r.left + m,
      panel.bottom + m * 0.7,
      r.right - m,
      r.bottom - m,
    );
    final grilleRR = RRect.fromRectAndRadius(
      grille,
      Radius.circular(r.width * 0.02),
    );
    c.drawRRect(grilleRR, Paint()..color = art.grille);
    final gTexture = art.texture == ModelArtTexture.tweed
        ? ModelArtTexture.basketweave
        : art.texture;
    _texture(c, grille, gTexture, art.grille);
    c.drawRRect(
      grilleRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r.width * 0.015)
        ..color = _shade(art.body, -0.2),
    );
  }

  void _head(Canvas c, Rect r) {
    final body = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.1));
    _box(c, body, art.body);
    if (art.piping != null) {
      c.drawRRect(
        body.deflate(r.height * 0.06),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.7, r.height * 0.03)
          ..color = art.piping!,
      );
    }
    final panel = Rect.fromLTRB(
      r.left + r.width * 0.06,
      r.top + r.height * 0.24,
      r.right - r.width * 0.06,
      r.bottom - r.height * 0.24,
    );
    final panelRR = RRect.fromRectAndRadius(
      panel,
      Radius.circular(r.height * 0.04),
    );
    _box(c, panelRR, art.panel, edgeAmount: -0.25);
    _texture(c, panel, art.texture, art.panel);
    final knobs = Rect.fromLTRB(
      panel.left + panel.width * 0.12,
      panel.top,
      panel.right - panel.width * 0.03,
      panel.bottom,
    );
    _knobRow(c, knobs, art.knobs, art.knob, radius: panel.height * 0.26);
    _pilotOrLed(
      c,
      Offset(panel.left + panel.width * 0.06, panel.center.dy),
      panel.height * 0.14,
    );
    // Handle.
    c.drawLine(
      Offset(r.center.dx - r.width * 0.12, r.top + r.height * 0.1),
      Offset(r.center.dx + r.width * 0.12, r.top + r.height * 0.1),
      Paint()
        ..strokeWidth = math.max(1, r.height * 0.06)
        ..strokeCap = StrokeCap.round
        ..color = _shade(art.body, -0.15),
    );
  }

  void _rack(Canvas c, Rect r) {
    final ear = r.width * 0.06;
    final body = Rect.fromLTRB(r.left + ear, r.top, r.right - ear, r.bottom);
    for (final x in [r.left, r.right - ear]) {
      final e = Rect.fromLTWH(x, r.top, ear, r.height);
      _box(
        c,
        RRect.fromRectAndRadius(e, Radius.circular(ear * 0.3)),
        _shade(art.body, 0.1),
      );
      for (final y in [0.25, 0.75]) {
        c.drawCircle(
          Offset(e.center.dx, r.top + r.height * y),
          ear * 0.18,
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
      }
    }
    _box(
      c,
      RRect.fromRectAndRadius(body, Radius.circular(r.height * 0.06)),
      art.body,
    );
    final knobs = Rect.fromLTRB(
      body.left + body.width * 0.14,
      body.top,
      body.right - body.width * 0.04,
      body.bottom,
    );
    _knobRow(c, knobs, art.knobs, art.knob, radius: body.height * 0.17);
    _pilotOrLed(
      c,
      Offset(body.left + body.width * 0.07, body.center.dy),
      body.height * 0.08,
    );
  }

  // ------------------------------------------------------------------- cab

  void _cab(Canvas c, Rect r) {
    final slantCut = art.slant ? r.height * 0.32 : 0.0;
    final outline = Path()
      ..moveTo(r.left + slantCut * 0.55, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + slantCut)
      ..close();
    c.drawPath(outline, Paint()..color = art.body);
    c.save();
    c.clipPath(outline);
    _texture(
      c,
      r,
      art.texture == ModelArtTexture.tweed
          ? ModelArtTexture.tweed
          : ModelArtTexture.plain,
      art.body,
    );
    c.restore();
    c.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r.width * 0.015)
        ..color = _shade(art.body, -0.2),
    );

    final m = r.shortestSide * 0.08;
    final grillePath = Path()
      ..moveTo(r.left + m + slantCut * 0.5, r.top + m)
      ..lineTo(r.right - m, r.top + m)
      ..lineTo(r.right - m, r.bottom - m)
      ..lineTo(r.left + m, r.bottom - m)
      ..lineTo(r.left + m, r.top + m + slantCut * 0.85)
      ..close();
    c.drawPath(grillePath, Paint()..color = art.grille);
    c.save();
    c.clipPath(grillePath);
    final grilleRect = grillePath.getBounds();
    final gTexture = art.texture == ModelArtTexture.tweed
        ? ModelArtTexture.basketweave
        : art.texture;
    _texture(c, grilleRect, gTexture, art.grille);

    // Speakers seen through the cloth.
    final cols = art.speakerCols, rows = art.speakerRows;
    final cw = grilleRect.width / cols, rh = grilleRect.height / rows;
    final sr = math.min(cw, rh) * (art.speakerSize == 10 ? 0.36 : 0.42);
    for (var i = 0; i < cols; i++) {
      for (var j = 0; j < rows; j++) {
        final center = Offset(
          grilleRect.left + cw * (i + 0.5),
          grilleRect.top + rh * (j + 0.5),
        );
        c.drawCircle(
          center,
          sr,
          Paint()..color = Colors.black.withValues(alpha: 0.22),
        );
        c.drawCircle(
          center,
          sr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.6, sr * 0.08)
            ..color = Colors.black.withValues(alpha: 0.3),
        );
        c.drawCircle(
          center,
          sr * 0.32,
          Paint()..color = Colors.black.withValues(alpha: 0.25),
        );
      }
    }
    c.restore();
  }

  // ---------------------------------------------------------------- pedals

  void _footswitch(Canvas c, Offset at, double radius) {
    c.drawCircle(
      at,
      radius * 1.25,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    c.drawCircle(
      at,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFF4F6F8), Color(0xFF8E959C)],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );
  }

  void _stomp(Canvas c, Rect r) {
    final body = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.12));
    _box(c, body, art.body);
    final knobArea = Rect.fromLTWH(
      r.left + r.width * 0.08,
      r.top + r.height * 0.07,
      r.width * 0.84,
      r.height * (art.knobs > 3 ? 0.42 : 0.24),
    );
    if (art.knobs > 3) {
      final top = Rect.fromLTWH(
        knobArea.left,
        knobArea.top,
        knobArea.width,
        knobArea.height / 2,
      );
      final bottom = top.shift(Offset(0, knobArea.height / 2));
      final rad = knobArea.height * 0.17;
      _knobRow(c, top, 2, art.knob, radius: rad);
      _knobRow(c, bottom, art.knobs - 2, art.knob, radius: rad);
    } else {
      _knobRow(c, knobArea, art.knobs, art.knob, radius: r.width * 0.11);
    }
    _led(
      c,
      Offset(r.center.dx, r.top + r.height * 0.58),
      r.width * 0.045,
      art.led ?? const Color(0xFFEF4444),
    );
    _footswitch(
      c,
      Offset(r.center.dx, r.bottom - r.height * 0.2),
      r.width * 0.14,
    );
  }

  void _compact(Canvas c, Rect r) {
    final body = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.1));
    _box(c, body, art.body);
    final knobArea = Rect.fromLTWH(
      r.left + r.width * 0.06,
      r.top + r.height * 0.05,
      r.width * 0.88,
      r.height * 0.2,
    );
    _knobRow(c, knobArea, art.knobs, art.knob, radius: r.width * 0.075);
    _led(
      c,
      Offset(r.left + r.width * 0.16, r.top + r.height * 0.31),
      r.width * 0.04,
      art.led ?? const Color(0xFFEF4444),
    );
    final treadle = Rect.fromLTRB(
      r.left + r.width * 0.05,
      r.top + r.height * 0.38,
      r.right - r.width * 0.05,
      r.bottom - r.height * 0.04,
    );
    _box(
      c,
      RRect.fromRectAndRadius(treadle, Radius.circular(r.width * 0.08)),
      _shade(art.body, -0.12),
    );
    final ribs = Paint()
      ..strokeWidth = math.max(0.5, r.width * 0.02)
      ..color = _shade(art.body, -0.25);
    for (var i = 1; i < 6; i++) {
      final y = treadle.top + treadle.height * (0.55 + i * 0.07);
      c.drawLine(
        Offset(treadle.left + treadle.width * 0.12, y),
        Offset(treadle.right - treadle.width * 0.12, y),
        ribs,
      );
    }
  }

  void _wah(Canvas c, Rect r) {
    final base = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.16));
    _box(c, base, _shade(art.body, -0.06));
    final treadle = Path()
      ..moveTo(r.left + r.width * 0.12, r.top + r.height * 0.05)
      ..lineTo(r.right - r.width * 0.12, r.top + r.height * 0.05)
      ..lineTo(r.right - r.width * 0.06, r.bottom - r.height * 0.1)
      ..lineTo(r.left + r.width * 0.06, r.bottom - r.height * 0.1)
      ..close();
    c.drawPath(treadle, Paint()..color = art.body);
    final rubber = Rect.fromLTRB(
      r.left + r.width * 0.2,
      r.top + r.height * 0.14,
      r.right - r.width * 0.2,
      r.bottom - r.height * 0.22,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(rubber, Radius.circular(r.width * 0.06)),
      Paint()..color = const Color(0xFF141414),
    );
    final rib = Paint()
      ..strokeWidth = math.max(0.5, r.width * 0.025)
      ..color = const Color(0xFF3A3A3A);
    for (
      var y = rubber.top + rubber.height * 0.08;
      y < rubber.bottom;
      y += rubber.height * 0.11
    ) {
      c.drawLine(Offset(rubber.left + 2, y), Offset(rubber.right - 2, y), rib);
    }
    _led(
      c,
      Offset(r.right - r.width * 0.2, r.bottom - r.height * 0.05),
      r.width * 0.045,
      art.led ?? const Color(0xFFEF4444),
    );
  }

  void _round(Canvas c, Rect r) {
    final center = r.center;
    final radius = r.width / 2;
    c.drawCircle(
      center.translate(0, radius * 0.05),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [_shade(art.body, 0.12), _shade(art.body, -0.1)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    _knob(
      c,
      center.translate(-radius * 0.36, -radius * 0.38),
      radius * 0.16,
      art.knob,
    );
    _knob(
      c,
      center.translate(radius * 0.36, -radius * 0.38),
      radius * 0.16,
      art.knob,
    );
    _footswitch(c, center.translate(0, radius * 0.38), radius * 0.2);
  }

  // ---------------------------------------------------------------- glyphs

  void _glyphPlate(Canvas c, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.18));
    c.drawRRect(rr, Paint()..color = plate);
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.45),
    );
    final g = r.deflate(r.height * 0.18);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r.height * 0.055)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent;
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.45);
    final fill = Paint()..color = accent;
    _drawGlyph(c, art.glyph ?? ModelGlyph.chorus, g, stroke, faint, fill);
  }

  Path _wave(
    Rect g,
    double cycles,
    double amp, {
    double phase = 0,
    double Function(double t)? env,
    double chirp = 0,
  }) {
    final p = Path();
    const steps = 80;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final f = cycles * (1 + chirp * t);
      final a = amp * (env?.call(t) ?? 1);
      final y =
          g.center.dy -
          math.sin(2 * math.pi * f * t + phase) * a * g.height / 2;
      final x = g.left + t * g.width;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p;
  }

  void _bars(
    Canvas c,
    Rect g,
    int n,
    Paint fill, {
    bool rising = false,
    double topFrac = 1,
    double bottomPad = 0,
  }) {
    final w = g.width / (n * 1.8);
    for (var i = 0; i < n; i++) {
      final k = rising ? (i + 1) / n : 1 - i / n;
      final h = g.height * topFrac * (0.25 + 0.75 * k);
      final x = g.left + i * (g.width / n) + w * 0.3;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, g.bottom - bottomPad - h, w, h),
          Radius.circular(w * 0.4),
        ),
        Paint()..color = fill.color.withValues(alpha: 0.35 + 0.65 * k),
      );
    }
  }

  void _arrow(Canvas c, Offset from, Offset to, Paint p, {double? head}) {
    c.drawLine(from, to, p);
    final ang = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final len = head ?? (to - from).distance * 0.3;
    for (final s in [-1, 1]) {
      final a = ang + math.pi + s * 0.5;
      c.drawLine(to, to + Offset(math.cos(a), math.sin(a)) * len, p);
    }
  }

  void _filterCurve(
    Canvas c,
    Rect g,
    Paint p, {
    required bool lowCut,
    required bool hiCut,
  }) {
    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      var v = 1.0;
      if (lowCut) v *= 1 / (1 + math.pow((0.3 / math.max(t, 0.01)), 4));
      if (hiCut) v *= 1 / (1 + math.pow((t / 0.7), 6));
      final x = g.left + t * g.width;
      final y = g.bottom - v * g.height * 0.85;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    c.drawPath(path, p);
  }

  void _drawGlyph(
    Canvas c,
    ModelGlyph glyph,
    Rect g,
    Paint s,
    Paint faint,
    Paint fill,
  ) {
    switch (glyph) {
      case ModelGlyph.chorus:
        c.drawPath(_wave(g, 1.5, 0.6, phase: 0.9), faint);
        c.drawPath(_wave(g, 1.5, 0.6), s);
      case ModelGlyph.triChorus:
        c.drawPath(_wave(g, 1.5, 0.6, phase: 1.8), faint);
        c.drawPath(_wave(g, 1.5, 0.6, phase: 0.9), faint);
        c.drawPath(_wave(g, 1.5, 0.6), s);
      case ModelGlyph.flanger:
        c.drawPath(_wave(g, 1.2, 0.7, chirp: 2.5), s);
      case ModelGlyph.jet:
        c.drawPath(_wave(g, 1.0, 0.45, chirp: 3), faint);
        _arrow(
          c,
          g.bottomLeft.translate(g.width * 0.1, -g.height * 0.05),
          g.topRight.translate(-g.width * 0.05, g.height * 0.08),
          s,
        );
      case ModelGlyph.phaser:
        c.drawPath(_wave(g, 1.5, 0.6), s);
        for (final t in [0.28, 0.5, 0.72]) {
          c.drawLine(
            Offset(g.left + g.width * t, g.top),
            Offset(g.left + g.width * t, g.top + g.height * 0.18),
            faint,
          );
        }
      case ModelGlyph.stepPhaser:
        final p = Path()..moveTo(g.left, g.center.dy);
        for (var i = 0; i < 6; i++) {
          final x0 = g.left + g.width * i / 6,
              x1 = g.left + g.width * (i + 1) / 6;
          final y = i.isEven
              ? g.top + g.height * 0.2
              : g.bottom - g.height * 0.2;
          p
            ..lineTo(x0, y)
            ..lineTo(x1, y);
        }
        c.drawPath(p, s);
      case ModelGlyph.hiCutPhaser:
        c.drawPath(_wave(g, 1.5, 0.45), faint);
        _filterCurve(c, g, s, lowCut: false, hiCut: true);
      case ModelGlyph.vibrato:
        c.drawPath(_wave(g, 4, 0.35), s);
      case ModelGlyph.rotary:
        final rr = g.height * 0.45;
        final rect = Rect.fromCircle(center: g.center, radius: rr);
        c.drawArc(rect, -0.4, 2.4, false, s);
        c.drawArc(rect, math.pi - 0.4, 2.4, false, s);
        c.drawCircle(g.center, rr * 0.22, fill);
        for (final a in [2.0, math.pi + 2.0]) {
          Offset at(double t) =>
              g.center + Offset(math.cos(t), math.sin(t)) * rr;
          _arrow(c, at(a - 0.3), at(a), s, head: g.height * 0.2);
        }
      case ModelGlyph.tremolo:
        c.drawPath(
          _wave(
            g,
            5,
            0.8,
            env: (t) => 0.25 + 0.75 * math.sin(math.pi * t * 2).abs(),
          ),
          s,
        );
      case ModelGlyph.stutter:
        final w = g.width / 9;
        for (var i = 0; i < 5; i++) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                g.left + i * w * 2,
                g.top + g.height * 0.15,
                w,
                g.height * 0.7,
              ),
              Radius.circular(w * 0.3),
            ),
            fill,
          );
        }
      case ModelGlyph.detune:
        c.drawPath(_wave(g, 2.0, 0.6), faint);
        c.drawPath(_wave(g, 2.3, 0.6), s);
      case ModelGlyph.ring:
        c.drawCircle(g.center, g.height * 0.46, s);
        c.drawPath(
          _wave(
            Rect.fromCenter(
              center: g.center,
              width: g.height * 0.7,
              height: g.height * 0.5,
            ),
            1.5,
            0.8,
          ),
          s,
        );
      case ModelGlyph.lofi:
        final p = Path()..moveTo(g.left, g.bottom);
        for (var i = 0; i < 6; i++) {
          final y = g.bottom - g.height * (i + 1) / 6 * (i.isEven ? 1 : 0.7);
          p
            ..lineTo(g.left + g.width * i / 6, y)
            ..lineTo(g.left + g.width * (i + 1) / 6, y);
        }
        c.drawPath(p, s);
      case ModelGlyph.swell:
        c.drawPath(_wave(g, 4, 0.9, env: (t) => t), s);
      case ModelGlyph.bandPass:
        _filterCurve(c, g, s, lowCut: true, hiCut: true);
      case ModelGlyph.lowCut:
        _filterCurve(c, g, s, lowCut: true, hiCut: false);
      case ModelGlyph.hiCut:
        _filterCurve(c, g, s, lowCut: false, hiCut: true);
      case ModelGlyph.pitch:
        _arrow(c, Offset(g.center.dx, g.bottom), Offset(g.center.dx, g.top), s);
        c.drawLine(
          Offset(g.left + g.width * 0.15, g.bottom),
          Offset(g.right - g.width * 0.15, g.bottom),
          faint,
        );
      case ModelGlyph.pitchPoly:
        _arrow(
          c,
          Offset(g.center.dx - g.width * 0.18, g.bottom),
          Offset(g.center.dx - g.width * 0.18, g.top + g.height * 0.2),
          s,
        );
        _arrow(
          c,
          Offset(g.center.dx + g.width * 0.18, g.bottom),
          Offset(g.center.dx + g.width * 0.18, g.top),
          s,
        );
      case ModelGlyph.echo:
        _bars(c, g, 5, fill);
      case ModelGlyph.digitalEcho:
        final n = 5;
        for (var i = 0; i < n; i++) {
          final k = 1 - i / n;
          final side = g.height * (0.35 + 0.5 * k);
          c.drawRect(
            Rect.fromLTWH(
              g.left + i * g.width / n,
              g.bottom - side,
              side * 0.6,
              side,
            ),
            Paint()..color = fill.color.withValues(alpha: 0.35 + 0.65 * k),
          );
        }
      case ModelGlyph.modEcho:
        _bars(c, g, 5, fill, topFrac: 0.75);
        c.drawPath(
          _wave(Rect.fromLTWH(g.left, g.top, g.width, g.height * 0.3), 2, 0.8),
          s,
        );
      case ModelGlyph.reverse:
        _bars(c, g, 5, fill, rising: true, topFrac: 0.7);
        _arrow(
          c,
          Offset(g.right, g.top + g.height * 0.1),
          Offset(g.left + g.width * 0.1, g.top + g.height * 0.1),
          s,
        );
      case ModelGlyph.dualEcho:
        final top = Rect.fromLTWH(g.left, g.top, g.width, g.height * 0.46);
        _bars(c, top, 5, fill);
        _bars(c, top.shift(Offset(0, g.height * 0.54)), 3, fill);
      case ModelGlyph.pingPong:
        final p = Path()..moveTo(g.left, g.top + g.height * 0.2);
        for (var i = 1; i <= 4; i++) {
          p.lineTo(
            g.left + g.width * i / 4,
            i.isEven ? g.top + g.height * 0.2 : g.bottom - g.height * 0.2,
          );
        }
        c.drawPath(p, faint);
        for (var i = 0; i <= 4; i++) {
          c.drawCircle(
            Offset(
              g.left + g.width * i / 4,
              i.isEven ? g.top + g.height * 0.2 : g.bottom - g.height * 0.2,
            ),
            g.height * (0.14 - i * 0.02),
            fill,
          );
        }
      case ModelGlyph.tape:
        final rr = g.height * 0.32;
        final l = Offset(
          g.left + g.width * 0.25,
          g.center.dy - g.height * 0.08,
        );
        final rt = Offset(
          g.right - g.width * 0.25,
          g.center.dy - g.height * 0.08,
        );
        for (final ctr in [l, rt]) {
          c.drawCircle(ctr, rr, s);
          c.drawCircle(ctr, rr * 0.25, fill);
          for (var k = 0; k < 3; k++) {
            final a = k * 2 * math.pi / 3;
            c.drawLine(
              ctr + Offset(math.cos(a), math.sin(a)) * rr * 0.3,
              ctr + Offset(math.cos(a), math.sin(a)) * rr * 0.85,
              faint,
            );
          }
        }
        c.drawLine(Offset(l.dx, l.dy + rr), Offset(rt.dx, rt.dy + rr), s);
      case ModelGlyph.spring:
        final p = Path();
        const loops = 6;
        for (var i = 0; i <= 120; i++) {
          final t = i / 120;
          final a = t * loops * 2 * math.pi;
          final x =
              g.left +
              t * g.width * 0.86 +
              math.cos(a) * g.width * 0.05 +
              g.width * 0.05;
          final y = g.center.dy + math.sin(a) * g.height * 0.38;
          i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
        }
        c.drawPath(p, s);
      case ModelGlyph.room:
        final room = Rect.fromCenter(
          center: g.center,
          width: g.height * 0.95,
          height: g.height * 0.85,
        );
        c.drawRect(room, s);
        _bars(
          c,
          room.deflate(room.width * 0.18),
          4,
          Paint()..color = accent.withValues(alpha: 0.8),
        );
      case ModelGlyph.hall:
        final arch = Path()
          ..moveTo(g.left + g.width * 0.12, g.bottom)
          ..lineTo(g.left + g.width * 0.12, g.center.dy)
          ..arcToPoint(
            Offset(g.right - g.width * 0.12, g.center.dy),
            radius: Radius.circular(g.width * 0.38),
          )
          ..lineTo(g.right - g.width * 0.12, g.bottom);
        c.drawPath(arch, s);
        for (final t in [0.35, 0.5, 0.65]) {
          c.drawLine(
            Offset(g.left + g.width * t, g.bottom),
            Offset(g.left + g.width * t, g.center.dy + g.height * 0.1),
            faint,
          );
        }
      case ModelGlyph.church:
        final p = Path()
          ..moveTo(g.center.dx - g.width * 0.24, g.bottom)
          ..lineTo(g.center.dx - g.width * 0.24, g.center.dy)
          ..lineTo(g.center.dx, g.top)
          ..lineTo(g.center.dx + g.width * 0.24, g.center.dy)
          ..lineTo(g.center.dx + g.width * 0.24, g.bottom);
        c.drawPath(p, s);
        final door = Path()
          ..moveTo(g.center.dx - g.width * 0.07, g.bottom)
          ..lineTo(g.center.dx - g.width * 0.07, g.center.dy + g.height * 0.12)
          ..lineTo(g.center.dx, g.center.dy)
          ..lineTo(g.center.dx + g.width * 0.07, g.center.dy + g.height * 0.12)
          ..lineTo(g.center.dx + g.width * 0.07, g.bottom);
        c.drawPath(door, faint);
      case ModelGlyph.plate:
        final plateRect = Rect.fromCenter(
          center: g.center.translate(0, g.height * 0.08),
          width: g.width * 0.62,
          height: g.height * 0.6,
        );
        c.drawRect(plateRect, s);
        for (final x in [plateRect.left, plateRect.right]) {
          c.drawLine(
            Offset(x, plateRect.top),
            Offset(x + (x == plateRect.left ? -1 : 1) * g.width * 0.1, g.top),
            faint,
          );
        }
        c.drawPath(
          _wave(plateRect.deflate(plateRect.height * 0.2), 2, 0.6),
          faint,
        );
      case ModelGlyph.cave:
        final p = Path()
          ..moveTo(g.left, g.bottom)
          ..quadraticBezierTo(
            g.left + g.width * 0.05,
            g.top - g.height * 0.1,
            g.center.dx,
            g.top + g.height * 0.08,
          )
          ..quadraticBezierTo(
            g.right - g.width * 0.02,
            g.top + g.height * 0.05,
            g.right,
            g.bottom,
          );
        c.drawPath(p, s);
        for (var i = 0; i < 3; i++) {
          final x = g.left + g.width * (0.3 + i * 0.2);
          c.drawLine(
            Offset(x, g.top + g.height * 0.2),
            Offset(x, g.top + g.height * (0.36 + i * 0.06)),
            faint,
          );
        }
      case ModelGlyph.modVerb:
        c.drawPath(_wave(g, 3, 0.85, env: (t) => math.exp(-2.4 * t)), s);
      case ModelGlyph.gate:
        final th = g.top + g.height * 0.45;
        _bars(c, g, 6, fill, rising: false);
        c.drawLine(Offset(g.left, th), Offset(g.right, th), faint);
      case ModelGlyph.eq:
        const levels = [0.7, 0.35, 0.55, 0.25];
        for (var i = 0; i < levels.length; i++) {
          final x = g.left + g.width * (i + 0.5) / levels.length;
          c.drawLine(Offset(x, g.top), Offset(x, g.bottom), faint);
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x, g.top + g.height * levels[i]),
                width: g.width * 0.13,
                height: g.height * 0.2,
              ),
              Radius.circular(g.height * 0.05),
            ),
            fill,
          );
        }
      case ModelGlyph.eq4:
        final path = Path();
        const nodes = [0.15, 0.4, 0.65, 0.88];
        const gains = [0.35, -0.4, 0.5, -0.2];
        double response(double t) {
          var v = 0.0;
          for (var k = 0; k < 4; k++) {
            final d = (t - nodes[k]) / 0.11;
            v += gains[k] * math.exp(-d * d);
          }
          return v;
        }
        for (var i = 0; i <= 60; i++) {
          final t = i / 60;
          final x = g.left + t * g.width;
          final y = g.center.dy - response(t) * g.height * 0.9;
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        c.drawLine(g.centerLeft, g.centerRight, faint);
        c.drawPath(path, s);
        for (var k = 0; k < 4; k++) {
          c.drawCircle(
            Offset(
              g.left + nodes[k] * g.width,
              g.center.dy - response(nodes[k]) * g.height * 0.9,
            ),
            g.height * 0.09,
            fill,
          );
        }
      case ModelGlyph.loop:
        final rect = Rect.fromCenter(
          center: g.center,
          width: g.width * 0.7,
          height: g.height * 0.8,
        );
        c.drawArc(rect, math.pi * 1.1, math.pi * 0.85, false, s);
        c.drawArc(rect, math.pi * 0.1, math.pi * 0.85, false, s);
        final a1 = math.pi * 1.95, a2 = math.pi * 0.95;
        Offset onEllipse(double a) => Offset(
          rect.center.dx + math.cos(a) * rect.width / 2,
          rect.center.dy + math.sin(a) * rect.height / 2,
        );
        _arrow(c, onEllipse(a1 - 0.3), onEllipse(a1), s, head: g.height * 0.2);
        _arrow(c, onEllipse(a2 - 0.3), onEllipse(a2), s, head: g.height * 0.2);
      case ModelGlyph.userIr:
        final ctr = Offset(g.left + g.width * 0.3, g.center.dy);
        final rr = g.height * 0.48;
        c.drawCircle(ctr, rr, s);
        c.drawCircle(ctr, rr * 0.35, fill);
        final spike = Path()
          ..moveTo(g.left + g.width * 0.62, g.center.dy)
          ..lineTo(g.left + g.width * 0.68, g.center.dy)
          ..lineTo(g.left + g.width * 0.7, g.top)
          ..lineTo(g.left + g.width * 0.73, g.bottom - g.height * 0.1)
          ..lineTo(g.left + g.width * 0.77, g.center.dy - g.height * 0.15)
          ..lineTo(g.left + g.width * 0.82, g.center.dy + g.height * 0.05)
          ..lineTo(g.right, g.center.dy);
        c.drawPath(spike, s);
    }
  }

  @override
  bool shouldRepaint(covariant ModelArtPainter old) =>
      old.art != art || old.accent != accent || old.plate != plate;
}
