import 'dart:math' as math;

/// RBJ biquad magnitude helpers (fs = 44.1 kHz, the pedal's rate).
class BiquadResponse {
  const BiquadResponse(this.b0, this.b1, this.b2, this.a0, this.a1, this.a2);

  final double b0, b1, b2, a0, a1, a2;

  static const double fs = 44100;

  factory BiquadResponse.peaking(double f0, double db, {double q = 0.9}) {
    final a = math.pow(10, db / 40).toDouble();
    final w0 = 2 * math.pi * f0.clamp(10, fs / 2.05) / fs;
    final alpha = math.sin(w0) / (2 * q);
    final c = math.cos(w0);
    return BiquadResponse(
      1 + alpha * a,
      -2 * c,
      1 - alpha * a,
      1 + alpha / a,
      -2 * c,
      1 - alpha / a,
    );
  }

  factory BiquadResponse.highPass(double f0) {
    final w0 = 2 * math.pi * f0.clamp(10, fs / 2.05) / fs;
    final alpha = math.sin(w0) / (2 * math.sqrt1_2);
    final c = math.cos(w0);
    return BiquadResponse(
      (1 + c) / 2,
      -(1 + c),
      (1 + c) / 2,
      1 + alpha,
      -2 * c,
      1 - alpha,
    );
  }

  factory BiquadResponse.lowPass(double f0) {
    final w0 = 2 * math.pi * f0.clamp(10, fs / 2.05) / fs;
    final alpha = math.sin(w0) / (2 * math.sqrt1_2);
    final c = math.cos(w0);
    return BiquadResponse(
      (1 - c) / 2,
      1 - c,
      (1 - c) / 2,
      1 + alpha,
      -2 * c,
      1 - alpha,
    );
  }

  double dbAt(double hz) {
    final w = 2 * math.pi * hz / fs;
    final c1 = math.cos(w), s1 = math.sin(w);
    final c2 = math.cos(2 * w), s2 = math.sin(2 * w);
    final nr = b0 + b1 * c1 + b2 * c2, ni = -(b1 * s1 + b2 * s2);
    final dr = a0 + a1 * c1 + a2 * c2, di = -(a1 * s1 + a2 * s2);
    final mag2 = (nr * nr + ni * ni) / math.max(1e-12, dr * dr + di * di);
    return 10 * math.log(math.max(1e-12, mag2)) / math.ln10;
  }
}
