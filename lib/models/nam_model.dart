import 'dart:convert';
import 'dart:typed_data';

/// Compatibility tier for running a `.nam` capture on an embedded Cortex-M7 DSP.
enum NamDspCompatibility { compatible, heavy, unsupported }

/// Parsed representation of a Neural Amp Modeler (`.nam`) / TONE3000 capture.
class NamModel {
  const NamModel({
    required this.version,
    required this.architecture,
    required this.sampleRate,
    required this.weightCount,
    required this.flatWeights,
    required this.config,
    required this.metadata,
  });

  final String version;
  final String architecture;
  final double? sampleRate;
  final int weightCount;
  final List<double> flatWeights;
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
    return author is String && author.trim().isNotEmpty
        ? author.trim()
        : 'Unknown';
  }

  String get gear {
    final value = metadata['gear'];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'Unspecified';
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
    if (arch.contains('lstm') ||
        arch.contains('linear') ||
        arch.contains('a2')) {
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

  /// Estimated float32 weight footprint in bytes (suitable for DTCM/Flash sizing).
  int get weightsBytes => weightCount * 4;

  /// Conservative Cortex-M7 @ 600 MHz cycle estimate per sample at 44.1 kHz
  /// (~1.5 cycles/MAC with FPU + activation overhead).
  int get estimatedM7CyclesPerSample {
    if (weightCount <= 0) return 0;
    final macCycles = (weightCount * 1.5).round();
    final archOverhead = architecture.toLowerCase().contains('lstm')
        ? 180
        : 120;
    return macCycles + archOverhead;
  }

  /// Percentage of total 600 MHz / 44.1 kHz budget (13,605 cycles/sample).
  double get estimatedM7CpuPercent =>
      (estimatedM7CyclesPerSample / 13605.0) * 100.0;

  bool get isSlimmable => architecture.toLowerCase().contains('slimmable');

  /// Effective weight count after channel slimming (`slimRatio` in `0.25..1.0`).
  /// Matrix weights scale quadratically with channel width (`r^2`).
  int effectiveWeightCount(double slimRatio) {
    final r = slimRatio.clamp(0.1, 1.0);
    if (!isSlimmable || r >= 0.999) return weightCount;
    return (weightCount * r * r).round().clamp(1, weightCount);
  }

  int effectiveM7CyclesPerSample(double slimRatio) {
    final w = effectiveWeightCount(slimRatio);
    if (w <= 0) return 0;
    final macCycles = (w * 1.5).round();
    final archOverhead = architecture.toLowerCase().contains('lstm')
        ? 180
        : 120;
    return macCycles + archOverhead;
  }

  double effectiveM7CpuPercent(double slimRatio) =>
      (effectiveM7CyclesPerSample(slimRatio) / 13605.0) * 100.0;

  NamDspCompatibility effectiveCompatibility(double slimRatio) {
    final w = effectiveWeightCount(slimRatio);
    if (w <= 0) return NamDspCompatibility.unsupported;
    if (w <= 3500) return NamDspCompatibility.compatible;
    if (w <= 12000) return NamDspCompatibility.heavy;
    return NamDspCompatibility.unsupported;
  }

  /// Exports a compact little-endian `.nam7` binary payload for Cortex-M7 firmware:
  /// `[magic "NAM7" (4B), version=1 (u16), slimPct (u16), sampleRateHz (u32), weightCount (u32), ...float32 weights...]`.
  Uint8List exportNam7Binary({double slimRatio = 1.0}) {
    final targetCount = effectiveWeightCount(slimRatio);
    final exportCount = flatWeights.length < targetCount
        ? flatWeights.length
        : targetCount;
    final byteData = ByteData(16 + exportCount * 4);
    byteData.setUint8(0, 0x4e); // 'N'
    byteData.setUint8(1, 0x41); // 'A'
    byteData.setUint8(2, 0x4d); // 'M'
    byteData.setUint8(3, 0x37); // '7'
    byteData.setUint16(4, 1, Endian.little);
    byteData.setUint16(6, (slimRatio * 100).round(), Endian.little);
    byteData.setUint32(8, 44100, Endian.little);
    byteData.setUint32(12, exportCount, Endian.little);
    for (var i = 0; i < exportCount; i++) {
      byteData.setFloat32(16 + i * 4, flatWeights[i], Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  /// Parses a `.nam` JSON string into a [NamModel].
  ///
  /// Throws a [FormatException] if required fields are missing or malformed.
  factory NamModel.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected a JSON object at the root of .nam file.',
      );
    }

    final version = decoded['version'];
    final architecture = decoded['architecture'];
    final weights = decoded['weights'];

    if (architecture is! String || architecture.trim().isEmpty) {
      throw const FormatException('Missing required "architecture" string.');
    }

    final rawConfig = decoded['config'];
    final config = rawConfig is Map<String, dynamic>
        ? rawConfig
        : <String, dynamic>{};

    final topWeights = _extractFloatList(weights);
    final nestedWeights = <double>[];
    if (topWeights.isEmpty) {
      _collectNestedWeights(config, nestedWeights);
    }
    final allWeights = topWeights.isNotEmpty ? topWeights : nestedWeights;

    if (weights is! List && allWeights.isEmpty) {
      throw const FormatException('Missing required "weights" array.');
    }

    final rawRate = decoded['sample_rate'];
    final double? sampleRate = rawRate is num ? rawRate.toDouble() : null;

    final rawMeta = decoded['metadata'];
    final metadata = rawMeta is Map<String, dynamic>
        ? rawMeta
        : <String, dynamic>{};

    return NamModel(
      version: version is String ? version : 'unknown',
      architecture: architecture.trim(),
      sampleRate: sampleRate,
      weightCount: allWeights.length,
      flatWeights: allWeights,
      config: config,
      metadata: metadata,
    );
  }

  static List<double> _extractFloatList(dynamic node) {
    if (node is! List) return const <double>[];
    return node.whereType<num>().map((e) => e.toDouble()).toList();
  }

  static void _collectNestedWeights(dynamic node, List<double> out) {
    if (node is Map) {
      for (final entry in node.entries) {
        if (entry.key == 'weights' && entry.value is List) {
          out.addAll(_extractFloatList(entry.value));
        } else {
          _collectNestedWeights(entry.value, out);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        _collectNestedWeights(item, out);
      }
    }
  }
}
