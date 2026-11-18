import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/fx200_constants.dart';
import 'fx200_protocol.dart';

/// Frames the pedal returns after a `0xA6` preset select: the 10 module
/// states, the EXP assignment, the footswitch assignment and `0xBB` (always
/// last in `captura.pcapng`). All of them are also sent by `FX200.exe`, so
/// they can be replayed as-is when restoring.
const List<int> fx200PresetStateOpcodes = <int>[
  0x91,
  0x92,
  0x93,
  0x94,
  0x95,
  0x96,
  0x97,
  0x98,
  0x99,
  0x9a,
  Fx200Protocol.opCmdA3,
  Fx200Protocol.opCmdA4,
  Fx200Protocol.opCmdBb,
];

/// One preset as stored in a backup.
class Fx200PresetSnapshot {
  const Fx200PresetSnapshot({
    required this.index,
    required this.name,
    this.dump,
    this.stateFrames = const <int, Uint8List>{},
    this.chain,
  });

  final int index;
  final String name;

  /// Raw 4096-byte preset record from the `0xE0` dump (`0xA5` chunks 0..7).
  final Uint8List? dump;

  /// Raw bodies of the frames in [fx200PresetStateOpcodes], keyed by opcode.
  final Map<int, Uint8List> stateFrames;

  /// Opcodes (hex) that were not received when the preset was read.
  List<String> get missingFrames => [
    for (final op in fx200PresetStateOpcodes)
      if (!stateFrames.containsKey(op)) op.toRadixString(16).padLeft(2, '0'),
  ];

  /// True when every frame needed to rewrite this preset was captured.
  bool get isRestorable =>
      fx200PresetStateOpcodes.every(stateFrames.containsKey);

  /// Explicit `0xA0` body (order + flags), e.g. from the live chain cache.
  final Uint8List? chain;

  /// `0xA0` body (order + flags): [chain] if known, else from the raw dump.
  Uint8List? get chainBlock {
    if (chain != null) return chain;
    final d = dump;
    return d == null ? null : Fx200Protocol.chainBlockFromPresetDump(d);
  }

  /// Same preset content under a different name / slot.
  Fx200PresetSnapshot copyWith({int? index, String? name}) {
    return Fx200PresetSnapshot(
      index: index ?? this.index,
      name: name ?? this.name,
      dump: dump,
      stateFrames: stateFrames,
      chain: chain,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'name': name,
    if (dump != null) 'dump': base64Encode(dump!),
    if (chain != null) 'chain': _hex(chain!),
    'frames': <String, String>{
      for (final e in stateFrames.entries)
        e.key.toRadixString(16).padLeft(2, '0'): _hex(e.value),
    },
  };

  factory Fx200PresetSnapshot.fromJson(Map<String, Object?> json) {
    final frames = <int, Uint8List>{};
    final rawFrames = json['frames'];
    if (rawFrames is Map) {
      rawFrames.forEach((key, value) {
        final op = int.tryParse('$key', radix: 16);
        if (op != null && value is String) frames[op] = _unhex(value);
      });
    }
    final dump = json['dump'];
    final chain = json['chain'];
    return Fx200PresetSnapshot(
      chain: chain is String ? _unhex(chain) : null,
      index: (json['index'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      dump: dump is String ? base64Decode(dump) : null,
      stateFrames: frames,
    );
  }
}

/// Full device backup: global SYSTEM block + the 200 presets.
class Fx200Backup {
  const Fx200Backup({
    required this.createdAt,
    required this.presets,
    this.globalSettings,
  });

  static const String formatId = 'fx200studio-backup';
  static const int formatVersion = 1;
  static const String fileExtension = 'fx200backup';

  final DateTime createdAt;
  final Fx200GlobalSettings? globalSettings;
  final List<Fx200PresetSnapshot> presets;

  int get restorablePresetCount => presets.where((p) => p.isRestorable).length;

  String encode() =>
      const JsonEncoder.withIndent(' ').convert(<String, Object?>{
        'format': formatId,
        'version': formatVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (globalSettings != null) 'global': _hex(globalSettings!.raw),
        'presets': presets.map((p) => p.toJson()).toList(),
      });

  /// Parses a backup file; throws [FormatException] for foreign files.
  static Fx200Backup decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Not an FX200 Studio backup (invalid JSON).');
    }
    if (json is! Map || json['format'] != formatId) {
      throw const FormatException('Not an FX200 Studio backup.');
    }
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw FormatException('Backup version $version is newer than supported.');
    }
    final global = json['global'];
    final presets = (json['presets'] as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((p) => Fx200PresetSnapshot.fromJson(p.cast<String, Object?>()))
        .where((p) => p.index >= 0 && p.index < Fx200Constants.presetPatchCount)
        .toList();
    return Fx200Backup(
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      globalSettings: global is String
          ? Fx200GlobalSettings.fromBody(_unhex(global))
          : null,
      presets: presets,
    );
  }
}

/// Minimal view of the connected pedal needed to back up / restore it.
/// Implemented by `Fx200HardwareSync`; faked in tests.
abstract class Fx200DeviceLink {
  bool get isConnected;

  /// Every verified frame received from the pedal.
  Stream<({int opcode, Uint8List body})> get frames;

  void sendPacket(Uint8List packet);

  /// Completes once the pedal can answer `0xA6` (no `0xE0` dump running).
  Future<void> waitUntilReady();

  /// Last known `0xA0` body (order + flags) of preset [index], if any.
  Uint8List? chainBlockFor(int index);

  /// Records the chain written to preset [index] so later copies use it.
  void rememberChainBlock(int index, Uint8List chain);

  /// Re-reads all presets with `0xE0` and returns the complete raw records
  /// (index → 4096 bytes) plus the `0xA1` block the pedal sends with it.
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump();
}

typedef Fx200BackupProgress = void Function(double fraction, String message);

class Fx200BackupCancelled implements Exception {
  const Fx200BackupCancelled();
  @override
  String toString() => 'Cancelled';
}

/// Creates and restores backups using only opcodes confirmed in
/// `captura.pcapng` / `FX200.exe`:
///
/// * backup: `0xE0` dump (names, raw records, `0xA1`) + a `0xA6` sweep that
///   captures each preset's module/EXP/footswitch frames;
/// * restore: per preset `0xA6` select → `0xA0` chain → `0x91..0x9A` →
///   `0xA3` → `0xA4` → `0xBB` → `0xA8` save; then `0xA1` for globals.
///
/// The bulk-write opcode `0xAB` used by the official restore is avoided on
/// purpose: it was never observed on the wire.
class Fx200BackupService {
  Fx200BackupService(
    this.link, {
    this.presetCount = Fx200Constants.presetPatchCount,
    this.selectTimeout = const Duration(seconds: 3),
    this.packetGap = const Duration(milliseconds: 25),
    this.settleDelay = const Duration(milliseconds: 150),
  });

  final Fx200DeviceLink link;
  final int presetCount;
  final Duration selectTimeout;
  final Duration packetGap;
  final Duration settleDelay;

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  void _checkCancelled() {
    if (_cancelled) throw const Fx200BackupCancelled();
    if (!link.isConnected) {
      throw StateError('FX200 disconnected during the operation.');
    }
  }

  Future<Fx200Backup> createBackup({
    required Map<int, String> knownNames,
    Fx200BackupProgress? onProgress,
  }) async {
    _cancelled = false;
    _checkCancelled();
    onProgress?.call(0, 'Reading preset memory (0xE0)...');
    final full = await link.readFullDump();
    _checkCancelled();

    final presets = <Fx200PresetSnapshot>[];
    for (var i = 0; i < presetCount; i++) {
      _checkCancelled();
      onProgress?.call(
        0.1 + 0.9 * i / presetCount,
        'Reading preset ${_pad(i)} (${i + 1}/$presetCount)',
      );
      final frames = (await capturePreset(i)).stateFrames;
      final dump = full.dumps[i];
      presets.add(
        Fx200PresetSnapshot(
          index: i,
          name: knownNames[i] ?? _nameFromDump(dump) ?? '',
          dump: dump,
          stateFrames: frames,
          chain: link.chainBlockFor(i),
        ),
      );
    }
    onProgress?.call(1, 'Backup complete');
    return Fx200Backup(
      createdAt: DateTime.now(),
      globalSettings: full.global,
      presets: presets,
    );
  }

  Future<({int written, int skipped})> restoreBackup(
    Fx200Backup backup, {
    bool restorePresets = true,
    bool restoreGlobals = true,
    Fx200BackupProgress? onProgress,
  }) async {
    _cancelled = false;
    _checkCancelled();
    var written = 0;
    var skipped = 0;

    if (restorePresets) {
      final total = backup.presets.length;
      for (var n = 0; n < total; n++) {
        _checkCancelled();
        final p = backup.presets[n];
        onProgress?.call(
          n / total,
          'Writing preset ${_pad(p.index)} (${n + 1}/$total)',
        );
        if (!p.isRestorable) {
          skipped++;
          continue;
        }
        await writePreset(p);
        written++;
      }
    }

    final global = backup.globalSettings;
    if (restoreGlobals && global != null) {
      _checkCancelled();
      onProgress?.call(1, 'Writing global settings (0xA1)...');
      await _send(Fx200Protocol.buildGlobalSettingsPacket(global));
    }
    onProgress?.call(1, 'Restore complete');
    return (written: written, skipped: skipped);
  }

  /// Reads preset [index] from the pedal (selects it with `0xA6`).
  Future<Fx200PresetSnapshot> capturePreset(
    int index, {
    String name = '',
  }) async {
    _checkCancelled();
    var frames = await _selectAndCapture(index);
    for (
      var attempt = 0;
      attempt < 2 && !fx200PresetStateOpcodes.every(frames.containsKey);
      attempt++
    ) {
      frames = await _selectAndCapture(index);
    }
    return Fx200PresetSnapshot(
      index: index,
      name: name,
      stateFrames: frames,
      chain: link.chainBlockFor(index),
    );
  }

  /// Writes [p] into slot `target ?? p.index` and saves it under `p.name`.
  Future<void> writePreset(Fx200PresetSnapshot p, {int? target}) async {
    if (!p.isRestorable) {
      throw StateError('Preset ${_pad(p.index)} was not read completely.');
    }
    final slot = target ?? p.index;
    await _selectAndCapture(slot);
    final chain = p.chainBlock;
    if (chain != null) {
      await _send(Fx200Protocol.buildRawPacket(Fx200Protocol.opCmdA0, chain));
    }
    for (final op in fx200PresetStateOpcodes) {
      await _send(Fx200Protocol.buildRawPacket(op, p.stateFrames[op]!));
    }
    await _send(Fx200Protocol.buildPresetSavePacket(slot, p.name));
    if (chain != null) link.rememberChainBlock(slot, chain);
    await Future<void>.delayed(settleDelay);
  }

  Future<void> _send(Uint8List packet) async {
    _checkCancelled();
    link.sendPacket(packet);
    await Future<void>.delayed(packetGap);
  }

  /// Selects preset [index] and collects its state frames until `0xBB`.
  Future<Map<int, Uint8List>> _selectAndCapture(int index) async {
    await link.waitUntilReady();
    _checkCancelled();
    final captured = <int, Uint8List>{};
    final done = Completer<void>();
    final sub = link.frames.listen((f) {
      if (!fx200PresetStateOpcodes.contains(f.opcode)) return;
      captured[f.opcode] = f.body;
      if (f.opcode == Fx200Protocol.opCmdBb && !done.isCompleted) {
        done.complete();
      }
    });
    try {
      link.sendPacket(Fx200Protocol.buildPresetReadPacket(index));
      await done.future.timeout(selectTimeout, onTimeout: () {});
    } finally {
      await sub.cancel();
    }
    return captured;
  }

  static String _pad(int i) => i.toString().padLeft(3, '0');

  static String? _nameFromDump(Uint8List? dump) {
    if (dump == null) return null;
    final bytes = <int>[];
    for (var i = 0; i < 16 && i < dump.length; i++) {
      final b = dump[i];
      if (b == 0) break;
      if (b >= 32 && b < 127) bytes.add(b);
    }
    final name = String.fromCharCodes(bytes).trim();
    return name.isEmpty ? null : name;
  }
}

String _hex(List<int> bytes) =>
    bytes.map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String hex) {
  final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
