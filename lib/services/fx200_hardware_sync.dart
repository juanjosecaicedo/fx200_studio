import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../core/fx200_constants.dart';
import '../domain/entities/preset.dart';
import 'fx200_protocol.dart';
import 'usb_transport.dart';

/// Bridges live FX200 USB HID I/O (`EP 0x05 OUT` / `EP 0x84 IN`) with the
/// Clean Architecture editor state using a dedicated background Isolate so
/// high-rate `0xA5` bursts never drop USB packets.
class Fx200HardwareSync {
  Fx200HardwareSync();

  final Map<int, Fx200ModuleState> _lastModules = <int, Fx200ModuleState>{};
  final Map<int, DateTime> _lastWriteTime = <int, DateTime>{};

  Isolate? _usbIsolate;
  ReceivePort? _rxPort;
  SendPort? _txPort;
  bool _connected = false;

  bool get isConnected => _connected;

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
        return EffectCategory.volume;
      case 5:
        return EffectCategory.gate;
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
      case EffectCategory.volume:
        return 4;
      case EffectCategory.gate:
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

  Future<({bool ok, String message})> connect({
    required void Function(Fx200ModuleState module) onModuleReceived,
    required void Function(Map<int, String> presetNames) onPresetNamesReceived,
    void Function(int activePatch)? onActivePatchReceived,
    void Function(List<int> order1Based, List<bool> enabledStates)?
        onChainOrderReceived,
    void Function(double outputLevelDb)? onOutputLevelReceived,
    void Function()? onPresetSyncComplete,
  }) async {
    if (_connected) {
      return (ok: true, message: 'FX200 LIVE (IF 3)');
    }

    final rxPort = ReceivePort();
    _rxPort = rxPort;
    final initCompleter = Completer<({bool ok, String message})>();
    Timer? syncIdleTimer;

    rxPort.listen((dynamic message) {
      if (message is Map<String, Object?>) {
        final type = message['type'] as String?;
        if (type == 'ready') {
          final ok = message['ok'] as bool? ?? false;
          final msg = message['message'] as String? ?? 'USB ERROR';
          if (ok) {
            _txPort = message['txPort'] as SendPort?;
            _connected = true;
          } else {
            disconnect();
          }
          if (!initCompleter.isCompleted) {
            initCompleter.complete((ok: ok, message: msg));
          }
          return;
        }
        if (type == 'frame') {
          final opcode = message['opcode'] as int;
          final body = message['body'] as Uint8List;
          _handleFrame(
            opcode: opcode,
            body: body,
            onModuleReceived: onModuleReceived,
            onPresetNamesReceived: onPresetNamesReceived,
            onActivePatchReceived: onActivePatchReceived,
            onChainOrderReceived: onChainOrderReceived,
            onOutputLevelReceived: onOutputLevelReceived,
            onPresetDumpFrame: () {
              syncIdleTimer?.cancel();
              syncIdleTimer = Timer(const Duration(milliseconds: 600), () {
                onPresetSyncComplete?.call();
              });
            },
          );
          return;
        }
        if (type == 'names') {
          final names = (message['names'] as Map).cast<int, String>();
          if (names.isNotEmpty) {
            onPresetNamesReceived(names);
            syncIdleTimer?.cancel();
            syncIdleTimer = Timer(const Duration(milliseconds: 600), () {
              onPresetSyncComplete?.call();
            });
          }
          return;
        }
      }
    });

    _usbIsolate = await Isolate.spawn(_usbWorkerEntry, rxPort.sendPort);
    return initCompleter.future;
  }

  void _handleFrame({
    required int opcode,
    required Uint8List body,
    required void Function(Fx200ModuleState module) onModuleReceived,
    required void Function(Map<int, String> presetNames) onPresetNamesReceived,
    void Function(int activePatch)? onActivePatchReceived,
    void Function(List<int> order1Based, List<bool> enabledStates)?
        onChainOrderReceived,
    void Function(double outputLevelDb)? onOutputLevelReceived,
    void Function()? onPresetDumpFrame,
  }) {
    final mod = Fx200Protocol.decodeModuleFrame(opcode, body);
    if (mod != null) {
      _lastModules[mod.slotIndex] = mod;
      final lastWrite = _lastWriteTime[mod.slotIndex];
      if (lastWrite == null ||
          DateTime.now().difference(lastWrite).inMilliseconds > 150) {
        onModuleReceived(mod);
      }
      return;
    }

    final saved = Fx200Protocol.decodePresetSaveFrame(opcode, body);
    if (saved != null && saved.name.isNotEmpty) {
      onPresetNamesReceived(<int, String>{saved.index: saved.name});
      return;
    }

    final dump = Fx200Protocol.decodePresetDumpFrame(opcode, body);
    if (dump != null && dump.name.isNotEmpty) {
      onPresetNamesReceived(<int, String>{dump.index: dump.name});
      onPresetDumpFrame?.call();
      return;
    }

    final chain = Fx200Protocol.decodeChainOrderFrame(opcode, body);
    if (chain != null && onChainOrderReceived != null) {
      onChainOrderReceived(chain.order1Based, chain.enabledStates);
      return;
    }

    final outDb = Fx200Protocol.decodeOutputLevelFrame(opcode, body);
    if (outDb != null && onOutputLevelReceived != null) {
      onOutputLevelReceived(outDb);
      return;
    }

    if (opcode == Fx200Protocol.opCmdBb &&
        body.length >= 2 &&
        onActivePatchReceived != null) {
      final patch = ((body[0] & 0xff) << 8) | (body[1] & 0xff);
      if (patch >= 0 && patch < Fx200Constants.presetPatchCount) {
        onActivePatchReceived(patch);
      }
    }
  }

  void requestPresetList() {
    if (!_connected) return;
    _txPort?.send(
      Fx200Protocol.buildHidPacket(
        payload: const <int>[Fx200Protocol.opCmdE0],
      ),
    );
  }

  void requestPreset(int patchNumber) {
    if (!_connected) return;
    final clamped = patchNumber.clamp(0, Fx200Constants.presetPatchCount - 1);
    _txPort?.send(Fx200Protocol.buildPresetReadPacket(clamped));
  }

  void sendBlockUpdate(EffectBlock block, {bool force = false}) {
    if (!_connected) return;
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
    _txPort?.send(Fx200Protocol.encodeModuleFrame(state));
  }

  void sendPresetSave(int patchNumber, String name) {
    if (!_connected) return;
    _txPort?.send(Fx200Protocol.buildPresetSavePacket(patchNumber, name));
  }

  void sendOutputLevelDb(double db) {
    if (!_connected) return;
    _txPort?.send(Fx200Protocol.buildOutputLevelPacket(db));
  }

  void sendChainOrder(List<EffectBlock> blocks) {
    if (!_connected) return;
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
    _txPort?.send(
      Fx200Protocol.buildChainOrderPacket(order1Based, enabledBySlot),
    );
  }

  void disconnect() {
    _connected = false;
    _txPort?.send(null);
    _txPort = null;
    _rxPort?.close();
    _rxPort = null;
    _usbIsolate?.kill(priority: Isolate.immediate);
    _usbIsolate = null;
  }
}

Future<void> _usbWorkerEntry(SendPort mainPort) async {
  final transport = Fx200UsbTransport();
  final res = transport.openHidSession();
  final session = res.session;
  if (session == null) {
    mainPort.send(<String, Object?>{
      'type': 'ready',
      'ok': false,
      'message': res.error ?? 'Failed to open FX200 HID.',
    });
    return;
  }

  final cmdPort = ReceivePort();
  var running = true;
  final outQueue = <Uint8List>[];

  cmdPort.listen((dynamic msg) {
    if (msg == null) {
      running = false;
    } else if (msg is Uint8List) {
      outQueue.add(msg);
    }
  });

  mainPort.send(<String, Object?>{
    'type': 'ready',
    'ok': true,
    'message': 'FX200 LIVE (IF 3)',
    'txPort': cmdPort.sendPort,
  });

  final assembler = Fx200FrameAssembler();
  final pendingNames = <int, String>{};
  var lastFlush = DateTime.now();
  var burstCount = 0;

  while (running && session.isOpen) {
    while (outQueue.isNotEmpty) {
      final pkt = outQueue.removeAt(0);
      session.sendRaw(pkt);
    }

    final polled = session.pollIn(timeoutMs: 8);
    if (polled.data != null) {
      burstCount++;
      final frames = assembler.feedPacket(polled.data!);
      for (final frame in frames) {
        final dump = Fx200Protocol.decodePresetDumpFrame(
          frame.opcode,
          frame.body,
        );
        if (dump != null && dump.name.isNotEmpty) {
          pendingNames[dump.index] = dump.name;
          continue;
        }
        mainPort.send(<String, Object?>{
          'type': 'frame',
          'opcode': frame.opcode,
          'body': frame.body,
        });
      }
      if (burstCount >= 24) {
        burstCount = 0;
        await Future<void>.delayed(Duration.zero);
      }
    } else {
      burstCount = 0;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    if (pendingNames.isNotEmpty &&
        (pendingNames.length >= 10 ||
            DateTime.now().difference(lastFlush).inMilliseconds >= 80)) {
      mainPort.send(<String, Object?>{
        'type': 'names',
        'names': Map<int, String>.from(pendingNames),
      });
      pendingNames.clear();
      lastFlush = DateTime.now();
    }
  }

  cmdPort.close();
  session.close();
}
