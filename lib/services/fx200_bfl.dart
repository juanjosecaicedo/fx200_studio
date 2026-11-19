import 'dart:async';
import 'dart:typed_data';

import '../core/l10n/l10n.dart';
import 'fx200_backup.dart';
import 'fx200_ir.dart';
import 'fx200_pfl.dart';
import 'fx200_protocol.dart';

/// Device backup of the official FX200 editor (`.bfl`).
///
/// Reverse-engineered from `FX200.exe` (writer `0x4282de`) and checked
/// byte-for-byte against a real backup (`backup.bfl` + `captura-backup`):
/// a 0x80-byte header (`"FX200"` at 0x00, editor version at 0x20) followed
/// by a raw copy of 0x8DF48 bytes of the editor's memory starting at
/// `0xDC5A60`, so every field sits at `0x80 + (address - 0xDC5A60)`:
///
/// | address            | content                                            |
/// |--------------------|----------------------------------------------------|
/// | 0xDC5A60           | last dump frame: 0x80, active preset u16 LE, chunk |
/// | 0xDC5A6C + i·0x840 | preset i (`PresetPara_TypeDef`, same as `.pfl`)    |
/// | 0xE2CC6C           | copy of the active preset                          |
/// | 0xE2D54C + s·16    | IR names in upper case, empty = `EMPTY` + spaces   |
/// | 0xE2D86C           | active preset u16 LE, last `0xAA` read state       |
/// | 0xE2D877 + s·0xC0F | IR s samples (3072 B, name area left zero)         |
/// | 0xE53365           | number of IR slots in use                          |
/// | 0xE53366 + s       | IR slot s in use (s + 1, else 0)                   |
/// | 0xE53398           | IR names, raw `0x85` body (50 × 15 B)              |
/// | 0xE536C4           | global SYSTEM block (`0xA1` body, 46 bytes)        |
/// | 0xE536F4           | `0xAA` type 5 chunk 0 (system info, holds the drum |
/// |                    | machine at +0xF8: on, style, type, volume, BPM LE) |
/// | 0xE538F4           | `0xAA` type 5 chunk 1 (first 180 bytes fit)        |
class Fx200Bfl {
  Fx200Bfl._({
    required this.presets,
    required this.irRecords,
    required this.global,
    required this.drum,
  });

  static const int fileSize = 0x8dfc8;
  static const String fileExtension = 'bfl';
  static const int _base = 0xdc5a60;

  static int _off(int address) => address - _base + Fx200Pfl.headerSize;

  /// The 200 preset structs (0x840 bytes each).
  final List<Uint8List> presets;

  /// IR records ready for `0xE1` (samples + 15-byte name) by slot 0..49.
  final Map<int, Uint8List> irRecords;
  final Fx200GlobalSettings global;

  /// Drum machine state, or null when the backup holds none (all zero).
  final Fx200DrumSettings? drum;

  List<String> get presetNames => presets.map(Fx200Pfl.nameOf).toList();

  factory Fx200Bfl.parse(Uint8List file) {
    if (file.length != fileSize) {
      throw FormatException(
        'Unsupported .bfl size ${file.length} B (expected $fileSize).',
      );
    }
    if (String.fromCharCodes(file.sublist(0, 5)) != Fx200Pfl.magic) {
      throw const FormatException('Not an FX200 backup file.');
    }
    Uint8List at(int address, int length) =>
        Uint8List.fromList(file.sublist(_off(address), _off(address) + length));

    final presets = <Uint8List>[
      for (var i = 0; i < 200; i++)
        at(0xdc5a6c + i * Fx200Pfl.structSize, Fx200Pfl.structSize),
    ];
    final irs = <int, Uint8List>{};
    for (var s = 0; s < Fx200Ir.slotCount; s++) {
      if (file[_off(0xe53366 + s)] == 0) continue;
      final record = Uint8List(Fx200Ir.recordSize)
        ..setRange(0, Fx200Ir.points * 3, at(0xe2d877 + s * 0xc0f, 3072));
      final name = at(0xe53398 + s * Fx200Ir.nameLength, Fx200Ir.nameLength);
      record.setRange(Fx200Ir.points * 3, Fx200Ir.recordSize, name);
      irs[s] = record;
    }
    final global = Fx200GlobalSettings.fromBody(
      at(0xe536c4, Fx200GlobalSettings.length),
    );
    final d = at(0xe537ec, 0x12);
    final drum = d[0x0c] == 0
        ? null
        : Fx200DrumSettings(
            on: d[0] != 0,
            style: d[0x0c].clamp(1, Fx200DrumSettings.metronomeStyle),
            groove: d[0x0d].clamp(1, Fx200DrumSettings.grooveCount),
            volume: d[0x0e].clamp(0, 100),
            bpm: (d[0x10] | d[0x11] << 8).clamp(
              Fx200DrumSettings.minBpm,
              Fx200DrumSettings.maxBpm,
            ),
          );
    return Fx200Bfl._(
      presets: presets,
      irRecords: irs,
      global: global,
      drum: drum,
    );
  }

  /// Builds a `.bfl` file identical to the official editor's backup.
  ///
  /// [records] are the 200 preset records (>= 0x840 bytes each, e.g. the
  /// 4096-byte `0xA5` dumps), [irSamples] the 3072 sample bytes of each
  /// used IR slot (from `0xAA` type 2), [irNamesBody] the `0x85` body,
  /// [globalBody] the `0xA1` body and [type5] the `0xAA` type 5 chunks 0
  /// and 1.
  static Uint8List build({
    required List<Uint8List> records,
    required int activePreset,
    required Map<int, Uint8List> irSamples,
    required Uint8List irNamesBody,
    required Uint8List globalBody,
    required Map<int, Uint8List> type5,
  }) {
    if (records.length != 200) {
      throw ArgumentError('A backup needs the 200 presets.');
    }
    final f = Uint8List(fileSize);
    void put(int address, List<int> data) {
      final o = _off(address);
      final n = (o + data.length > f.length ? f.length - o : data.length);
      f.setRange(o, o + n, data);
    }

    f.setRange(0, Fx200Pfl.magic.length, Fx200Pfl.magic.codeUnits);
    f.setRange(
      0x20,
      0x20 + Fx200Pfl.editorVersion.length,
      Fx200Pfl.editorVersion.codeUnits,
    );
    put(_base, <int>[0x80, 0, activePreset & 0xff, activePreset >> 8, 0, 7]);
    for (var i = 0; i < 200; i++) {
      put(
        0xdc5a6c + i * Fx200Pfl.structSize,
        records[i].sublist(0, Fx200Pfl.structSize),
      );
    }
    put(0xe2cc6c, records[activePreset].sublist(0, Fx200Pfl.structSize));
    for (var s = 0; s < Fx200Ir.slotCount; s++) {
      final start = s * Fx200Ir.nameLength;
      final entry = start + Fx200Ir.nameLength <= irNamesBody.length
          ? irNamesBody.sublist(start, start + Fx200Ir.nameLength)
          : Uint8List(Fx200Ir.nameLength);
      final isEmpty = Fx200Ir.decodeNames(<int>[
        ...entry,
        ...List<int>.filled(Fx200Ir.nameLength * (Fx200Ir.slotCount - 1), 0),
      ]).first.isEmpty;
      put(
        0xe2d54c + s * 16,
        isEmpty
            ? <int>[...'EMPTY       '.codeUnits, 0, 0, 0, 0]
            : <int>[
                for (final b in entry) (b >= 0x61 && b <= 0x7a) ? b - 0x20 : b,
                0,
              ],
      );
    }
    // Editor state right after a backup: active preset, last 0xAA read
    // (type 5, index 1, chunk 7) and the "read finished" flag.
    put(0xe2d86c, <int>[activePreset & 0xff, activePreset >> 8]);
    put(0xe2d871, const <int>[5, 1, 7, 0, 1]);
    var used = 0;
    for (final e in irSamples.entries) {
      put(0xe2d877 + e.key * 0xc0f, e.value.sublist(0, Fx200Ir.points * 3));
      f[_off(0xe53366 + e.key)] = e.key + 1;
      used++;
    }
    f[_off(0xe53365)] = used;
    put(
      0xe53398,
      irNamesBody.sublist(
        0,
        irNamesBody.length < 750 ? irNamesBody.length : 750,
      ),
    );
    put(0xe536c4, globalBody);
    if (type5[0] != null) put(0xe536f4, type5[0]!.sublist(0, 512));
    if (type5[1] != null) put(0xe538f4, type5[1]!.sublist(0, 512));
    return f;
  }
}

/// Reads with `0xAA` what a `.bfl` needs besides presets and `0xA1`: the
/// samples of the IR slots in [usedSlots] (type 2: `[2, slot+1, chunk 1..7]`
/// → `[2, slot+1, chunk, 512 B]`, or `[2, slot+1, ff]` when empty) and the
/// type 5 chunks 0-1 (`[5, 1, chunk]`), like the official backup does.
Future<({Map<int, Uint8List> irSamples, Map<int, Uint8List> type5})>
fx200ReadBackupExtras(
  Fx200DeviceLink link,
  Iterable<int> usedSlots, {
  Duration timeout = const Duration(seconds: 2),
  Fx200BackupProgress? onProgress,
}) async {
  await link.waitUntilReady();
  Future<Uint8List?> read(int type, int index, int chunk) async {
    final done = Completer<Uint8List?>();
    final sub = link.frames.listen((f) {
      if (f.opcode != 0xaa || f.body.length < 3) return;
      if (f.body[0] != type || f.body[1] != index) return;
      if (f.body[2] == 0xff) {
        if (!done.isCompleted) done.complete(null);
        return;
      }
      if (f.body[2] != chunk || f.body.length < 3 + 512) return;
      if (!done.isCompleted) {
        done.complete(Uint8List.fromList(f.body.sublist(3, 3 + 512)));
      }
    });
    try {
      link.sendPacket(
        Fx200Protocol.buildRawPacket(0xaa, <int>[type, index, chunk, 0, 0]),
      );
      return await done.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'The FX200 did not answer the backup read ($type/$index/$chunk).',
        ),
      );
    } finally {
      await sub.cancel();
    }
  }

  final slots = usedSlots.toList()..sort();
  final total = slots.length * 6 + 2;
  var done = 0;
  final irs = <int, Uint8List>{};
  for (final s in slots) {
    final bytes = BytesBuilder();
    var empty = false;
    for (var c = 1; c <= 6; c++) {
      final data = await read(2, s + 1, c);
      done++;
      onProgress?.call(done / total, 'Reading IR ${s + Fx200Ir.firstCabModel}');
      if (data == null) {
        empty = true;
        break;
      }
      bytes.add(data);
    }
    if (!empty) irs[s] = bytes.toBytes();
  }
  final type5 = <int, Uint8List>{};
  for (var c = 0; c <= 1; c++) {
    final data = await read(5, 1, c);
    done++;
    onProgress?.call(done / total, 'Reading system data');
    if (data != null) type5[c] = data;
  }
  return (irSamples: irs, type5: type5);
}

/// Writes an official backup to the pedal with frames already verified on
/// the hardware or in captures: `0xA1` globals, `0xAD` drum, `0xE1` user IRs
/// and the `0x83` preset upload. [isCancelled] is checked between steps;
/// what was written before a cancel stays written.
Future<({int presets, int irs})> fx200RestoreBfl(
  Fx200DeviceLink link,
  Fx200Bfl bfl, {
  bool presets = true,
  bool irs = true,
  bool globals = true,
  Fx200BackupProgress? onProgress,
  bool Function()? isCancelled,
  Duration uploadQuiet = const Duration(milliseconds: 800),
  Duration settle = const Duration(seconds: 1),
  int uploadAttempts = 3,
}) async {
  void check() {
    if (isCancelled?.call() ?? false) throw const Fx200BackupCancelled();
    if (!link.isConnected) {
      throw StateError('FX200 disconnected during the restore.');
    }
  }

  final total =
      (globals ? 1 : 0) +
      (irs ? bfl.irRecords.length : 0) +
      (presets ? bfl.presets.length : 0);
  var done = 0;
  void step(String message) {
    done++;
    onProgress?.call(total == 0 ? 1 : done / total, message);
  }

  await link.waitUntilReady();
  await Future<void>.delayed(settle);

  // Presets first: a SYSTEM (0xA1) write right before an upload kept the
  // pedal busy and it ignored the 0x83 request (real-pedal test). Each
  // upload is retried, since nothing is written when the pedal does not
  // ask for the data.
  var presetCount = 0;
  if (presets) {
    for (var i = 0; i < bfl.presets.length; i++) {
      check();
      for (var attempt = 1; ; attempt++) {
        try {
          await fx200UploadPresetStruct(
            link,
            i,
            bfl.presets[i],
            quiet: uploadQuiet,
          );
          break;
        } on TimeoutException {
          if (attempt >= uploadAttempts) {
            throw StateError(
              tr(
                'The FX200 did not accept preset {0} after {1} attempts; {2} presets were restored before it.',
                [i.toString().padLeft(3, '0'), attempt, presetCount],
              ),
            );
          }
          await Future<void>.delayed(settle);
        }
      }
      presetCount++;
      step('Preset ${i.toString().padLeft(3, '0')} written');
    }
  }
  var irCount = 0;
  if (irs) {
    for (final e in bfl.irRecords.entries) {
      check();
      await fx200UploadIr(link, e.key, e.value);
      irCount++;
      step('IR ${e.key + Fx200Ir.firstCabModel} written');
    }
  }
  if (globals) {
    check();
    link.sendPacket(Fx200Protocol.buildGlobalSettingsPacket(bfl.global));
    final drum = bfl.drum;
    if (drum != null) {
      link.sendPacket(Fx200Protocol.buildDrumPacket(drum.copyWith(on: false)));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    step('Global settings and drum machine written');
  }
  return (presets: presetCount, irs: irCount);
}
