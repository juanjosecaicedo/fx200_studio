import 'dart:ui' show Color;

import '../domain/entities/preset.dart';

/// Shape drawn for a model.
enum ModelArtKind {
  /// Combo amp (panel on top, grille below). `wide` = 2×12 style.
  combo,

  /// Amp head (tolex box with full-width front panel).
  head,

  /// Rack preamp unit.
  rack,

  /// Speaker cabinet; layout comes from [ModelArt.speakerCols]/[speakerRows].
  cab,

  /// Classic stompbox (knobs on top, footswitch at the bottom).
  stomp,

  /// Compact pedal with a hinged treadle covering the switch.
  compact,

  /// Wah / expression pedal.
  wah,

  /// Round "pie" fuzz enclosure.
  round,

  /// Dark plate with an effect-type glyph (MOD / DLY / REV / NS / EQ / LOOP).
  glyph,
}

/// Effect-type symbols for [ModelArtKind.glyph].
enum ModelGlyph {
  chorus,
  triChorus,
  flanger,
  jet,
  phaser,
  stepPhaser,
  hiCutPhaser,
  vibrato,
  rotary,
  tremolo,
  stutter,
  detune,
  ring,
  lofi,
  swell,
  bandPass,
  lowCut,
  hiCut,
  pitch,
  pitchPoly,
  echo,
  tape,
  digitalEcho,
  pingPong,
  modEcho,
  reverse,
  dualEcho,
  spring,
  room,
  hall,
  church,
  plate,
  cave,
  modVerb,
  gate,
  eq,
  eq4,
  loop,
  userIr,
}

/// Grille / surface treatments.
enum ModelArtTexture { plain, tweed, diamond, basketweave, diamondPlate }

/// Original, brand-free illustration spec for one FX200 model.
///
/// The FX200 manual says which classic unit each model is "based on"; these
/// specs only evoke the *type* of gear (combo vs head, era-typical colours,
/// speaker layout, pedal shape) so models are easy to recognise at a glance.
/// No logos, trade names or product photos are reproduced.
class ModelArt {
  const ModelArt({
    required this.kind,
    this.body = const Color(0xFF1C1C1E),
    this.panel = const Color(0xFF121214),
    this.grille = const Color(0xFF2C2C2E),
    this.knob = const Color(0xFFD9DDE2),
    this.knobs = 4,
    this.led,
    this.wide = false,
    this.speakerCols = 1,
    this.speakerRows = 1,
    this.speakerSize = 12,
    this.slant = false,
    this.texture = ModelArtTexture.plain,
    this.glyph,
    this.piping,
  });

  final ModelArtKind kind;
  final Color body;
  final Color panel;
  final Color grille;
  final Color knob;
  final int knobs;
  final Color? led;
  final bool wide;
  final int speakerCols;
  final int speakerRows;
  final int speakerSize;
  final bool slant;
  final ModelArtTexture texture;
  final ModelGlyph? glyph;
  final Color? piping;

  ModelArt withLed(Color? c) => ModelArt(
    kind: kind,
    body: body,
    panel: panel,
    grille: grille,
    knob: knob,
    knobs: knobs,
    led: c,
    wide: wide,
    speakerCols: speakerCols,
    speakerRows: speakerRows,
    speakerSize: speakerSize,
    slant: slant,
    texture: texture,
    glyph: glyph,
    piping: piping,
  );
}

/// Lookup of [ModelArt] for every model in `Fx200Models`.
class Fx200ModelArt {
  Fx200ModelArt._();

  // Shared palette (generic, era-typical finishes).
  static const Color _black = Color(0xFF1B1B1D);
  static const Color _blackPanel = Color(0xFF111113);
  static const Color _silver = Color(0xFFB9BEC4);
  static const Color _chrome = Color(0xFFD3D7DB);
  static const Color _gold = Color(0xFFD1AE4A);
  static const Color _tweed = Color(0xFFC9A46A);
  static const Color _oxblood = Color(0xFF5E3B2A);
  static const Color _cream = Color(0xFFE9DFC6);
  static const Color _orange = Color(0xFFE07A1F);
  static const Color _navy = Color(0xFF233A5E);
  static const Color _royal = Color(0xFF214A8A);
  static const Color _wheat = Color(0xFFCBBE98);
  static const Color _darkCloth = Color(0xFF2D2B29);

  static const Color ledClean = Color(0xFF34D399);
  static const Color ledCrunch = Color(0xFFF59E0B);
  static const Color ledLead = Color(0xFFEF4444);
  static const Color ledBlue = Color(0xFF3B82F6);

  /// Channel LED inferred from the model name (CL / CR-OD / DS, colours).
  static Color? channelLed(String name) {
    final n = ' ${name.toUpperCase()} ';
    if (n.contains(' GREEN ')) return ledClean;
    if (n.contains(' BLUE ')) return ledBlue;
    if (n.contains(' RED ')) return ledLead;
    if (n.contains(' CL ')) return ledClean;
    if (n.contains(' OD B ') || n.contains(' DS B ')) return ledLead;
    if (n.contains(' CR ') ||
        n.contains(' OD ') ||
        n.contains(' OD A ') ||
        n.contains(' DS A ') ||
        n.contains(' CH2 ')) {
      return ledCrunch;
    }
    if (n.contains(' DS') || n.contains(' OD B ') || n.contains(' CH3 ')) {
      return ledLead;
    }
    return null;
  }

  static const ModelArt _blackfaceCombo = ModelArt(
    kind: ModelArtKind.combo,
    body: _black,
    panel: _blackPanel,
    grille: _silver,
    knob: Color(0xFFBFC3C8),
    knobs: 6,
  );

  /// Amp families keyed by the start of the model name.
  static const Map<String, ModelArt> _amps = <String, ModelArt>{
    'US 65 DR': _blackfaceCombo,
    'US 65 TR': ModelArt(
      kind: ModelArtKind.combo,
      wide: true,
      body: _black,
      panel: _blackPanel,
      grille: _silver,
      knob: Color(0xFFBFC3C8),
      knobs: 7,
    ),
    '59 BASSGUY': ModelArt(
      kind: ModelArtKind.combo,
      body: _tweed,
      panel: _chrome,
      grille: _oxblood,
      knob: Color(0xFF3A2A1E),
      knobs: 6,
      texture: ModelArtTexture.tweed,
    ),
    'GALAXY': ModelArt(
      kind: ModelArtKind.combo,
      body: _navy,
      panel: _blackPanel,
      grille: _wheat,
      knobs: 5,
    ),
    'UK COMBO': ModelArt(
      kind: ModelArtKind.combo,
      wide: true,
      body: _black,
      panel: Color(0xFFB4703C),
      grille: Color(0xFF6E4126),
      knob: Color(0xFF2A1F18),
      knobs: 6,
      texture: ModelArtTexture.diamond,
    ),
    'BRIT J45': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _gold,
      knob: Color(0xFF1E1E1E),
      knobs: 6,
      piping: _cream,
    ),
    'BRIT PLEXI': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: Color(0xFFE2C35A),
      knob: Color(0xFF1E1E1E),
      knobs: 6,
      piping: _cream,
    ),
    'BRIT J800': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _gold,
      knob: Color(0xFF1E1E1E),
      knobs: 6,
    ),
    'BRIT J900': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _gold,
      knob: Color(0xFF1E1E1E),
      knobs: 8,
    ),
    'BRIT J410': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _gold,
      knob: Color(0xFF1E1E1E),
      knobs: 9,
    ),
    'BRIT M9004': ModelArt(
      kind: ModelArtKind.rack,
      body: _black,
      panel: _blackPanel,
      knob: _silver,
      knobs: 8,
    ),
    'FRYMAN': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: Color(0xFF1F1F21),
      knob: _gold,
      knobs: 7,
      piping: Color(0xFFBFA87A),
    ),
    'ARCHEAN': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _silver,
      knob: Color(0xFF202022),
      knobs: 7,
    ),
    'CITRUS': ModelArt(
      kind: ModelArtKind.head,
      body: _orange,
      panel: _cream,
      knob: Color(0xFF1E1E1E),
      knobs: 6,
    ),
    'CUSTOM 100': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _silver,
      knob: Color(0xFF202022),
      knobs: 6,
    ),
    'US CLASSIC': ModelArt(
      kind: ModelArtKind.combo,
      wide: true,
      body: _tweed,
      panel: _chrome,
      grille: _oxblood,
      knob: Color(0xFF2A2A2C),
      knobs: 8,
      texture: ModelArtTexture.tweed,
    ),
    '5153': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _blackPanel,
      knob: Color(0xFF3A3A3C),
      knobs: 9,
    ),
    'SOLO 100': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _chrome,
      knob: Color(0xFF1E1E1E),
      knobs: 8,
    ),
    'CALI TEXAS': ModelArt(
      kind: ModelArtKind.combo,
      body: _black,
      panel: _blackPanel,
      grille: Color(0xFF8E7A55),
      knob: Color(0xFFDADADA),
      knobs: 8,
      texture: ModelArtTexture.basketweave,
    ),
    'CALI REC': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: Color(0xFFA9AEB4),
      knob: Color(0xFF1E1E1E),
      knobs: 8,
      texture: ModelArtTexture.diamondPlate,
    ),
    'CALI V': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _blackPanel,
      knob: _chrome,
      knobs: 9,
    ),
    'SHIVANI': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _silver,
      knob: Color(0xFF1E1E1E),
      knobs: 7,
    ),
    'ECSTATIC': ModelArt(
      kind: ModelArtKind.head,
      body: _royal,
      panel: _silver,
      knob: Color(0xFF1E1E1E),
      knobs: 9,
    ),
    'HERBART': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: Color(0xFF26262A),
      knob: _chrome,
      knobs: 9,
    ),
    'DIZZY V4': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: _silver,
      knob: Color(0xFF1E1E1E),
      knobs: 9,
    ),
    'SEVERE': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: Color(0xFF232326),
      knob: Color(0xFFC0392B),
      knobs: 8,
    ),
    'POWER': ModelArt(
      kind: ModelArtKind.head,
      body: _black,
      panel: Color(0xFF1A1A1C),
      knob: _silver,
      knobs: 9,
      piping: Color(0xFFC0392B),
    ),
  };

  /// Cabinet families: (tolex, grille, texture).
  static const Map<String, (Color, Color, ModelArtTexture)> _cabFinish =
      <String, (Color, Color, ModelArtTexture)>{
        '65 DR': (_black, _silver, ModelArtTexture.plain),
        '65 TR': (_black, _silver, ModelArtTexture.plain),
        'BASSGUY': (_tweed, _oxblood, ModelArtTexture.tweed),
        'GALAXY': (_navy, _wheat, ModelArtTexture.plain),
        'COMBO': (_black, Color(0xFF6E4126), ModelArtTexture.diamond),
        '1936': (_black, _wheat, ModelArtTexture.basketweave),
        '1960': (_black, _wheat, ModelArtTexture.basketweave),
        'FRYMAN': (_black, Color(0xFF5A5246), ModelArtTexture.basketweave),
        'ARCHEAN': (_black, _darkCloth, ModelArtTexture.plain),
        'CITRUS': (_orange, Color(0xFFD9CCAA), ModelArtTexture.basketweave),
        'CUSTOM': (_black, _darkCloth, ModelArtTexture.plain),
        'US CLASSIC': (_tweed, _oxblood, ModelArtTexture.tweed),
        '5153': (_black, Color(0xFF232325), ModelArtTexture.plain),
        'SOLO': (_black, _darkCloth, ModelArtTexture.plain),
        'CALI TEXAS': (_black, Color(0xFF8E7A55), ModelArtTexture.basketweave),
        'CALI': (_black, Color(0xFF1F1F21), ModelArtTexture.diamondPlate),
        'BOGNAR': (_black, Color(0xFFBFAE84), ModelArtTexture.basketweave),
        'DIZZY': (_black, Color(0xFF29292B), ModelArtTexture.plain),
        'SEVERE': (_black, Color(0xFF242426), ModelArtTexture.plain),
        'POWER': (_black, Color(0xFF242426), ModelArtTexture.plain),
      };

  static const Set<String> _slantCabs = <String>{
    '1960 412 A',
    'SOLO 412',
    'CALI REC 412 B',
    'CALI V 412',
  };

  static ModelArt _pedal(
    ModelArtKind kind,
    int body, {
    int knob = 0xFF1C1C1E,
    int knobs = 3,
    int led = 0xFFEF4444,
  }) {
    return ModelArt(
      kind: kind,
      body: Color(body),
      knob: Color(knob),
      knobs: knobs,
      led: Color(led),
    );
  }

  static final Map<String, ModelArt> _pedals = <String, ModelArt>{
    // FX
    'CS COMP': _pedal(ModelArtKind.compact, 0xFF2F6FC4, knobs: 4),
    'JR COMP': _pedal(ModelArtKind.stomp, 0xFFB8BDC3, knobs: 3),
    'AUTO WAH': _pedal(ModelArtKind.stomp, 0xFF6C3FA3, knob: 0xFFE8E8E8),
    '95 CRY': _pedal(ModelArtKind.wah, 0xFF1F1F21),
    '535 CRY': _pedal(ModelArtKind.wah, 0xFF2B2B2E, led: 0xFF22C55E),
    'TALK AH': _pedal(ModelArtKind.wah, 0xFF7B3B9C),
    'TALK OH': _pedal(ModelArtKind.wah, 0xFF33689A),
    'DYNAMIC WAH': _pedal(ModelArtKind.stomp, 0xFF2E8B57, knob: 0xFFE8E8E8),
    // DS / OD
    'SMOOTH BOOST': _pedal(ModelArtKind.stomp, 0xFFE3E3E3, knobs: 4),
    'CLEAN BOOST': _pedal(ModelArtKind.stomp, 0xFFC4C8CC, knobs: 4),
    'DARK RAT': _pedal(ModelArtKind.stomp, 0xFF151517, knob: 0xFF2E2E31),
    'GOLD BOX': _pedal(ModelArtKind.stomp, 0xFFD1AE4A, knob: 0xFFE6E6E6),
    'RIOTER': _pedal(ModelArtKind.stomp, 0xFF2A2A2D, knob: 0xFFE6E6E6),
    'SCREAMER 808': _pedal(ModelArtKind.stomp, 0xFF3C9A57),
    'TUBE OD': _pedal(ModelArtKind.stomp, 0xFF8D9196, knobs: 4),
    'ML ZONE': _pedal(
      ModelArtKind.compact,
      0xFF29292C,
      knobs: 4,
      knob: 0xFF3C3C40,
    ),
    'ML MASTER': _pedal(ModelArtKind.stomp, 0xFF1E1E21, knob: 0xFFE07A1F),
    'TIGHT GAIN': _pedal(ModelArtKind.stomp, 0xFFB52A2A, knob: 0xFFE6E6E6),
    'TIGHT METAL': _pedal(ModelArtKind.stomp, 0xFF141416, knob: 0xFFC0392B),
    'VX SILVERY': _pedal(ModelArtKind.stomp, 0xFFC9CCCF),
    'DIRECT OD': _pedal(ModelArtKind.stomp, 0xFFE8DCC0),
    'OBSESSIVE OD': _pedal(ModelArtKind.stomp, 0xFFF1F1F1),
    'UK SHREDDER': _pedal(
      ModelArtKind.stomp,
      0xFF1C1C1E,
      knobs: 4,
      knob: 0xFFD1AE4A,
    ),
    'FULL DS': _pedal(ModelArtKind.stomp, 0xFF3E9F99, knobs: 4),
    'RED 500': _pedal(
      ModelArtKind.stomp,
      0xFFBF3A2E,
      knobs: 4,
      knob: 0xFFE6E6E6,
    ),
    'JIMMY DRIVE': _pedal(ModelArtKind.stomp, 0xFFEDEDED, knobs: 4),
    'BEEBEE PREAMP': _pedal(ModelArtKind.stomp, 0xFFE6C66A, knobs: 4),
    'BEEBEE PLUS': _pedal(
      ModelArtKind.stomp,
      0xFF1E1E21,
      knobs: 4,
      knob: 0xFFD1AE4A,
    ),
    'ROUND FUZZ': _pedal(
      ModelArtKind.round,
      0xFFC62828,
      knobs: 2,
      knob: 0xFFE6E6E6,
    ),
    'SILVERY FUZZ': _pedal(ModelArtKind.stomp, 0xFFC5C8CB),
  };

  static const Map<String, ModelGlyph> _modGlyphs = <String, ModelGlyph>{
    '70S CHORUS': ModelGlyph.chorus,
    'TRI CHORUS': ModelGlyph.triChorus,
    'ANA FLANGER': ModelGlyph.flanger,
    'JET FLANGER': ModelGlyph.jet,
    '70S PHASER': ModelGlyph.phaser,
    'STEP PHASER': ModelGlyph.stepPhaser,
    'HI-CUT PHASER': ModelGlyph.hiCutPhaser,
    'PITCH VIBRATO': ModelGlyph.vibrato,
    'VIBE ROTARY': ModelGlyph.rotary,
    'TREMOLO': ModelGlyph.tremolo,
    'STAMMER': ModelGlyph.stutter,
    'DETUNE': ModelGlyph.detune,
    'RING': ModelGlyph.ring,
    'LOFI': ModelGlyph.lofi,
    'SLOW GEAR': ModelGlyph.swell,
    'BAND-PASS': ModelGlyph.bandPass,
    'LOW-CUT': ModelGlyph.lowCut,
    'HI-CUT': ModelGlyph.hiCut,
    'PITCH MONO': ModelGlyph.pitch,
    'PITCH POLY': ModelGlyph.pitchPoly,
  };

  static const Map<String, ModelGlyph> _delayGlyphs = <String, ModelGlyph>{
    'ANALOG': ModelGlyph.echo,
    'REAL': ModelGlyph.echo,
    'TAPE': ModelGlyph.tape,
    'DIGITAL': ModelGlyph.digitalEcho,
    'PINGPONG': ModelGlyph.pingPong,
    'MOD': ModelGlyph.modEcho,
    'REVERSE': ModelGlyph.reverse,
    'DYNAMIC': ModelGlyph.echo,
    'DUAL': ModelGlyph.dualEcho,
  };

  static const Map<String, ModelGlyph> _reverbGlyphs = <String, ModelGlyph>{
    'SPRING': ModelGlyph.spring,
    'ROOM': ModelGlyph.room,
    'HALL': ModelGlyph.hall,
    'CHURCH': ModelGlyph.church,
    'PLATE': ModelGlyph.plate,
    'CAVE': ModelGlyph.cave,
    'MOD': ModelGlyph.modVerb,
  };

  static ModelArt _glyph(ModelGlyph g) =>
      ModelArt(kind: ModelArtKind.glyph, glyph: g);

  static String? _prefixMatch(Iterable<String> keys, String name) {
    String? best;
    for (final k in keys) {
      if (name.startsWith(k) && (best == null || k.length > best.length)) {
        best = k;
      }
    }
    return best;
  }

  /// Illustration spec for [modelName] in [category] (always non-null; falls
  /// back to a generic look for unknown names).
  static ModelArt artFor(EffectCategory category, String modelName) {
    final name = modelName.trim().toUpperCase();
    switch (category) {
      case EffectCategory.amp:
        final key = _prefixMatch(_amps.keys.map((k) => k.toUpperCase()), name);
        final base = key == null
            ? const ModelArt(kind: ModelArtKind.head, knobs: 6)
            : _amps.entries.firstWhere((e) => e.key.toUpperCase() == key).value;
        return base.withLed(channelLed(name));
      case EffectCategory.cab:
        if (name.startsWith('USER IR')) return _glyph(ModelGlyph.userIr);
        return _cabFor(name);
      case EffectCategory.compressor:
      case EffectCategory.drive:
        return _pedals[name] ?? _pedal(ModelArtKind.stomp, 0xFF555A60);
      case EffectCategory.modulation:
        return _glyph(_modGlyphs[name] ?? ModelGlyph.chorus);
      case EffectCategory.delay:
        return _glyph(_delayGlyphs[name] ?? ModelGlyph.echo);
      case EffectCategory.reverb:
        return _glyph(_reverbGlyphs[name] ?? ModelGlyph.hall);
      case EffectCategory.gate:
        return _glyph(ModelGlyph.gate);
      case EffectCategory.eq:
        return _glyph(name.startsWith('4') ? ModelGlyph.eq4 : ModelGlyph.eq);
      case EffectCategory.volume:
        return _glyph(ModelGlyph.loop);
    }
  }

  static ModelArt _cabFor(String name) {
    var cols = 1, rows = 1, size = 12;
    if (name.contains('412')) {
      cols = 2;
      rows = 2;
    } else if (name.contains('410')) {
      cols = 2;
      rows = 2;
      size = 10;
    } else if (name.contains('212')) {
      cols = 2;
    }
    final key = _prefixMatch(_cabFinish.keys, name);
    final finish = key == null
        ? (_black, _darkCloth, ModelArtTexture.plain)
        : _cabFinish[key]!;
    return ModelArt(
      kind: ModelArtKind.cab,
      body: finish.$1,
      grille: finish.$2,
      texture: finish.$3,
      speakerCols: cols,
      speakerRows: rows,
      speakerSize: size,
      slant: _slantCabs.contains(name),
    );
  }
}
