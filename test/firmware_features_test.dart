import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_firmware_features.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

List<int> _deviceString({bool marker = false, int version = 1}) => <int>[
  ...'FX200'.codeUnits,
  0,
  if (marker) ...<int>[0x53, 0x43, 0x4E, version] else ...<int>[0, 0, 0, 0],
  0, 0, 0, 0, 0, 0, //
];

void main() {
  test('stock 0x84 from the pedal (import-IRs.pcapng): no scenes', () {
    // aa 55 11 00 84 | 46 58 32 30 30 00 x11 | crc 62 be
    final f = Fx200FirmwareFeatures.fromFrame(0x84, _deviceString());
    expect(f, isNotNull);
    expect(f!.deviceName, 'FX200');
    expect(f.hasPedalScenes, isFalse);
  });

  test('0x10 answer of the scenes firmware carries the marker', () {
    final f = Fx200FirmwareFeatures.fromFrame(0x10, <int>[
      0x84,
      ..._deviceString(marker: true, version: 3),
    ]);
    expect(f!.deviceName, 'FX200');
    expect(f.hasPedalScenes, isTrue);
    expect(f.scenesPatchVersion, 3);
  });

  test('other frames and malformed bodies are ignored', () {
    expect(Fx200FirmwareFeatures.fromFrame(0xa1, _deviceString()), isNull);
    expect(Fx200FirmwareFeatures.fromFrame(0x10, _deviceString()), isNull);
    expect(Fx200FirmwareFeatures.fromFrame(0x84, <int>[0x46, 0x58]), isNull);
    expect(
      Fx200FirmwareFeatures.fromFrame(0x84, <int>[
        ...'FX200'.codeUnits,
        0,
        0x53,
        0x43,
        0x4E,
        0,
        ...List.filled(6, 0),
      ])!.hasPedalScenes,
      isFalse,
      reason: 'version 0 is not a valid marker',
    );
  });

  test('handshake request matches FX200.exe (CRC F6 B7)', () {
    final p = Fx200Protocol.buildHandshakePacket();
    final n = p[0];
    expect(p.sublist(1, n + 1), <int>[
      0xaa,
      0x55,
      0x03,
      0x00,
      0x84,
      0x00,
      0x00,
      0xf6,
      0xb7,
    ]);
  });

  test('FS MODE SCENE (3) only with the custom firmware', () {
    final s = Fx200GlobalSettings.fromBody(List<int>.filled(46, 0));
    expect(s.withFsMode(3).fsMode, Fx200GlobalSettings.fsModeDual);
    expect(
      s.withFsMode(3, allowScene: true).fsMode,
      Fx200GlobalSettings.fsModeScene,
    );
    expect(s.withFsMode(9, allowScene: true).fsMode, 3);
  });
}
