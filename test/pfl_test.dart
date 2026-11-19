import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart';
import 'package:fx200_studio/services/fx200_pfl.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

/// Answers a 0x83 upload like the pedal is expected to: after each chunk it
/// asks for the next one (`body[3] = n` → PC sends chunk n + 1).
class _UploadPedal implements Fx200DeviceLink {
  _UploadPedal({this.answers = true});

  static const int lastRequest = 3;

  final bool answers;
  final _frames = StreamController<({int opcode, Uint8List body})>.broadcast();
  final Map<int, Uint8List> chunks = <int, Uint8List>{};

  @override
  bool isConnected = true;

  @override
  Stream<({int opcode, Uint8List body})> get frames => _frames.stream;

  @override
  void sendPacket(Uint8List packet) {
    expect(Fx200Protocol.verifyFrame(packet), isTrue);
    final len = packet[3] | (packet[4] << 8);
    expect(packet[5], Fx200Protocol.opCmd83);
    final body = Uint8List.fromList(packet.sublist(6, 5 + len));
    expect(body.length, 516);
    expect(body.sublist(0, 3), [1, 0, 42]);
    final chunk = body[3];
    chunks[chunk] = Uint8List.fromList(body.sublist(4));
    if (!answers || chunk > lastRequest) return;
    scheduleMicrotask(() {
      _frames.add((
        opcode: Fx200Protocol.opCmd83,
        body: Uint8List.fromList([1, 0, 42, chunk]),
      ));
    });
  }

  @override
  Future<void> waitUntilReady() async {}
  @override
  Uint8List? chainBlockFor(int index) => null;
  @override
  void rememberChainBlock(int index, Uint8List chain) {}
  @override
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump() => throw UnimplementedError();
}

Uint8List _record() {
  final r = Uint8List(Fx200Protocol.presetDumpBytes);
  for (var i = 0; i < r.length; i++) {
    r[i] = (i * 7) & 0xff;
  }
  r.setAll(0, 'DR Z'.codeUnits);
  r.fillRange(4, 16, 0);
  return r;
}

void main() {
  test('.pfl = FX200/V1.1.8 header + first 0x840 bytes of the record', () {
    final record = _record();
    final file = Fx200Pfl.encode(record);
    expect(file.length, 0x8c0);
    expect(String.fromCharCodes(file.sublist(0, 5)), 'FX200');
    expect(String.fromCharCodes(file.sublist(0x20, 0x26)), 'V1.1.8');
    expect(file.sublist(0x26, 0x80).every((b) => b == 0), isTrue);
    expect(Fx200Pfl.decode(file), record.sublist(0, 0x840));
    expect(Fx200Pfl.nameOf(Fx200Pfl.decode(file)), 'DR Z');
  });

  test('rejects unknown sizes and headers', () {
    expect(() => Fx200Pfl.decode(Uint8List(0xa20)), throwsFormatException);
    final bad = Fx200Pfl.encode(_record())..[0] = 0x58;
    expect(() => Fx200Pfl.decode(bad), throwsFormatException);
    expect(Fx200Pfl.decode(Uint8List(0x840)).length, 0x840);
  });

  test('file names follow the official editor (bank + A/B + name)', () {
    expect(Fx200Pfl.fileNameFor(4, 'DR Z'), '03A DR Z.pfl');
    expect(Fx200Pfl.fileNameFor(3, '5150CORE'), '02B 5150CORE.pfl');
    expect(Fx200Pfl.fileNameFor(199, 'A/B'), '100B A_B.pfl');
  });

  test(
    '0x83 upload sends chunk 0 then answers each request with n + 1',
    () async {
      final struct = Fx200Pfl.decode(Fx200Pfl.encode(_record()));
      final pedal = _UploadPedal();
      await fx200UploadPresetStruct(
        pedal,
        42,
        struct,
        quiet: const Duration(milliseconds: 50),
      );
      expect(pedal.chunks.keys.toList()..sort(), [0, 1, 2, 3, 4]);
      final sent = BytesBuilder();
      for (var c = 0; c <= 4; c++) {
        sent.add(pedal.chunks[c]!);
      }
      final bytes = sent.toBytes();
      expect(bytes.sublist(0, 0x840), struct);
      expect(bytes.sublist(0x840).every((b) => b == 0), isTrue);
    },
  );

  test('0x83 upload fails if the pedal never asks for data', () async {
    final pedal = _UploadPedal(answers: false);
    await expectLater(
      fx200UploadPresetStruct(
        pedal,
        42,
        Uint8List(0x840),
        firstRequestTimeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('long frames are sent as [n, 63-byte pieces] like FX200.exe', () {
    final packet = Fx200Protocol.buildRawPacket(
      Fx200Protocol.opCmd83,
      Uint8List(516),
    );
    final reports = Fx200Protocol.splitInterruptChunks(packet);
    final frameLen = 516 + 7; // AA 55 lenLo lenHi op body crcHi crcLo
    expect(reports.length, (frameLen / 63).ceil());
    expect(reports.every((r) => r.length == 64), isTrue);
    expect(reports.first[0], 63);
    expect(reports.first.sublist(1, 3), [0xaa, 0x55]);
    expect(reports.last[0], frameLen - 63 * (reports.length - 1));
    final rebuilt = <int>[for (final r in reports) ...r.sublist(1, 1 + r[0])];
    expect(rebuilt, packet.sublist(1));
  });
}
