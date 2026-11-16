import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../core/fx200_constants.dart';

/// Descriptor of a discovered USB device matching the FX200 Vendor ID.
class Fx200UsbDevice {
  const Fx200UsbDevice({
    required this.vendorId,
    required this.productId,
    required this.bcdDevice,
  });

  final int vendorId;
  final int productId;
  final int bcdDevice;

  bool get isKnownFx200Pid => Fx200Constants.usbProductIds.contains(productId);

  String get hexVidPid =>
      '0x${vendorId.toRadixString(16).padLeft(4, '0')}:'
      '0x${productId.toRadixString(16).padLeft(4, '0')}';
}

/// Result of a USB discovery scan.
class UsbScanResult {
  const UsbScanResult({
    required this.devices,
    this.errorMessage,
  });

  final List<Fx200UsbDevice> devices;
  final String? errorMessage;
}

final class _LibusbDeviceDescriptor extends Struct {
  @Uint8()
  external int bLength;
  @Uint8()
  external int bDescriptorType;
  @Uint16()
  external int bcdUSB;
  @Uint8()
  external int bDeviceClass;
  @Uint8()
  external int bDeviceSubClass;
  @Uint8()
  external int bDeviceProtocol;
  @Uint8()
  external int bMaxPacketSize0;
  @Uint16()
  external int idVendor;
  @Uint16()
  external int idProduct;
  @Uint16()
  external int bcdDevice;
  @Uint8()
  external int iManufacturer;
  @Uint8()
  external int iProduct;
  @Uint8()
  external int iSerialNumber;
  @Uint8()
  external int bNumConfigurations;
}

typedef _LibusbInitNative = Int32 Function(Pointer<Pointer<Void>> ctx);
typedef _LibusbInitDart = int Function(Pointer<Pointer<Void>> ctx);

typedef _LibusbExitNative = Void Function(Pointer<Void> ctx);
typedef _LibusbExitDart = void Function(Pointer<Void> ctx);

typedef _LibusbGetDeviceListNative = IntPtr Function(
  Pointer<Void> ctx,
  Pointer<Pointer<Pointer<Void>>> list,
);
typedef _LibusbGetDeviceListDart = int Function(
  Pointer<Void> ctx,
  Pointer<Pointer<Pointer<Void>>> list,
);

typedef _LibusbFreeDeviceListNative = Void Function(
  Pointer<Pointer<Void>> list,
  Int32 unrefDevices,
);
typedef _LibusbFreeDeviceListDart = void Function(
  Pointer<Pointer<Void>> list,
  int unrefDevices,
);

typedef _LibusbGetDeviceDescriptorNative = Int32 Function(
  Pointer<Void> dev,
  Pointer<_LibusbDeviceDescriptor> desc,
);
typedef _LibusbGetDeviceDescriptorDart = int Function(
  Pointer<Void> dev,
  Pointer<_LibusbDeviceDescriptor> desc,
);

/// Read-only `libusb-1.0` FFI scanner for Flamma FX200 USB devices.
class Fx200UsbTransport {
  DynamicLibrary? _tryOpenLibusb() {
    final candidates = <String>[
      if (Platform.isLinux) ...[
        'libusb-1.0.so.0',
        'libusb-1.0.so',
      ],
      if (Platform.isMacOS) ...[
        'libusb-1.0.0.dylib',
        '/opt/homebrew/lib/libusb-1.0.dylib',
      ],
      if (Platform.isWindows) 'libusb-1.0.dll',
    ];

    for (final name in candidates) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {
        // Try next candidate.
      }
    }
    return null;
  }

  /// Scans USB buses for devices with STMicroelectronics VID (`0x0483`).
  UsbScanResult scanForFx200() {
    final lib = _tryOpenLibusb();
    if (lib == null) {
      return const UsbScanResult(
        devices: <Fx200UsbDevice>[],
        errorMessage: 'libusb-1.0 library not found on this system.',
      );
    }

    final init = lib.lookupFunction<_LibusbInitNative, _LibusbInitDart>('libusb_init');
    final exit = lib.lookupFunction<_LibusbExitNative, _LibusbExitDart>('libusb_exit');
    final getList = lib.lookupFunction<_LibusbGetDeviceListNative, _LibusbGetDeviceListDart>(
      'libusb_get_device_list',
    );
    final freeList = lib.lookupFunction<_LibusbFreeDeviceListNative, _LibusbFreeDeviceListDart>(
      'libusb_free_device_list',
    );
    final getDesc =
        lib.lookupFunction<_LibusbGetDeviceDescriptorNative, _LibusbGetDeviceDescriptorDart>(
      'libusb_get_device_descriptor',
    );

    final ctxPtr = calloc<Pointer<Void>>();
    final listPtr = calloc<Pointer<Pointer<Void>>>();
    final descPtr = calloc<_LibusbDeviceDescriptor>();

    try {
      final initRc = init(ctxPtr);
      if (initRc != 0) {
        return UsbScanResult(
          devices: const <Fx200UsbDevice>[],
          errorMessage: 'libusb_init failed with code $initRc.',
        );
      }

      final ctx = ctxPtr.value;
      try {
        final count = getList(ctx, listPtr);
        if (count < 0) {
          return UsbScanResult(
            devices: const <Fx200UsbDevice>[],
            errorMessage: 'libusb_get_device_list failed with code $count.',
          );
        }

        final list = listPtr.value;
        try {
          final matches = <Fx200UsbDevice>[];
          for (var i = 0; i < count; i++) {
            final dev = list[i];
            if (dev == nullptr) break;
            if (getDesc(dev, descPtr) == 0) {
              final ref = descPtr.ref;
              if (ref.idVendor == Fx200Constants.usbVendorId) {
                matches.add(
                  Fx200UsbDevice(
                    vendorId: ref.idVendor,
                    productId: ref.idProduct,
                    bcdDevice: ref.bcdDevice,
                  ),
                );
              }
            }
          }
          return UsbScanResult(devices: matches);
        } finally {
          freeList(list, 1);
        }
      } finally {
        exit(ctx);
      }
    } finally {
      calloc.free(ctxPtr);
      calloc.free(listPtr);
      calloc.free(descPtr);
    }
  }
}
