import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ir_wav.dart';
import '../../services/fx200_ir.dart';
import 'editor_notifier.dart';
import '../../core/l10n/l10n.dart';

class IrState {
  const IrState({
    this.names,
    this.busySlot,
    this.progress = 0,
    this.message,
    this.isError = false,
  });

  /// Names of user IR slots 0..49 (CAB 31..80); '' = empty. Null until
  /// the pedal sends `0x85`.
  final List<String>? names;
  final int? busySlot;
  final double progress;
  final String? message;
  final bool isError;

  bool get isBusy => busySlot != null;

  IrState copyWith({
    List<String>? names,
    int? busySlot,
    bool clearBusy = false,
    double? progress,
    String? message,
    bool? isError,
  }) {
    return IrState(
      names: names ?? this.names,
      busySlot: clearBusy ? null : (busySlot ?? this.busySlot),
      progress: progress ?? this.progress,
      message: message ?? this.message,
      isError: isError ?? this.isError,
    );
  }
}

final irProvider = NotifierProvider<IrNotifier, IrState>(IrNotifier.new);

/// User impulse responses: slot names (`0x85`) and WAV loading (`0xE1`).
class IrNotifier extends Notifier<IrState> {
  @override
  IrState build() {
    final sync = ref.watch(fx200HardwareSyncProvider);
    final sub = sync.frames.listen((f) {
      if (f.opcode == Fx200Ir.opNames) {
        state = state.copyWith(names: Fx200Ir.decodeNames(f.body));
      }
    });
    ref.onDispose(sub.cancel);
    return IrState(names: sync.irNames);
  }

  /// Display name of CAB model [modelName] (`USER IR 31`..`USER IR 80`),
  /// with the loaded IR's name when known.
  String labelFor(String modelName) {
    final m = RegExp(r'^USER IR (\d+)$').firstMatch(modelName);
    final names = state.names;
    if (m == null || names == null) return modelName;
    final slot = int.parse(m.group(1)!) - Fx200Ir.firstCabModel;
    if (slot < 0 || slot >= names.length) return modelName;
    final n = names[slot];
    return n.isEmpty ? '$modelName (empty)' : '${m.group(1)} $n';
  }

  /// Clears user IR [slot] (0..49) on the pedal.
  Future<void> deleteSlot(int slot) async {
    if (state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    final label = slot + Fx200Ir.firstCabModel;
    try {
      state = state.copyWith(
        busySlot: slot,
        progress: 0,
        message: tr('Deleting IR {0}...', [label]),
        isError: false,
      );
      await fx200DeleteIr(
        sync,
        slot,
        onProgress: (p) => state = state.copyWith(progress: p),
      );
      sync.rememberIrName(slot, '');
      final names = List<String>.of(
        state.names ?? List<String>.filled(Fx200Ir.slotCount, ''),
      )..[slot] = '';
      state = state.copyWith(
        names: names,
        clearBusy: true,
        progress: 1,
        message: tr('IR {0} deleted.', [label]),
      );
    } catch (e) {
      state = state.copyWith(clearBusy: true, message: '$e', isError: true);
    }
  }

  /// Converts the WAV at [path] and writes it into [slot] (0..49).
  Future<void> loadWav(int slot, String path) async {
    if (state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    final fileName = path.split(Platform.pathSeparator).last;
    try {
      final wav = IrWavFile.fromBytes(await File(path).readAsBytes());
      // IrWavFile already keeps only the first channel of each frame.
      final name = Fx200Ir.sanitizeName(fileName);
      final record = Fx200Ir.encodeRecord(wav.samples, wav.sampleRate, name);
      state = state.copyWith(
        busySlot: slot,
        progress: 0,
        message: tr('Loading {0} into CAB {1}...', [
          name,
          slot + Fx200Ir.firstCabModel,
        ]),
        isError: false,
      );
      await fx200UploadIr(
        sync,
        slot,
        record,
        onProgress: (p) => state = state.copyWith(progress: p),
      );
      sync.rememberIrName(slot, name);
      final names = List<String>.of(
        state.names ?? List<String>.filled(Fx200Ir.slotCount, ''),
      )..[slot] = name;
      state = state.copyWith(
        names: names,
        clearBusy: true,
        progress: 1,
        message: tr('Loaded {0} into CAB {1}.', [
          name,
          slot + Fx200Ir.firstCabModel,
        ]),
      );
    } catch (e) {
      state = state.copyWith(
        clearBusy: true,
        message: '$fileName: $e',
        isError: true,
      );
    }
  }
}
