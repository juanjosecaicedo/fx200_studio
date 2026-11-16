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
}
