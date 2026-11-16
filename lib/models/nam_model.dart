import 'dart:convert';

/// Compatibility tier for running a `.nam` capture on an embedded Cortex-M7 DSP.
enum NamDspCompatibility {
  compatible,
  heavy,
  unsupported,
}

/// Parsed representation of a Neural Amp Modeler (`.nam`) / TONE3000 capture.
class NamModel {
  const NamModel({
    required this.version,
    required this.architecture,
    required this.sampleRate,
    required this.weightCount,
    required this.config,
    required this.metadata,
  });

  final String version;
  final String architecture;
  final double? sampleRate;
  final int weightCount;
  final Map<String, dynamic> config;
  final Map<String, dynamic> metadata;

  String get displayName {
    final name = metadata['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Untitled NAM Capture';
  }

  String get modeledBy {
    final author = metadata['modeled_by'];
    return author is String && author.trim().isNotEmpty ? author.trim() : 'Unknown';
  }

  String get gear {
    final value = metadata['gear'];
    return value is String && value.trim().isNotEmpty ? value.trim() : 'Unspecified';
  }

  /// Estimates whether the capture fits within a Cortex-M7 real-time DSP budget.
  ///
  /// Standard desktop WaveNet models typically exceed real-time M7 FLOPs;
  /// compact LSTM / Feather / Nano profiles (<= ~3,500 weights) are candidates.
  NamDspCompatibility get dspCompatibility {
    if (weightCount <= 0) {
      return NamDspCompatibility.unsupported;
    }
    final arch = architecture.toLowerCase();
    if (arch.contains('lstm') || arch.contains('linear') || arch.contains('a2')) {
      return weightCount <= 4000
          ? NamDspCompatibility.compatible
          : NamDspCompatibility.heavy;
    }
    if (weightCount <= 3500) {
      return NamDspCompatibility.compatible;
    }
    if (weightCount <= 12000) {
      return NamDspCompatibility.heavy;
    }
    return NamDspCompatibility.unsupported;
  }

  bool get needsSampleRateConversion =>
      sampleRate != null && sampleRate!.round() != 44100;

  /// Parses a `.nam` JSON string into a [NamModel].
  ///
  /// Throws a [FormatException] if required fields are missing or malformed.
  factory NamModel.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object at the root of .nam file.');
    }

    final version = decoded['version'];
    final architecture = decoded['architecture'];
    final weights = decoded['weights'];

    if (architecture is! String || architecture.trim().isEmpty) {
      throw const FormatException('Missing required "architecture" string.');
    }
    if (weights is! List) {
      throw const FormatException('Missing required "weights" array.');
    }

    final rawRate = decoded['sample_rate'];
    final double? sampleRate = rawRate is num ? rawRate.toDouble() : null;

    final rawConfig = decoded['config'];
    final config = rawConfig is Map<String, dynamic>
        ? rawConfig
        : <String, dynamic>{};

    final rawMeta = decoded['metadata'];
    final metadata = rawMeta is Map<String, dynamic>
        ? rawMeta
        : <String, dynamic>{};

    return NamModel(
      version: version is String ? version : 'unknown',
      architecture: architecture.trim(),
      sampleRate: sampleRate,
      weightCount: weights.length,
      config: config,
      metadata: metadata,
    );
  }
}
