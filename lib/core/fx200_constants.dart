/// Hardware and protocol constants observed from Flamma FX200 artifacts
/// (`FX200 Update.exe`, `FX200_V2.0.1.fl`, and `FX200_Manual_EN.pdf`).
class Fx200Constants {
  Fx200Constants._();

  /// STMicroelectronics USB Vendor ID used by the FX200 USB stack.
  static const int usbVendorId = 0x0483;

  /// Secondary Vendor/Product ID observed in `FX200.exe` (`sub_402016`).
  static const int secondaryUsbVendorId = 0x34db;
  static const int secondaryUsbProductId = 0x8001;

  /// All USB Vendor IDs accepted by the official FX200 tools.
  static const List<int> supportedVendorIds = <int>[
    usbVendorId,
    secondaryUsbVendorId,
  ];

  /// USB Product IDs checked by `FX200 Update.exe` (`sub_402e20` / `sub_403b90`).
  static const List<int> usbProductIds = <int>[
    0x5703,
    0x5750,
    0x5708,
    0x1512,
    0x1522,
    secondaryUsbProductId,
  ];

  /// USB interrupt transfer packet size (bytes) observed in `FX200.exe` (`sub_401680`).
  static const int interruptPacketBytes = 64;

  /// Live HID interface & endpoints observed on `0x34db:0x8001` via `lsusb -v`.
  static const int hidInterfaceNumber = 3;
  static const int hidEndpointIn = 0x84;
  static const int hidEndpointOut = 0x05;

  /// HID command frame magic bytes observed in `FX200.exe` (`sub_411eb0`..`sub_414a90`).
  static const int frameHeader0 = 0xaa;
  static const int frameHeader1 = 0x55;

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
