import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

Uint8List _hex(String s) {
  final parts = s.trim().split(RegExp(r'\s+'));
  return Uint8List.fromList(parts.map((p) => int.parse(p, radix: 16)).toList());
}

/// `0xA1` body received after `0xE0` in captura.pcapng (frame 19055).
final Uint8List _capturedA1 = _hex(
  '01 34 01 00 32 32 01 01 01 00 00 02 00 00 00 00 09 00 64 00 00 01 01 00 '
  '00 00 00 01 00 00 84 1a 1f 00 26 22 14 00 3b 27 1b 00 99 3a 3e 00',
);

void main() {
  group('0xA1 global settings', () {
    test('decodes the captured SYSTEM block', () {
      final s = Fx200Protocol.decodeGlobalSettingsFrame(0xa1, _capturedA1)!;
      expect(s.brightness, 100);
      expect(s.usbRecVol, 50);
      expect(s.usbPlayVol, 50);
      expect(s.usbMix, 52);
      expect(s.usbLeftDry, isFalse);
      expect(s.usbRightDry, isTrue);
      expect(s.globalCabLeft, isTrue);
      expect(s.globalCabRight, isTrue);
      expect(s.cabSync, isTrue);
      expect(s.fsMode, Fx200GlobalSettings.fsModeDual);
      expect(s.looperPost, isTrue);
      expect(s.spillOver, isTrue);
      expect(s.midiOut, isFalse);
      expect(s.midiChannel, 0);
      expect(s.midiClockSync, isTrue);
      expect(s.globalEqEnabled, isFalse);
      expect(s.eqHighCutHz, 15001);
      expect(s.eqLowCutHz, 62);
    });

    test(
      'edits only the targeted bytes and re-encodes a valid 0xA1 packet',
      () {
        final s = Fx200GlobalSettings.fromBody(_capturedA1);
        final edited = s
            .withBrightness(80)
            .withEqLowCutHz(120)
            .withFsMode(Fx200GlobalSettings.fsModeFavorite);

        final before = s.raw;
        final after = edited.raw;
        for (var i = 0; i < Fx200GlobalSettings.length; i++) {
          if (i == 18 || i == 11 || i == 44 || i == 45) continue;
          expect(after[i], before[i], reason: 'byte $i must be preserved');
        }
        expect(after[18], 80);
        expect(after[11], 1);
        expect(after[44] | (after[45] << 8), 120);

        final packet = Fx200Protocol.buildGlobalSettingsPacket(edited);
        // frameLen = 0x2f payload + 6 framing bytes
        expect(packet.sublist(0, 6), <int>[0x35, 0xaa, 0x55, 0x2f, 0x00, 0xa1]);
        expect(Fx200Protocol.verifyFrame(packet), isTrue);
        expect(packet.sublist(6, 6 + 46), after);
      },
    );

    test('switching MIDI direction resets the channel and limits OMNI', () {
      final s = Fx200GlobalSettings.fromBody(_capturedA1)
          .withMidiChannel(Fx200GlobalSettings.midiChannelOmni);
      expect(s.midiChannel, 16);
      final out = s.withMidiOut(true);
      expect(out.midiOut, isTrue);
      expect(out.midiChannel, 0);
      expect(out.withMidiChannel(16).midiChannel, 15);
    });

    test('EQ gain uses 0..48 with 24 = 0 dB', () {
      expect(Fx200GlobalSettings.gainToDb(24), 0);
      expect(Fx200GlobalSettings.gainToDb(48), 12);
      expect(Fx200GlobalSettings.dbToGain(-12), 0);
      expect(Fx200GlobalSettings.dbToGain(3.5), 31);
    });
  });

  group('0xA4 footswitch', () {
    test('builds the same frame layout as the pedal reports', () {
      // captura.pcapng: a4 02 00 02 00 78 (TAP, mask DS/OD, 120 BPM)
      const config = Fx200FootswitchConfig(mode: 2, ctrlMask: 0x0002, bpm: 120);
      final packet = Fx200Protocol.buildFootswitchPacket(config);
      expect(packet.sublist(5, 11), <int>[0xa4, 0x02, 0x00, 0x02, 0x00, 0x78]);
      final decoded = Fx200Protocol.decodeTapTempoFrame(
        0xa4,
        packet.sublist(6),
      );
      expect(decoded!.ctrlMask, 0x0002);
    });

    test('CTRL mask toggles one bit per module slot', () {
      const base = Fx200FootswitchConfig(mode: 1, ctrlMask: 0, bpm: 100);
      final withMod = base.withCtrlAssigned(7, true).withCtrlAssigned(1, true);
      expect(withMod.ctrlMask, 0x0082);
      expect(withMod.isCtrlAssigned(7), isTrue);
      expect(withMod.withCtrlAssigned(7, false).ctrlMask, 0x0002);
    });
  });

  group('preset dump chunks', () {
    test('decodes index as u16 big-endian and extracts the chain block', () {
      final body = Uint8List(516)
        ..[0] = 0x80
        ..[1] = 0x00
        ..[2] = 0x8c
        ..[3] = 0x04;
      final chunk = Fx200Protocol.decodePresetDumpChunk(0xa5, body)!;
      expect(chunk.index, 0x8c);
      expect(chunk.chunk, 4);
      expect(chunk.data.length, 512);

      final dump = Uint8List(Fx200Protocol.presetDumpBytes);
      const chain = <int>[6, 1, 2, 3, 4, 5, 7, 8, 9, 10];
      const flags = <int>[1, 1, 1, 1, 1, 0, 0, 0, 1, 1];
      dump.setAll(Fx200Protocol.presetDumpChainOffset, <int>[
        ...chain,
        ...flags,
      ]);
      expect(Fx200Protocol.chainBlockFromPresetDump(dump), <int>[
        ...chain,
        ...flags,
      ]);

      dump[Fx200Protocol.presetDumpChainOffset] = 0; // not a permutation
      expect(Fx200Protocol.chainBlockFromPresetDump(dump), isNull);
    });
  });
}
