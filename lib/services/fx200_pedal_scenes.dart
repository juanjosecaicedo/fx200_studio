import 'dart:async';
import 'dart:typed_data';

import 'fx200_backup.dart' show Fx200DeviceLink;
import 'fx200_protocol.dart';

/// USB command `0xF5` of FX200 Studio's scenes firmware patch (phase 2,
/// marker version >= 2; `fx200/firmware_patch/scenes/scenes.c`). It does not
/// exist on the stock firmware, which ignores it (opcodes > 0xE5 fall into
/// the dispatcher's default case), but the app only sends it when the
/// `0x84` marker says the patch is installed.
///
/// Every request gets one reply with the same opcode, `body[0]` = the same
/// sub-command:
///
/// | request              | reply                                          |
/// |----------------------|------------------------------------------------|
/// | `[01]`               | `[01, ver, preset, active, nscn, flags, fsmode, chunk, nchunks]` |
/// | `[02, n]`            | `[02, status, active]` (= footswitch n)        |
/// | `[03, n, c]`         | `[03, status, n, c, data(chunk)]`              |
/// | `[04, n, c, data]`   | `[04, status, n, c]`                           |
///
/// Only the active preset's scenes are reachable. Edits stay in the pedal's
/// RAM until the preset is saved (`0xA8`), like any other edit.
class Fx200PedalScenes {
  Fx200PedalScenes._();

  static const int opcode = 0xF5;
  static const int subInfo = 1;
  static const int subSelect = 2;
  static const int subRead = 3;
  static const int subWrite = 4;

  static const int sceneCount = 4;

  /// Scene data = the preset's 10 module blocks of 0xC8 bytes (preset record
  /// from +0x10).
  static const int moduleBlockBytes = 0xC8;
  static const int sceneBytes = 10 * moduleBlockBytes;
  static const int chunkBytes = 250;
  static const int chunkCount = sceneBytes ~/ chunkBytes;

  /// Inside a module block (U102 `apply_i`, e.g. DELAY `0x6568`: enable at
  /// preset `+0x654`, model `+0x655`, first parameter `+0x684`).
  static const int blockEnabled = 4;
  static const int blockModel = 5;
  static const int blockParams = 0x34;

  static Uint8List _packet(List<int> body) =>
      Fx200Protocol.buildHidPacket(payload: <int>[opcode, ...body]);

  static Uint8List infoPacket() => _packet(const <int>[subInfo]);

  static Uint8List selectPacket(int scene) => _packet(<int>[subSelect, scene]);

  static Uint8List readPacket(int scene, int chunk) =>
      _packet(<int>[subRead, scene, chunk]);

  static Uint8List writePacket(int scene, int chunk, List<int> data) {
    if (data.length != chunkBytes) {
      throw ArgumentError('chunk must be $chunkBytes bytes');
    }
    return _packet(<int>[subWrite, scene, chunk, ...data]);
  }

  /// Splits a 2000-byte scene into the write packets.
  static List<Uint8List> writePackets(int scene, Uint8List data) {
    if (data.length != sceneBytes) {
      throw ArgumentError('scene must be $sceneBytes bytes');
    }
    return <Uint8List>[
      for (var c = 0; c < chunkCount; c++)
        writePacket(
          scene,
          c,
          Uint8List.sublistView(data, c * chunkBytes, (c + 1) * chunkBytes),
        ),
    ];
  }
}

/// Reply to [Fx200PedalScenes.subInfo].
class Fx200PedalScenesInfo {
  const Fx200PedalScenesInfo({
    required this.version,
    required this.preset,
    required this.active,
    required this.sceneCount,
    required this.flags,
    required this.fsMode,
  });

  final int version;

  /// Preset (0..199) the scenes belong to.
  final int preset;

  /// Scene being played (0..3).
  final int active;
  final int sceneCount;

  /// bit0: a scene did not fit in the flash record when last saved.
  final int flags;
  final int fsMode;

  static Fx200PedalScenesInfo? fromBody(List<int> body) {
    if (body.length < 9 || body[0] != Fx200PedalScenes.subInfo) return null;
    // Chunk layout must match this app's codec.
    if (body[7] != Fx200PedalScenes.chunkBytes ||
        body[8] != Fx200PedalScenes.chunkCount) {
      return null;
    }
    return Fx200PedalScenesInfo(
      version: body[1],
      preset: body[2],
      active: body[3],
      sceneCount: body[4],
      flags: body[5],
      fsMode: body[6],
    );
  }
}

/// One module of a pedal scene, decoded from its 0xC8-byte block.
class Fx200SceneModule {
  const Fx200SceneModule({
    required this.enabled,
    required this.modelId,
    required this.params,
  });

  final bool enabled;
  final int modelId;
  final List<int> params;

  /// Same content as a module frame of the pedal (`0x91 + slot`).
  Fx200ModuleState toModuleState(int slot) => Fx200ModuleState(
    opcode: 0x91 + slot,
    slotIndex: slot,
    name: Fx200Protocol.moduleNames[slot],
    enabled: enabled,
    modelId: modelId,
    params: params,
  );
}

/// A pedal scene: the raw 2000 bytes (copied back as-is when writing) and a
/// decoded view of its modules.
class Fx200PedalScene {
  Fx200PedalScene(this.data)
    : assert(data.length == Fx200PedalScenes.sceneBytes);

  final Uint8List data;

  /// Module [slot] (0..9) with [paramCount] parameters (u16 LE words).
  Fx200SceneModule module(int slot, int paramCount) {
    final base = slot * Fx200PedalScenes.moduleBlockBytes;
    final b = ByteData.sublistView(data);
    final maxParams =
        (Fx200PedalScenes.moduleBlockBytes - Fx200PedalScenes.blockParams) ~/ 2;
    final n = paramCount.clamp(0, maxParams);
    return Fx200SceneModule(
      enabled: data[base + Fx200PedalScenes.blockEnabled] != 0,
      modelId: data[base + Fx200PedalScenes.blockModel],
      params: <int>[
        for (var i = 0; i < n; i++)
          b.getUint16(
            base + Fx200PedalScenes.blockParams + 2 * i,
            Endian.little,
          ),
      ],
    );
  }

  bool sameAs(Fx200PedalScene other) {
    for (var i = 0; i < data.length; i++) {
      if (data[i] != other.data[i]) return false;
    }
    return true;
  }
}

class Fx200PedalScenesException implements Exception {
  const Fx200PedalScenesException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Request / reply client for [Fx200PedalScenes] over the HID link. One
/// request at a time: each waits for its reply before the next is sent
/// (the pedal answers from a single static buffer).
class Fx200PedalScenesClient {
  Fx200PedalScenesClient(
    this.link, {
    this.timeout = const Duration(milliseconds: 800),
  });

  final Fx200DeviceLink link;
  final Duration timeout;
  Future<void> _queue = Future<void>.value();

  Future<List<int>> _call(Uint8List packet, int sub) {
    final result = _queue.then((_) => _send(packet, sub));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<int>> _send(Uint8List packet, int sub) async {
    if (!link.isConnected) {
      throw const Fx200PedalScenesException('FX200 not connected.');
    }
    final reply = link.frames
        .where(
          (f) =>
              f.opcode == Fx200PedalScenes.opcode &&
              f.body.isNotEmpty &&
              f.body[0] == sub,
        )
        .first
        .timeout(timeout);
    link.sendPacket(packet);
    try {
      return (await reply).body;
    } on TimeoutException {
      throw const Fx200PedalScenesException(
        'The pedal did not answer the scenes command.',
      );
    }
  }

  static void _checkStatus(List<int> body, String what) {
    if (body.length < 2 || body[1] != 0) {
      throw Fx200PedalScenesException('The pedal rejected $what.');
    }
  }

  Future<Fx200PedalScenesInfo> info() async {
    final body = await _call(
      Fx200PedalScenes.infoPacket(),
      Fx200PedalScenes.subInfo,
    );
    final info = Fx200PedalScenesInfo.fromBody(body);
    if (info == null) {
      throw const Fx200PedalScenesException(
        'Unexpected scenes info from the pedal.',
      );
    }
    return info;
  }

  /// Switches the pedal to [scene] (like its footswitch); returns the active
  /// scene.
  Future<int> select(int scene) async {
    final body = await _call(
      Fx200PedalScenes.selectPacket(scene),
      Fx200PedalScenes.subSelect,
    );
    _checkStatus(body, 'scene ${scene + 1}');
    return body.length > 2 ? body[2] : scene;
  }

  Future<Fx200PedalScene> read(int scene) async {
    final data = Uint8List(Fx200PedalScenes.sceneBytes);
    for (var c = 0; c < Fx200PedalScenes.chunkCount; c++) {
      final body = await _call(
        Fx200PedalScenes.readPacket(scene, c),
        Fx200PedalScenes.subRead,
      );
      _checkStatus(body, 'reading scene ${scene + 1}');
      if (body.length < 4 + Fx200PedalScenes.chunkBytes ||
          body[2] != scene ||
          body[3] != c) {
        throw const Fx200PedalScenesException(
          'Unexpected scene data from the pedal.',
        );
      }
      data.setRange(
        c * Fx200PedalScenes.chunkBytes,
        (c + 1) * Fx200PedalScenes.chunkBytes,
        body.sublist(4, 4 + Fx200PedalScenes.chunkBytes),
      );
    }
    return Fx200PedalScene(data);
  }

  /// Replaces [scene] (in the pedal's RAM; Save stores it). Writing the
  /// active scene also changes the sound.
  Future<void> write(int scene, Uint8List data) async {
    final packets = Fx200PedalScenes.writePackets(scene, data);
    for (final p in packets) {
      final body = await _call(p, Fx200PedalScenes.subWrite);
      _checkStatus(body, 'writing scene ${scene + 1}');
    }
  }

  /// Reads the four scenes.
  Future<List<Fx200PedalScene>> readAll() async => <Fx200PedalScene>[
    for (var n = 0; n < Fx200PedalScenes.sceneCount; n++) await read(n),
  ];
}
