import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../core/fx200_constants.dart';
import '../domain/entities/preset.dart';
import '../core/l10n/l10n.dart';
import 'fx200_backup.dart';
import 'fx200_ir.dart';
import 'fx200_firmware_features.dart';
import 'fx200_opcodes.dart';
import 'fx200_protocol.dart';
import 'usb_transport.dart';

/// Bridges live FX200 USB HID I/O (`EP 0x05 OUT` / `EP 0x84 IN`) with the
/// Clean Architecture editor state using a dedicated background Isolate so
/// high-rate `0xA5` bursts never drop USB packets.
class Fx200HardwareSync implements Fx200DeviceLink {
  Fx200HardwareSync();

  final Map<int, Fx200ModuleState> _lastModules = <int, Fx200ModuleState>{};
  final Map<int, DateTime> _lastWriteTime = <int, DateTime>{};
  int _lastFsMode = 0x02;
  int _lastCtrlMask = 0x0002;
  int _lastBpm = 120;

  /// Raw `0xA5`/`0x86` dump chunks: preset index → chunk index → 512 bytes.
  final Map<int, Map<int, Uint8List>> _presetDumps =
      <int, Map<int, Uint8List>>{};

  /// Presets written since their raw record was received (`0xA8` / `0x83`),
  /// so the cached record no longer matches the pedal.
  final Set<int> _staleRecords = <int>{};
  final StreamController<({int opcode, Uint8List body})> _frameController =
      StreamController<({int opcode, Uint8List body})>.broadcast();
  Fx200GlobalSettings? _lastGlobalSettings;
  Fx200DrumSettings? _lastDrum;
  List<String>? _irNames;
  Uint8List? _irNamesBody;

  /// `0xA0` body (order + flags) per preset: seeded from the raw dump,
  /// updated by live `0xA0` frames and by every chain write.
  final Map<int, Uint8List> _chainBlocks = <int, Uint8List>{};
  int? _activePatch;
  DateTime? _lastGlobalSettingsAt;
  DateTime? _lastDumpChunkAt;

  /// `0xE0` dump state. The dump takes ~27 s and ends with
  /// `91..9A, AD, A1, A3, AE, A4, 82, BB, A6, 84, 85, 86×8` (measured on the
  /// pedal). While it runs the pedal queues `0xA6` answers behind hundreds of
  /// `0xA5` packets, so preset operations must wait for it to finish.
  Completer<void>? _dumpDone;
  Timer? _dumpTailTimer;
  Timer? _dumpIdleTimer;
  Timer? _dumpGuardTimer;
  void Function()? _onDumpComplete;

  static const Duration _dumpTail = Duration(milliseconds: 600);
  static const Duration _dumpIdle = Duration(seconds: 3);
  static const Duration _dumpGuard = Duration(seconds: 60);

  /// True while an `0xE0` preset dump is still streaming from the pedal.
  bool get isDumping => _dumpDone != null && !_dumpDone!.isCompleted;

  void _beginDump() {
    if (!isDumping) _dumpDone = Completer<void>();
    _dumpTailTimer?.cancel();
    _dumpIdleTimer?.cancel();
    _dumpGuardTimer?.cancel();
    _dumpGuardTimer = Timer(_dumpGuard, _finishDump);
  }

  void _finishDump() {
    _dumpTailTimer?.cancel();
    _dumpIdleTimer?.cancel();
    _dumpGuardTimer?.cancel();
    final done = _dumpDone;
    if (done != null && !done.isCompleted) {
      done.complete();
      _onDumpComplete?.call();
    }
  }

  /// Waits until the pedal can answer preset requests (no dump running).
  @override
  Future<void> waitUntilReady() async {
    final done = _dumpDone;
    if (done == null || done.isCompleted) return;
    await done.future.timeout(_dumpGuard, onTimeout: () {});
  }

  /// While true, live module/chain/tempo/level/patch frames are not pushed to
  /// the editor (used while a backup or restore sweeps through presets).
  bool suppressEditorUpdates = false;

  Isolate? _usbIsolate;
  ReceivePort? _rxPort;
  SendPort? _txPort;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<({int opcode, Uint8List body})> get frames => _frameController.stream;

  /// Names of the 50 user IR slots (CAB 31-80) from the last `0x85`;
  /// empty string = unused slot. Null until the pedal sends them.
  List<String>? get irNames => _irNames;

  /// Raw `0x85` body (50 × 15-byte names) as the pedal last sent it,
  /// updated by IR uploads; needed to write an official `.bfl`.
  Uint8List? get irNamesBody => _irNamesBody;

  /// Records a name written by an IR upload ('' = slot cleared).
  void rememberIrName(int slot, String name) {
    final names = _irNames ?? List<String>.filled(Fx200Ir.slotCount, '');
    _irNames = List<String>.of(names)..[slot] = name;
    final body = _irNamesBody ?? Uint8List(Fx200Ir.slotCount * 15);
    final entry = name.isEmpty ? 'EMPTY' : name;
    body.fillRange(slot * 15, slot * 15 + 15, 0);
    final units = entry.codeUnits.take(15).toList();
    body.setRange(slot * 15, slot * 15 + units.length, units);
    _irNamesBody = body;
  }

  /// Firmware capabilities from the `0x84` handshake; null until the pedal
  /// answers [requestDeviceInfo] (or sends its spontaneous `0x84`).
  Fx200FirmwareFeatures? get firmwareFeatures => _firmwareFeatures;
  Fx200FirmwareFeatures? _firmwareFeatures;
  void Function(Fx200FirmwareFeatures features)? _onFirmwareFeatures;

  /// Last `0xAD` drum machine state received from (or sent to) the pedal.
  Fx200DrumSettings? get lastDrum => _lastDrum;

  /// Last `0xA1` global SYSTEM block received from (or sent to) the pedal.
  Fx200GlobalSettings? get lastGlobalSettings => _lastGlobalSettings;

  /// Footswitch assignment of the active preset (last `0xA4`).
  Fx200FootswitchConfig get lastFootswitch => Fx200FootswitchConfig(
    mode: _lastFsMode,
    ctrlMask: _lastCtrlMask,
    bpm: _lastBpm,
  );

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
    void Function(double bpm)? onBpmReceived,
    void Function()? onPresetSyncComplete,
    void Function(Fx200FirmwareFeatures features)? onFirmwareFeatures,
  }) async {
    _onFirmwareFeatures = onFirmwareFeatures;
    if (_connected) {
      return (ok: true, message: 'FX200 LIVE (IF 3)');
    }

    final rxPort = ReceivePort();
    _rxPort = rxPort;
    final initCompleter = Completer<({bool ok, String message})>();
    _onDumpComplete = onPresetSyncComplete;

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
          _frameController.add((opcode: opcode, body: body));
          _handleFrame(
            opcode: opcode,
            body: body,
            onModuleReceived: onModuleReceived,
            onPresetNamesReceived: onPresetNamesReceived,
            onActivePatchReceived: onActivePatchReceived,
            onChainOrderReceived: onChainOrderReceived,
            onBpmReceived: onBpmReceived,
            onPresetDumpFrame: () {},
          );
          return;
        }
        if (type == 'names') {
          final names = (message['names'] as Map).cast<int, String>();
          if (names.isNotEmpty) {
            onPresetNamesReceived(names);
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
    void Function(double bpm)? onBpmReceived,
    void Function()? onPresetDumpFrame,
  }) {
    final chunk = Fx200Protocol.decodePresetDumpChunk(opcode, body);
    if (chunk != null) {
      (_presetDumps[chunk.index] ??= <int, Uint8List>{})[chunk.chunk] =
          chunk.data;
      if (chunk.chunk == Fx200Protocol.presetDumpChunkCount - 1) {
        _staleRecords.remove(chunk.index);
      }
      if (chunk.chunk == 4) {
        final chain = Fx200Protocol.chainBlockFromPresetDump(
          Uint8List(Fx200Protocol.presetDumpChunkBytes * 4) + chunk.data,
        );
        if (chain != null) _chainBlocks[chunk.index] = chain;
      }
      _lastDumpChunkAt = DateTime.now();
      if (isDumping) {
        // Fallback in case the closing frames are lost.
        _dumpIdleTimer?.cancel();
        _dumpIdleTimer = Timer(_dumpIdle, _finishDump);
      }
      onPresetDumpFrame?.call();
      return;
    }

    // 0xA1 and 0x85 close the dump; the 0x86 tail follows within ~250 ms.
    if (isDumping &&
        (opcode == Fx200Protocol.opCmdA1 || opcode == 0x85) &&
        (_dumpTailTimer == null || !_dumpTailTimer!.isActive)) {
      _dumpTailTimer = Timer(_dumpTail, _finishDump);
    }

    if (opcode == Fx200Protocol.opPresetRead && body.isNotEmpty) {
      _activePatch = body[0] & 0xff;
    }

    final features = Fx200FirmwareFeatures.fromFrame(opcode, body);
    if (features != null) {
      _firmwareFeatures = features;
      _onFirmwareFeatures?.call(features);
    }

    if (opcode == Fx200Ir.opNames) {
      _irNames = Fx200Ir.decodeNames(body);
      _irNamesBody = Uint8List.fromList(body);
    }

    if (opcode == Fx200Protocol.opCmdAd) {
      final drum = Fx200DrumSettings.decode(body);
      if (drum != null) _lastDrum = drum;
      return;
    }

    final global = Fx200Protocol.decodeGlobalSettingsFrame(opcode, body);
    if (global != null) {
      _lastGlobalSettings = global;
      _lastGlobalSettingsAt = DateTime.now();
      return;
    }

    final tap = Fx200Protocol.decodeTapTempoFrame(opcode, body);
    if (tap != null) {
      _lastFsMode = tap.fsMode;
      _lastCtrlMask = tap.ctrlMask;
      _lastBpm = tap.bpm;
      if (!suppressEditorUpdates) onBpmReceived?.call(tap.bpm.toDouble());
      return;
    }

    if (suppressEditorUpdates) {
      final saved = Fx200Protocol.decodePresetSaveFrame(opcode, body);
      if (saved != null && saved.name.isNotEmpty) {
        onPresetNamesReceived(<int, String>{saved.index: saved.name});
      }
      return;
    }

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

    final chain = Fx200Protocol.decodeChainOrderFrame(opcode, body);
    if (chain != null && _activePatch != null && body.length >= 20) {
      _chainBlocks[_activePatch!] = Uint8List.fromList(body.sublist(0, 20));
    }
    if (chain != null && onChainOrderReceived != null) {
      onChainOrderReceived(chain.order1Based, chain.enabledStates);
      return;
    }

    if (opcode == Fx200Protocol.opPresetRead &&
        body.isNotEmpty &&
        onActivePatchReceived != null) {
      final patch = body[0] & 0xff;
      if (patch >= 0 && patch < Fx200Constants.presetPatchCount) {
        onActivePatchReceived(patch);
      }
    }
  }

  /// Asks for the device string (`0x84`, answered with `0x10`): tells a
  /// stock firmware from the custom scenes firmware. Read-only on the pedal
  /// (U102 handler 0x4528 only answers).
  void requestDeviceInfo() {
    if (!_connected) return;
    _tx(Fx200Protocol.buildHandshakePacket());
  }

  void requestPresetList() {
    if (!_connected) return;
    _beginDump();
    _tx(
      Fx200Protocol.buildHidPacket(payload: const <int>[Fx200Protocol.opCmdE0]),
    );
  }

  void requestPreset(int patchNumber) {
    if (!_connected) return;
    final clamped = patchNumber.clamp(0, Fx200Constants.presetPatchCount - 1);
    _activePatch = clamped;
    _tx(Fx200Protocol.buildPresetReadPacket(clamped));
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
    final resolvedModelId = modelIdx >= 0
        ? modelIdx + 1
        : (prevMod?.modelId ?? 1);

    final state = Fx200ModuleState(
      opcode: opcode,
      slotIndex: slot,
      name: Fx200Protocol.moduleNames[slot],
      enabled: block.enabled,
      modelId: resolvedModelId,
      params: params,
    );
    _lastModules[slot] = state;
    _tx(Fx200Protocol.encodeModuleFrame(state));
  }

  void sendPresetSave(int patchNumber, String name) {
    if (!_connected) return;
    _staleRecords.add(patchNumber);
    _tx(Fx200Protocol.buildPresetSavePacket(patchNumber, name));
  }

  /// Writes the drum machine / metronome state (`0xAD`, global, applied
  /// immediately).
  void sendDrum(Fx200DrumSettings drum) {
    if (!_connected) return;
    _lastDrum = drum;
    _tx(Fx200Protocol.buildDrumPacket(drum));
  }

  /// Sends one expression-pedal assignment (`0xA3`) for the active preset.
  /// Like the footswitch, it only persists once the preset is saved.
  void sendExpAssignment(Fx200ExpFrame frame) {
    if (!_connected) return;
    _tx(Fx200Protocol.buildExpPacket(frame));
  }

  /// Sends the VOLUME-mode heel/toe range of PEDAL 1 (`0xAE`).
  void sendVolumePedalRange(Fx200VolumePedalRange range) {
    if (!_connected) return;
    _tx(Fx200Protocol.buildVolumePedalRangePacket(range));
  }

  void sendTapTempoBpm(double bpm) {
    if (!_connected) return;
    _lastBpm = bpm.round().clamp(40, 260);
    _tx(
      Fx200Protocol.buildTapTempoPacket(
        bpm: bpm.round(),
        fsMode: _lastFsMode,
        ctrlMask: _lastCtrlMask,
      ),
    );
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
    final packet = Fx200Protocol.buildChainOrderPacket(
      order1Based,
      enabledBySlot,
    );
    if (_activePatch != null) {
      // packet = [len, aa, 55, lenLo, lenHi, 0xA0, ...20 body bytes, crc]
      _chainBlocks[_activePatch!] = Uint8List.fromList(packet.sublist(6, 26));
    }
    _tx(packet);
  }

  /// Writes the whole global SYSTEM block (`0xA1`); applied immediately.
  void sendGlobalSettings(Fx200GlobalSettings settings) {
    if (!_connected) return;
    _lastGlobalSettings = settings;
    _tx(Fx200Protocol.buildGlobalSettingsPacket(settings));
  }

  /// Sends the footswitch assignment (`0xA4`) for the active preset. It is
  /// only persisted once the preset is saved (`0xA8`).
  void sendFootswitch(Fx200FootswitchConfig config) {
    if (!_connected) return;
    _lastFsMode = config.mode;
    _lastCtrlMask = config.ctrlMask;
    _lastBpm = config.bpm;
    _tx(Fx200Protocol.buildFootswitchPacket(config));
  }

  @override
  void sendPacket(Uint8List packet) {
    if (!_connected) return;
    if (packet.length > 6 && packet[5] == Fx200Protocol.opPresetRead) {
      _activePatch = packet[6];
    }
    if (packet.length > 6 && packet[5] == Fx200Protocol.opPresetSave) {
      _staleRecords.add(packet[6]);
    }
    if (packet.length > 8 && packet[5] == Fx200Protocol.opCmd83) {
      _staleRecords.add(packet[7] << 8 | packet[8]);
    }
    _tx(packet);
  }

  @override
  Uint8List? chainBlockFor(int index) => _chainBlocks[index];

  @override
  void rememberChainBlock(int index, Uint8List chain) {
    _chainBlocks[index] = Uint8List.fromList(chain);
  }

  /// Up-to-date 4096-byte record of preset [index], or null if it was never
  /// received complete or the preset was written since.
  Uint8List? presetRecord(int index) {
    if (_staleRecords.contains(index)) return null;
    final chunks = _presetDumps[index];
    if (chunks == null || chunks.length < Fx200Protocol.presetDumpChunkCount) {
      return null;
    }
    final record = BytesBuilder(copy: false);
    for (var c = 0; c < Fx200Protocol.presetDumpChunkCount; c++) {
      final data = chunks[c];
      if (data == null) return null;
      record.add(data);
    }
    return record.toBytes();
  }

  /// Presets whose record is missing or stale.
  List<int> get incompletePresets => <int>[
    for (var i = 0; i < Fx200Constants.presetPatchCount; i++)
      if (presetRecord(i) == null) i,
  ];

  /// Human-readable list of the missing dump chunks (for error messages).
  String describeMissingRecords({int max = 6}) {
    final parts = <String>[];
    for (final i in incompletePresets.take(max)) {
      final have = _presetDumps[i]?.keys.toSet() ?? <int>{};
      final missing = <int>[
        for (var c = 0; c < Fx200Protocol.presetDumpChunkCount; c++)
          if (!have.contains(c)) c,
      ];
      parts.add(
        '${i.toString().padLeft(3, '0')}'
        '${_staleRecords.contains(i) ? ' (modified)' : ''}'
        ' chunks ${missing.join(',')}',
      );
    }
    final more = incompletePresets.length - parts.length;
    return parts.join('; ') + (more > 0 ? ' (+$more)' : '');
  }

  /// Re-reads the preset dump until every record is complete (up to
  /// [attempts] times), merging what each dump delivered.
  Future<void> ensureCompleteRecords({int attempts = 3}) async {
    for (var k = 0; k < attempts && incompletePresets.isNotEmpty; k++) {
      await readFullDump();
    }
    if (incompletePresets.isNotEmpty) {
      throw StateError(
        tr(
          'Some presets arrived incomplete from the FX200 after {0} reads (USB packets lost): {1}.',
          [attempts, describeMissingRecords()],
        ),
      );
    }
  }

  /// Complete 4096-byte records captured so far (index → bytes).
  Map<int, Uint8List> get completePresetDumps {
    final out = <int, Uint8List>{};
    _presetDumps.forEach((index, chunks) {
      if (chunks.length < Fx200Protocol.presetDumpChunkCount) return;
      final record = BytesBuilder(copy: false);
      for (var c = 0; c < Fx200Protocol.presetDumpChunkCount; c++) {
        record.add(chunks[c]!);
      }
      out[index] = record.toBytes();
    });
    return out;
  }

  @override
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump({
    Duration firstChunkTimeout = const Duration(seconds: 6),
  }) async {
    if (!_connected) {
      throw StateError('FX200 is not connected.');
    }
    await waitUntilReady();
    final requestedAt = DateTime.now();
    // Keep chunks already received intact (each one is simply replaced when
    // it arrives again), so repeated dumps fill the gaps of lost USB
    // packets. Only presets written since are discarded.
    for (final i in _staleRecords) {
      _presetDumps.remove(i);
    }
    _lastDumpChunkAt = null;
    requestPresetList();

    // Make sure the pedal actually started dumping.
    while (_connected && _lastDumpChunkAt == null) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (DateTime.now().difference(requestedAt) > firstChunkTimeout) {
        _finishDump();
        throw StateError('FX200 did not answer the preset dump (0xE0).');
      }
    }
    await waitUntilReady();
    final gotGlobal =
        _lastGlobalSettingsAt != null &&
        _lastGlobalSettingsAt!.isAfter(requestedAt);
    return (
      dumps: completePresetDumps,
      global: gotGlobal ? _lastGlobalSettings : null,
    );
  }

  /// Every packet to the pedal goes through here: [fx200CheckSendable]
  /// refuses commands that are undocumented, unknown or forbidden.
  void _tx(Uint8List packet) {
    if (packet.length > 5) {
      fx200CheckSendable(
        packet[5],
        customFirmware: _firmwareFeatures?.hasPedalSceneCommand ?? false,
      );
    }
    _txPort?.send(packet);
  }

  void _txPortClose() => _txPort?.send(null);

  void disconnect() {
    _connected = false;
    _firmwareFeatures = null;
    _finishDump();
    _txPortClose();
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

  while (running && session.isOpen) {
    while (outQueue.isNotEmpty) {
      final pkt = outQueue.removeAt(0);
      session.sendRaw(pkt);
    }

    var gotPacket = false;
    while (running && session.isOpen) {
      final polled = session.pollIn(timeoutMs: 12);
      final raw = polled.data;
      if (raw == null) break;
      gotPacket = true;

      final fastHeader = Fx200Protocol.decodePresetDumpPacketHeader(raw);
      if (fastHeader != null) {
        pendingNames[fastHeader.index] = fastHeader.name;
      }

      final frames = assembler.feedPacket(raw);
      for (final frame in frames) {
        final dump = Fx200Protocol.decodePresetDumpFrame(
          frame.opcode,
          frame.body,
        );
        if (dump != null && dump.name.isNotEmpty) {
          pendingNames[dump.index] = dump.name;
        }
        mainPort.send(<String, Object?>{
          'type': 'frame',
          'opcode': frame.opcode,
          'body': frame.body,
        });
      }

      if (pendingNames.length >= 20 &&
          DateTime.now().difference(lastFlush).inMilliseconds >= 60) {
        mainPort.send(<String, Object?>{
          'type': 'names',
          'names': Map<int, String>.from(pendingNames),
        });
        pendingNames.clear();
        lastFlush = DateTime.now();
      }
    }

    if (pendingNames.isNotEmpty) {
      mainPort.send(<String, Object?>{
        'type': 'names',
        'names': Map<int, String>.from(pendingNames),
      });
      pendingNames.clear();
      lastFlush = DateTime.now();
    }

    if (!gotPacket) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    } else {
      await Future<void>.delayed(Duration.zero);
    }
  }

  cmdPort.close();
  session.close();
}
