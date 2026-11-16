/// Hardware and protocol constants observed from Flamma FX200 artifacts
/// (`FX200 Update.exe`, `FX200_V2.0.1.fl`, and `FX200_Manual_EN.pdf`).
class Fx200Constants {
  Fx200Constants._();

  /// STMicroelectronics USB Vendor ID used by the FX200 USB stack.
  static const int usbVendorId = 0x0483;

  /// USB Product IDs checked by `FX200 Update.exe` (`sub_402e20` / `sub_403b90`).
  static const List<int> usbProductIds = <int>[
    0x5703,
    0x5750,
    0x5708,
    0x1512,
    0x1522,
  ];

  /// Firmware `.fl` container magic tags.
  static const String firmwareHeaderTag = 'Mooer_TAGFX200';
  static const String firmwareSectionTag = 'Mooer_TAG';

  /// USB bulk transfer chunk size (bytes) used during firmware updates.
  static const int firmwareChunkBytes = 512;

  /// Audio & Impulse Response specifications from `FX200_Manual_EN.pdf`.
  static const int irSampleRateHz = 44100;
  static const int irBitDepth = 24;
  static const int irSamplePoints = 1024;
  static const int effectModuleCount = 10;
  static const int builtInEffectCount = 160;
  static const int presetPatchCount = 200;

  /// Default 10-module FX200 signal chain order.
  static const List<String> defaultSignalChain = <String>[
    'FX',
    'DS / OD',
    'AMP (NAM A2)',
    'CAB (IR 1024)',
    'NS',
    'EQ',
    'MOD',
    'DLY',
    'REV',
    'VOL',
  ];
}
