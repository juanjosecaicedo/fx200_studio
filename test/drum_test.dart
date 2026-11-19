import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

void main() {
  test('0xAD decodes and re-encodes the drum state', () {
    const body = [0, 1, 0, 3, 0, 7, 0, 120, 0, 50];
    final d = Fx200DrumSettings.decode(body)!;
    expect((d.on, d.style, d.groove, d.bpm, d.volume), (true, 3, 7, 120, 50));
    expect(d.isMetronome, isFalse);
    expect(d.encode(), body);
  });

  test('BPM is u16 big-endian and clamped to 40..260', () {
    final d = Fx200DrumSettings.decode(const [0, 0, 0, 1, 0, 1, 1, 4, 0, 0])!;
    expect(d.bpm, 260);
    expect(d.copyWith(bpm: 200).encode().sublist(6, 8), [0, 200]);
  });

  test('switching to METRONOME uses style 9 and resets the type', () {
    const d = Fx200DrumSettings(
      on: true,
      style: 4,
      groove: 6,
      bpm: 100,
      volume: 50,
    );
    final m = d.withMetronome(true);
    expect((m.style, m.groove, m.isMetronome), (9, 1, true));
    expect(m.withMetronome(false).style, 1);
    expect(Fx200Protocol.buildDrumPacket(m).sublist(5, 16), [
      0xad,
      0,
      1,
      0,
      9,
      0,
      1,
      0,
      100,
      0,
      50,
    ]);
  });
}
