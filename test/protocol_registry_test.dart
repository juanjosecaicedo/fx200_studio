import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart'
    show fx200PresetStateOpcodes;
import 'package:fx200_studio/services/fx200_firmware.dart';
import 'package:fx200_studio/services/fx200_ir.dart';
import 'package:fx200_studio/services/fx200_opcodes.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

Uint8List _h(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

String _x(List<int> b) =>
    b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final fx = jsonDecode(
    File('test/fixtures/captured_frames.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('registry gate', () {
    test('every command the app writes is allowed', () {
      for (final op in <int>[
        0x83, 0x84, 0xa0, 0xa1, 0xa3, 0xa4, 0xa6, 0xa8, 0xaa, 0xad, 0xae, //
        0xe0,
        0xe1, 0xe4, ...fx200PresetStateOpcodes,
      ]) {
        expect(() => fx200CheckSendable(op), returnsNormally, reason: '$op');
      }
      for (final op in <int>[0x00, 0xaa, 0x02, 0x04, 0x06, 0x08, 0x0c, 0xff]) {
        expect(
          () => fx200CheckSendable(op, mode: Fx200UsbMode.update),
          returnsNormally,
        );
      }
    });

    test(
      'undocumented, unknown, forbidden or pedal-only commands are blocked',
      () {
        for (final op in <int>[0x82, 0xab, 0xac, 0x85, 0xa5, 0x10, 0x77]) {
          expect(
            () => fx200CheckSendable(op),
            throwsA(isA<Fx200ForbiddenCommand>()),
            reason: '$op',
          );
        }
        expect(
          () => fx200CheckSendable(0xa1, mode: Fx200UsbMode.update),
          throwsA(isA<Fx200ForbiddenCommand>()),
        );
      },
    );

    test('each entry names its source', () {
      for (final o in fx200Opcodes) {
        expect(o.source, isNotEmpty);
      }
    });
  });

  group('real frames from the official editor', () {
    test('0xA1 SYSTEM: INPUT LEVEL byte (captura-input-level)', () {
      final g = Fx200GlobalSettings.fromBody(_h(fx['a1_system_from_pedal']));
      expect(g.inputLevelDb, 8);
      final writes = (fx['a1_input_level_writes'] as List)
          .map((e) => Fx200GlobalSettings.fromBody(_h(e as String)))
          .toList();
      expect(writes.map((w) => w.inputLevelDb), [11, 10, 9, 7]);
      // The editor only changes that byte: rebuilding from the pedal's block
      // with the new level gives exactly what the official editor sent.
      expect(_x(g.withInputLevelDb(11).raw), fx['a1_input_level_writes'][0]);
    });

    test('0xAD drum, 0xAE volume, 0xA4 footswitch round-trip', () {
      final drum = Fx200DrumSettings.decode(_h(fx['ad_drum_from_pedal']))!;
      expect(
        (drum.on, drum.style, drum.groove, drum.bpm, drum.volume),
        (false, 1, 1, 110, 50),
      );
      expect(_x(drum.encode()), fx['ad_drum_from_pedal']);
      final vol = Fx200VolumePedalRange.decode(_h(fx['ae_volume_from_pedal']))!;
      expect((vol.min, vol.max), (0, 100));
      expect(_x(vol.encode()), fx['ae_volume_from_pedal']);
      final a4 = _h(fx['a4_footswitch_from_pedal']);
      final fs = Fx200Protocol.decodeTapTempoFrame(0xa4, a4)!;
      expect(fs.bpm, 120);
      final packet = Fx200Protocol.buildFootswitchPacket(
        Fx200FootswitchConfig(
          mode: fs.fsMode,
          ctrlMask: fs.ctrlMask,
          bpm: fs.bpm,
        ),
      );
      expect(_x(packet.sublist(6, 11)), fx['a4_footswitch_from_pedal']);
    });

    test('0xA3 expression pedal: what the official editor sent', () {
      final def = Fx200ExpFrame.decode(_h(fx['a3_default_from_pedal']))!;
      expect(def.assigned, isFalse);
      final writes = (fx['a3_editor_writes'] as List).cast<String>();
      for (final w in writes) {
        final f = Fx200ExpFrame.decode(_h(w))!;
        expect(_x(f.encode()), w);
        expect((f.pedal, f.mode, f.moduleSlot, f.paramIndex), (0, 0, 3, 1));
      }
      expect(Fx200ExpFrame.decode(_h(writes.first))!.assigned, isFalse);
      expect(Fx200ExpFrame.decode(_h(writes.last))!.max, 0x0296);
    });

    test('IR: names, upload name chunk, delete = official frames', () {
      final names = Fx200Ir.decodeNames(_h(fx['ir_names_85_after_import']));
      expect(names.length, 50);
      final rec = Fx200Ir.encodeRecord(
        List<double>.filled(10, 0),
        44100,
        'Disturbed_Stricken_IR.wav',
      );
      expect(_x(Fx200Ir.chunkBody(0, 7, rec)), fx['e1_import_slot0_chunk7']);
      final del = fx['e1_delete_slot1'] as Map<String, dynamic>;
      final empty = Uint8List(Fx200Ir.recordSize)
        ..setRange(3072, 3077, 'Empty'.codeUnits);
      expect(_x(Fx200Ir.chunkBody(1, 7, empty)), del['chunk7']);
      expect(
        _x(Fx200Ir.chunkBody(1, 1, empty)).substring(0, 40),
        del['chunk1_head'],
      );
      expect(fx['e4_delete_slot1'], '01');
    });

    test('0xAA backup reads use the official request format', () {
      final reqs = (fx['aa_read_requests'] as List).cast<String>();
      for (var c = 1; c <= reqs.length; c++) {
        expect(_x(<int>[2, 1, c, 0, 0]), reqs[c - 1]);
      }
      expect(fx['aa_ir_empty_answer'], '0203ff');
    });

    test('update mode: device info and start parameter (captura4)', () {
      final seq = (fx['update_mode_start'] as List)
          .cast<Map<String, dynamic>>();
      final info = seq.firstWhere((e) => e['op'] == 1);
      expect(fx200UpdateInfoStrings(_h(info['body'] as String)).first, 'FX200');
      final start = seq.firstWhere((e) => e['op'] == 2);
      expect(start['body'], '07000000');
      expect(seq.where((e) => e['ep'] == '0x2').map((e) => e['op']).take(4), [
        0x00,
        0xaa,
        0x00,
        0x02,
      ]);
    });
  });
}
