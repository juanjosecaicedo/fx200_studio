import 'dart:typed_data';

import '../core/fx200_constants.dart';
import '../core/fx200_models.dart';
import 'fx200_backup.dart';
import 'fx200_protocol.dart';

/// Copy / paste / move of presets on the pedal, built on the same confirmed
/// read (`0xA6` sweep) and write (`0xA0`, `0x91..0x9A`, `0xA3`, `0xA4`,
/// `0xBB`, `0xA8`) primitives as backup & restore.
class Fx200PresetOps {
  Fx200PresetOps(Fx200DeviceLink link, {Fx200BackupService? io})
    : _io = io ?? Fx200BackupService(link);

  final Fx200BackupService _io;

  void cancel() => _io.cancel();

  static String _nameOf(Map<int, String> names, int index) {
    final n = names[index];
    return (n != null && n.isNotEmpty)
        ? n
        : Fx200Models.defaultPresetName(index);
  }

  /// Reads preset [index] into a clipboard snapshot.
  Future<Fx200PresetSnapshot> copy(int index, Map<int, String> names) async {
    final snap = await _io.capturePreset(index, name: _nameOf(names, index));
    if (!snap.isRestorable) {
      throw StateError(
        'Could not read preset ${_pad(index)} completely; nothing copied. '
        '${_missingHint(snap)}',
      );
    }
    return snap;
  }

  /// Name written by [clear] (the pedal's own unused slots are "Empty").
  static const String clearedName = 'Empty';

  /// `0xA3` body seen on every preset in captura.pcapng (no EXP assignment).
  static final Uint8List defaultExpBody = Uint8List.fromList(const <int>[
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);

  /// Builds the "cleared" version of [current]: every module switched off
  /// (model and parameters kept, so no value is invented), default chain
  /// order, footswitch OFF with no CTRL modules at 120 BPM, no EXP
  /// assignment, and [name].
  static Fx200PresetSnapshot clearedFrom(
    Fx200PresetSnapshot current, {
    String name = clearedName,
  }) {
    final frames = <int, Uint8List>{};
    for (final op in fx200PresetStateOpcodes) {
      final body = current.stateFrames[op];
      if (body == null) continue;
      if (op >= 0x91 && op <= 0x9a) {
        final off = Uint8List.fromList(body);
        if (off.length >= 2) {
          off[0] = 0; // enabled word (u16BE) = 0
          off[1] = 0;
        }
        frames[op] = off;
      }
    }
    frames[Fx200Protocol.opCmdA3] = Uint8List.fromList(defaultExpBody);
    frames[Fx200Protocol.opCmdA4] = Uint8List.fromList(const <int>[
      Fx200FootswitchConfig.modeOff,
      0x00,
      0x00,
      0x00,
      120,
    ]);
    frames[Fx200Protocol.opCmdBb] = Uint8List(2);
    return Fx200PresetSnapshot(
      index: current.index,
      name: name,
      stateFrames: frames,
      chain: Uint8List.fromList(<int>[
        for (var id = 1; id <= 10; id++) id,
        ...List<int>.filled(10, 0),
      ]),
    );
  }

  /// Resets preset [index] on the pedal (see [clearedFrom]). The current
  /// content is read first; nothing is written if that read fails.
  Future<Fx200PresetSnapshot> clear(
    int index, {
    String name = clearedName,
  }) async {
    final current = await _io.capturePreset(index, name: name);
    if (!current.isRestorable) {
      throw StateError(
        'Could not read preset ${_pad(index)} completely; nothing cleared. '
        '${_missingHint(current)}',
      );
    }
    final cleared = clearedFrom(current, name: name);
    await _io.writePreset(cleared);
    return cleared;
  }

  /// Overwrites preset [target] with [clip] (keeps the copied name).
  Future<void> paste(Fx200PresetSnapshot clip, int target) async {
    await _io.writePreset(clip, target: target);
  }

  /// Moves preset [from] to position [to]; the presets in between shift by
  /// one slot (like reordering a list). Every affected preset is read first
  /// and nothing is written unless all reads succeeded.
  ///
  /// Returns the new names of the rewritten slots.
  Future<Map<int, String>> move(
    int from,
    int to,
    Map<int, String> names, {
    Fx200BackupProgress? onProgress,
  }) async {
    const count = Fx200Constants.presetPatchCount;
    if (from == to || from < 0 || to < 0 || from >= count || to >= count) {
      return const <int, String>{};
    }
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    final total = hi - lo + 1;

    final original = <Fx200PresetSnapshot>[];
    for (var i = lo; i <= hi; i++) {
      onProgress?.call(
        0.5 * (i - lo) / total,
        'Reading preset ${_pad(i)} (${i - lo + 1}/$total)',
      );
      final snap = await _io.capturePreset(i, name: _nameOf(names, i));
      if (!snap.isRestorable) {
        throw StateError(
          'Could not read preset ${_pad(i)} completely. '
          'Nothing was changed on the pedal. ${_missingHint(snap)}',
        );
      }
      original.add(snap);
    }

    final reordered = List<Fx200PresetSnapshot>.of(original);
    final moved = reordered.removeAt(from - lo);
    reordered.insert(to - lo, moved);

    final newNames = <int, String>{};
    for (var k = 0; k < total; k++) {
      final slot = lo + k;
      onProgress?.call(
        0.5 + 0.5 * k / total,
        'Writing preset ${_pad(slot)} (${k + 1}/$total)',
      );
      await _io.writePreset(reordered[k], target: slot);
      newNames[slot] = reordered[k].name;
    }
    onProgress?.call(1, 'Preset moved');
    return newNames;
  }

  static String _pad(int i) => i.toString().padLeft(3, '0');

  static String _missingHint(Fx200PresetSnapshot snap) {
    final missing = snap.missingFrames;
    if (missing.length == fx200PresetStateOpcodes.length) {
      return 'The pedal did not answer the preset request (0xA6). Leave the '
          'pedal on its main preset screen (not in a menu, tuner or looper) '
          'and try again.';
    }
    return 'Missing frames: ${missing.join(', ')}.';
  }
}
