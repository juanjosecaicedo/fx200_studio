import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/models/nam_model.dart';

void main() {
  test('parses valid NAM A2 JSON and evaluates M7 DSP budget', () {
    const raw = '''
    {
      "version": "0.5.4",
      "architecture": "LSTM",
      "sample_rate": 48000,
      "metadata": {
        "name": "TONE3000 Crunch",
        "modeled_by": "Tester",
        "gear": "Amp"
      },
      "config": {"hidden_size": 12},
      "weights": [0.1, 0.2, 0.3]
    }
    ''';

    final model = NamModel.fromJsonString(raw);
    expect(model.displayName, 'TONE3000 Crunch');
    expect(model.architecture, 'LSTM');
    expect(model.weightCount, 3);
    expect(model.needsSampleRateConversion, isTrue);
    expect(model.dspCompatibility, NamDspCompatibility.compatible);
  });

  test('throws FormatException when weights array is missing', () {
    const invalid = '{"architecture": "WaveNet"}';
    expect(() => NamModel.fromJsonString(invalid), throwsFormatException);
  });
}
