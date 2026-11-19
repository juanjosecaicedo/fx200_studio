import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

void main() {
  test('builds and verifies FX200 USB frame with CRC-16/CCITT', () {
    final frame = Fx200Protocol.buildFrame(
      header0: 0xaa,
      header1: 0x55,
      payload: <int>[0x01, 0x02, 0x03, 0x04],
    );

    expect(frame.length, 10);
    expect(frame[2], 4);
    expect(frame[3], 0);
    expect(Fx200Protocol.verifyFrame(frame), isTrue);

    // Flipping a payload byte invalidates the CRC.
    frame[5] ^= 0xff;
    expect(Fx200Protocol.verifyFrame(frame), isFalse);
  });

  test('splits frames into 64-byte USB interrupt chunks', () {
    final frame = Fx200Protocol.buildFrame(
      header0: 0xaa,
      header1: 0x55,
      payload: List<int>.filled(70, 0x2a),
    );

    final chunks = Fx200Protocol.splitInterruptChunks(frame);
    expect(chunks.length, 2);
    expect(chunks[0].length, 64);
    expect(chunks[1].length, 64);
  });

  test('matches exact 0x84 handshake frame from FX200.exe sub_402520', () {
    final frame = Fx200Protocol.buildFrame(
      header0: 0xaa,
      header1: 0x55,
      payload: <int>[Fx200Protocol.opHandshake, 0x00, 0x00],
    );

    expect(
      frame,
      equals(<int>[0xaa, 0x55, 0x03, 0x00, 0x84, 0x00, 0x00, 0xf6, 0xb7]),
    );
  });

  test('matches exact wire HID packets from captura.pcapng', () {
    final p00 = Fx200Protocol.buildHidPacket(
      payload: <int>[Fx200Protocol.opProbe00],
    );
    expect(p00, equals(<int>[0x07, 0xaa, 0x55, 0x01, 0x00, 0x00, 0xc8, 0xcf]));
    expect(Fx200Protocol.verifyFrame(p00), isTrue);

    final pe0 = Fx200Protocol.buildHidPacket(
      payload: <int>[Fx200Protocol.opCmdE0],
    );
    expect(pe0, equals(<int>[0x07, 0xaa, 0x55, 0x01, 0x00, 0xe0, 0x35, 0xe1]));
    expect(Fx200Protocol.verifyFrame(pe0), isTrue);

    final pa6 = Fx200Protocol.buildHidPacket(
      payload: <int>[
        Fx200Protocol.opPresetRead,
        0x8b,
        ...List<int>.filled(15, 0),
      ],
    );
    expect(
      pa6.sublist(0, 7),
      equals(<int>[0x17, 0xaa, 0x55, 0x11, 0x00, 0xa6, 0x8b]),
    );
    expect(pa6.sublist(pa6.length - 2), equals(<int>[0x4e, 0x42]));
    expect(Fx200Protocol.verifyFrame(pa6), isTrue);
  });

  test('reassembles and decodes 0x93 AMP module frame from captura.pcapng', () {
    // Frame #934 from captura.pcapng: 17 aa 55 11 00 93 0001 0007 0037 000b 002b 0040 0039 003a 80 bb
    final rawPacket = <int>[
      0x17,
      0xaa,
      0x55,
      0x11,
      0x00,
      0x93,
      0x00,
      0x01,
      0x00,
      0x07,
      0x00,
      0x37,
      0x00,
      0x0b,
      0x00,
      0x2b,
      0x00,
      0x40,
      0x00,
      0x39,
      0x00,
      0x3a,
      0x80,
      0xbb,
    ];

    final assembler = Fx200FrameAssembler();
    final frames = assembler.feedPacket(rawPacket);
    expect(frames.length, 1);
    expect(frames.first.opcode, 0x93);

    final module = Fx200Protocol.decodeModuleFrame(
      frames.first.opcode,
      frames.first.body,
    );
    expect(module, isNotNull);
    expect(module!.name, 'AMP');
    expect(module.enabled, isTrue);
    expect(module.modelId, 7);
    expect(module.params, equals(<int>[55, 11, 43, 64, 57, 58]));

    // Round-trip encodeModuleFrame -> feedPacket -> decodeModuleFrame
    final encoded = Fx200Protocol.encodeModuleFrame(
      module.copyWith(enabled: false),
    );
    expect(Fx200Protocol.verifyFrame(encoded), isTrue);
    final decoded = assembler.feedPacket(encoded);
    expect(decoded.length, 1);
    final rt = Fx200Protocol.decodeModuleFrame(
      decoded.first.opcode,
      decoded.first.body,
    );
    expect(rt!.enabled, isFalse);
    expect(rt.params, equals(module.params));

    // Preset read packet matches captura.pcapng
    expect(
      Fx200Protocol.buildPresetReadPacket(0x8b),
      equals(
        Fx200Protocol.buildHidPacket(
          payload: <int>[
            Fx200Protocol.opPresetRead,
            0x8b,
            ...List<int>.filled(15, 0),
          ],
        ),
      ),
    );
  });

  test('decodes 0xA5 preset dump name from captura.pcapng', () {
    // body: 80 00 01 00 "F Twin 65\0" ...
    final body = <int>[
      0x80,
      0x00,
      0x01,
      0x00,
      ...'F Twin 65'.codeUnits,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ];
    final decoded = Fx200Protocol.decodePresetDumpFrame(
      Fx200Protocol.opPresetList,
      body,
    );
    expect(decoded, isNotNull);
    expect(decoded!.index, 1);
    expect(decoded.name, 'F Twin 65');

    // Non-zero chunk index (body[3] != 0x00) does not carry the preset name header.
    final chunk1 = <int>[0x80, 0x00, 0x01, 0x01, ...List.filled(16, 0)];
    expect(
      Fx200Protocol.decodePresetDumpFrame(Fx200Protocol.opPresetList, chunk1),
      isNull,
    );
  });

  test('encodes and decodes 0xA8 preset save/rename frame', () {
    final packet = Fx200Protocol.buildPresetSavePacket(140, 'J900 V1 LEAD');
    expect(Fx200Protocol.verifyFrame(packet), isTrue);
    final body = packet.sublist(6, packet.length - 2);
    final decoded = Fx200Protocol.decodePresetSaveFrame(
      Fx200Protocol.opPresetSave,
      body,
    );
    expect(decoded, isNotNull);
    expect(decoded!.index, 140);
    expect(decoded.name, 'J900 V1 LEAD');
  });

  test('encodes and decodes 0xA0 signal chain order frame', () {
    final order = <int>[6, 2, 1, 3, 4, 5, 7, 8, 9, 10];
    final enabled = <bool>[
      true,
      false,
      false,
      true,
      false,
      true,
      false,
      false,
      true,
      true,
    ];
    final packet = Fx200Protocol.buildChainOrderPacket(order, enabled);
    expect(Fx200Protocol.verifyFrame(packet), isTrue);
    final body = packet.sublist(6, packet.length - 2);
    final decoded = Fx200Protocol.decodeChainOrderFrame(
      Fx200Protocol.opCmdA0,
      body,
    );
    expect(decoded, isNotNull);
    expect(decoded!.order1Based, order);
    expect(decoded.enabledStates, enabled);
  });
}
