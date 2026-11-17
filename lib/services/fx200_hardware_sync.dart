import 'dart:async';

import '../core/fx200_constants.dart';
import '../domain/entities/preset.dart';
import 'fx200_protocol.dart';
import 'usb_transport.dart';

/// Bridges live FX200 USB HID I/O (`EP 0x05 OUT` / `EP 0x84 IN`) with the
/// Clean Architecture editor state.
class Fx200HardwareSync {
  Fx200HardwareSync({Fx200UsbTransport? transport})
    : _transport = transport ?? Fx200UsbTransport();

  final Fx200UsbTransport _transport;
  final Fx200FrameAssembler _assembler = Fx200FrameAssembler();
  final Map<int, Fx200ModuleState> _lastModules = <int, Fx200ModuleState>{};
  final Map<int, DateTime> _lastWriteTime = <int, DateTime>{};
  Fx200HidSession? _session;
  Timer? _pollTimer;

  bool get isConnected => _session?.isOpen ?? false;

  static EffectCategory categoryForSlot(int slotIndex) {
    switch (slotIndex) {
      case 0:
        return EffectCategory.compressor;
      case 1:
        return EffectCategory.drive;
      case 2:
        return EffectCategory.amp;
      case 3:
        return EffectCategory.cab;
      case 4:
        return EffectCategory.gate;
      case 5:
        return EffectCategory.volume;
      case 6:
        return EffectCategory.eq;
      case 7:
        return EffectCategory.modulation;
      case 8:
        return EffectCategory.delay;
      default:
        return EffectCategory.reverb;
    }
  }

  static int slotForCategory(EffectCategory category) {
    switch (category) {
      case EffectCategory.compressor:
        return 0;
      case EffectCategory.drive:
        return 1;
      case EffectCategory.amp:
        return 2;
      case EffectCategory.cab:
        return 3;
      case EffectCategory.gate:
        return 4;
      case EffectCategory.volume:
        return 5;
      case EffectCategory.eq:
        return 6;
      case EffectCategory.modulation:
        return 7;
      case EffectCategory.delay:
        return 8;
      case EffectCategory.reverb:
        return 9;
    }
  }

  ({bool ok, String message}) connect({
    required void Function(Fx200ModuleState module) onModuleReceived,
    required void Function(int index, String name) onPresetNameReceived,
    void Function(int activePatch)? onActivePatchReceived,
    void Function(List<int> order1Based, List<bool> enabledStates)?
        onChainOrderReceived,
  }) {
    if (isConnected) {
      return (ok: true, message: 'FX200 HID already connected.');
    }

    final res = _transport.openHidSession();
    if (res.session == null) {
      return (ok: false, message: res.error ?? 'Failed to open FX200 HID.');
    }

    _session = res.session;
    _assembler.reset();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      final session = _session;
      if (session == null || !session.isOpen) return;
      for (var i = 0; i < 16; i++) {
        final polled = session.pollIn(timeoutMs: 5);
        if (polled.data == null) break;
        final frames = _assembler.feedPacket(polled.data!);
        for (final frame in frames) {
          final mod = Fx200Protocol.decodeModuleFrame(frame.opcode, frame.body);
          if (mod != null) {
            _lastModules[mod.slotIndex] = mod;
            final lastWrite = _lastWriteTime[mod.slotIndex];
            if (lastWrite == null ||
                DateTime.now().difference(lastWrite).inMilliseconds > 150) {
              onModuleReceived(mod);
            }
            continue;
          }
          final dump = Fx200Protocol.decodePresetDumpFrame(
            frame.opcode,
            frame.body,
          );
          if (dump != null && dump.name.isNotEmpty) {
            onPresetNameReceived(dump.index, dump.name);
            continue;
          }
          final saved = Fx200Protocol.decodePresetSaveFrame(
            frame.opcode,
            frame.body,
          );
          if (saved != null && saved.name.isNotEmpty) {
            onPresetNameReceived(saved.index, saved.name);
            continue;
          }
          final chain = Fx200Protocol.decodeChainOrderFrame(
            frame.opcode,
            frame.body,
          );
          if (chain != null && onChainOrderReceived != null) {
            onChainOrderReceived(chain.order1Based, chain.enabledStates);
            continue;
          }
          if (frame.opcode == Fx200Protocol.opCmdBb &&
              frame.body.length >= 2 &&
              onActivePatchReceived != null) {
            final patch = ((frame.body[0] & 0xff) << 8) | (frame.body[1] & 0xff);
            if (patch >= 0 && patch < Fx200Constants.presetPatchCount) {
              onActivePatchReceived(patch);
            }
          }
        }
      }
    });

    return (ok: true, message: 'FX200 LIVE (IF 3)');
  }

  void requestPresetList() {
    final session = _session;
    if (session == null || !session.isOpen) return;
    session.sendRaw(
      Fx200Protocol.buildHidPacket(
        payload: const <int>[Fx200Protocol.opProbe00],
      ),
    );
  }

  void requestPreset(int patchNumber) {
    final session = _session;
    if (session == null || !session.isOpen) return;
    final clamped = patchNumber.clamp(0, Fx200Constants.presetPatchCount - 1);
    session.sendRaw(Fx200Protocol.buildPresetReadPacket(clamped));
  }

  void sendBlockUpdate(EffectBlock block, {bool force = false}) {
    final session = _session;
    if (session == null || !session.isOpen) return;
    final slot = slotForCategory(block.category);
    final now = DateTime.now();
    final prevWrite = _lastWriteTime[slot];
    if (!force &&
        prevWrite != null &&
        now.difference(prevWrite).inMilliseconds < 40) {
      return;
    }
    _lastWriteTime[slot] = now;

    final prevMod = _lastModules[slot];
    final opcode = 0x91 + slot;
    final expectedLen = prevMod?.params.length ?? block.parameters.length;
    final params = <int>[];
    for (var i = 0; i < expectedLen; i++) {
      if (i < block.parameters.length) {
        final p = block.parameters[i];
        params.add(p.value.round().clamp(p.min.round(), p.max.round()));
      } else {
        params.add(prevMod?.params[i] ?? 0);
      }
    }

    final modelIdx = block.availableModels.indexOf(block.modelName);
    final resolvedModelId =
        modelIdx >= 0 ? modelIdx + 1 : (prevMod?.modelId ?? 1);

    final state = Fx200ModuleState(
      opcode: opcode,
      slotIndex: slot,
      name: Fx200Protocol.moduleNames[slot],
      enabled: block.enabled,
      modelId: resolvedModelId,
      params: params,
    );
    _lastModules[slot] = state;
    session.sendRaw(Fx200Protocol.encodeModuleFrame(state));
  }

  void sendPresetSave(int patchNumber, String name) {
    final session = _session;
    if (session == null || !session.isOpen) return;
    session.sendRaw(Fx200Protocol.buildPresetSavePacket(patchNumber, name));
  }

  void sendChainOrder(List<EffectBlock> blocks) {
    final session = _session;
    if (session == null || !session.isOpen) return;
    final ordered = List<EffectBlock>.from(blocks)
      ..sort((a, b) {
        final laneCmp = a.laneIndex.compareTo(b.laneIndex);
        return laneCmp != 0 ? laneCmp : a.slotIndex.compareTo(b.slotIndex);
      });
    final order1Based = <int>[];
    final seen = <int>{};
    final enabledBySlot = List<bool>.filled(10, true);
    for (final b in ordered) {
      final slot = slotForCategory(b.category);
      enabledBySlot[slot] = b.enabled;
      final id1Based = slot + 1;
      if (seen.add(id1Based)) {
        order1Based.add(id1Based);
      }
    }
    for (var id = 1; id <= 10; id++) {
      if (seen.add(id)) {
        order1Based.add(id);
      }
    }
    session.sendRaw(
      Fx200Protocol.buildChainOrderPacket(order1Based, enabledBySlot),
    );
  }

  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _session?.close();
    _session = null;
  }
}
