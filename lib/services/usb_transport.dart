import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../core/fx200_constants.dart';
import 'fx200_protocol.dart';

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
  const UsbScanResult({required this.devices, this.errorMessage});

  final List<Fx200UsbDevice> devices;
  final String? errorMessage;
}

/// Result of a live HID interrupt exchange on Interface 3 (`EP 0x05` / `0x84`).
class HidExchangeResult {
  const HidExchangeResult({
    required this.ok,
    this.txBytes = const <int>[],
    this.rxBytes = const <int>[],
    this.crcValid = false,
    this.errorMessage,
  });

  final bool ok;
  final List<int> txBytes;
  final List<int> rxBytes;
  final bool crcValid;
  final String? errorMessage;

  static String formatHex(List<int> bytes, {int maxBytes = 24}) {
    final slice = bytes.length > maxBytes ? bytes.sublist(0, maxBytes) : bytes;
    final hex = slice.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return bytes.length > maxBytes ? '$hex ... (${bytes.length}B)' : hex;
  }
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

typedef _LibusbOpenNative = Int32 Function(
  Pointer<Void> dev,
  Pointer<Pointer<Void>> devHandle,
);
typedef _LibusbOpenDart = int Function(
  Pointer<Void> dev,
  Pointer<Pointer<Void>> devHandle,
);

typedef _LibusbCloseNative = Void Function(Pointer<Void> devHandle);
typedef _LibusbCloseDart = void Function(Pointer<Void> devHandle);

typedef _LibusbKernelDriverActiveNative = Int32 Function(
  Pointer<Void> devHandle,
  Int32 interfaceNumber,
);
typedef _LibusbKernelDriverActiveDart = int Function(
  Pointer<Void> devHandle,
  int interfaceNumber,
);

typedef _LibusbDetachKernelDriverNative = Int32 Function(
  Pointer<Void> devHandle,
  Int32 interfaceNumber,
);
typedef _LibusbDetachKernelDriverDart = int Function(
  Pointer<Void> devHandle,
  int interfaceNumber,
);

typedef _LibusbAttachKernelDriverNative = Int32 Function(
  Pointer<Void> devHandle,
  Int32 interfaceNumber,
);
typedef _LibusbAttachKernelDriverDart = int Function(
  Pointer<Void> devHandle,
  int interfaceNumber,
);

typedef _LibusbClaimInterfaceNative = Int32 Function(
  Pointer<Void> devHandle,
  Int32 interfaceNumber,
);
typedef _LibusbClaimInterfaceDart = int Function(
  Pointer<Void> devHandle,
  int interfaceNumber,
);

typedef _LibusbReleaseInterfaceNative = Int32 Function(
  Pointer<Void> devHandle,
  Int32 interfaceNumber,
);
typedef _LibusbReleaseInterfaceDart = int Function(
  Pointer<Void> devHandle,
  int interfaceNumber,
);

typedef _LibusbInterruptTransferNative = Int32 Function(
  Pointer<Void> devHandle,
  Uint8 endpoint,
  Pointer<Uint8> data,
  Int32 length,
  Pointer<Int32> actualLength,
  Uint32 timeout,
);
typedef _LibusbInterruptTransferDart = int Function(
  Pointer<Void> devHandle,
  int endpoint,
  Pointer<Uint8> data,
  int length,
  Pointer<Int32> actualLength,
  int timeout,
);

/// `libusb-1.0` FFI transport for Flamma FX200 USB discovery and HID I/O.
class Fx200UsbTransport {
  DynamicLibrary? _tryOpenLibusb() {
    final candidates = <String>[
      if (Platform.isLinux) ...['libusb-1.0.so.0', 'libusb-1.0.so'],
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

  /// Scans USB buses for devices matching FX200 Vendor IDs (`0x0483`, `0x34db`).
  UsbScanResult scanForFx200() {
    final lib = _tryOpenLibusb();
    if (lib == null) {
      return const UsbScanResult(
        devices: <Fx200UsbDevice>[],
        errorMessage: 'libusb-1.0 library not found on this system.',
      );
    }

    final init = lib.lookupFunction<_LibusbInitNative, _LibusbInitDart>(
      'libusb_init',
    );
    final exit = lib.lookupFunction<_LibusbExitNative, _LibusbExitDart>(
      'libusb_exit',
    );
    final getList = lib
        .lookupFunction<_LibusbGetDeviceListNative, _LibusbGetDeviceListDart>(
          'libusb_get_device_list',
        );
    final freeList = lib
        .lookupFunction<_LibusbFreeDeviceListNative, _LibusbFreeDeviceListDart>(
          'libusb_free_device_list',
        );
    final getDesc = lib
        .lookupFunction<
          _LibusbGetDeviceDescriptorNative,
          _LibusbGetDeviceDescriptorDart
        >('libusb_get_device_descriptor');

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
              if (Fx200Constants.supportedVendorIds.contains(ref.idVendor)) {
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

  /// Sends a framed `0xAA 0x55` command over HID `EP 0x05 OUT` and reads
  /// one 64-byte response from `EP 0x84 IN`.
  HidExchangeResult sendAndReceiveHid(
    List<int> payload, {
    int timeoutMs = 1000,
  }) {
    final lib = _tryOpenLibusb();
    if (lib == null) {
      return const HidExchangeResult(
        ok: false,
        errorMessage: 'libusb-1.0 library not found on this system.',
      );
    }

    final init = lib.lookupFunction<_LibusbInitNative, _LibusbInitDart>(
      'libusb_init',
    );
    final exit = lib.lookupFunction<_LibusbExitNative, _LibusbExitDart>(
      'libusb_exit',
    );
    final getList = lib
        .lookupFunction<_LibusbGetDeviceListNative, _LibusbGetDeviceListDart>(
          'libusb_get_device_list',
        );
    final freeList = lib
        .lookupFunction<_LibusbFreeDeviceListNative, _LibusbFreeDeviceListDart>(
          'libusb_free_device_list',
        );
    final getDesc = lib
        .lookupFunction<
          _LibusbGetDeviceDescriptorNative,
          _LibusbGetDeviceDescriptorDart
        >('libusb_get_device_descriptor');
    final open = lib.lookupFunction<_LibusbOpenNative, _LibusbOpenDart>(
      'libusb_open',
    );
    final close = lib.lookupFunction<_LibusbCloseNative, _LibusbCloseDart>(
      'libusb_close',
    );
    final driverActive = lib
        .lookupFunction<
          _LibusbKernelDriverActiveNative,
          _LibusbKernelDriverActiveDart
        >('libusb_kernel_driver_active');
    final detachDriver = lib
        .lookupFunction<
          _LibusbDetachKernelDriverNative,
          _LibusbDetachKernelDriverDart
        >('libusb_detach_kernel_driver');
    final attachDriver = lib
        .lookupFunction<
          _LibusbAttachKernelDriverNative,
          _LibusbAttachKernelDriverDart
        >('libusb_attach_kernel_driver');
    final claimInterface = lib
        .lookupFunction<_LibusbClaimInterfaceNative, _LibusbClaimInterfaceDart>(
          'libusb_claim_interface',
        );
    final releaseInterface = lib
        .lookupFunction<
          _LibusbReleaseInterfaceNative,
          _LibusbReleaseInterfaceDart
        >('libusb_release_interface');
    final interruptTransfer = lib
        .lookupFunction<
          _LibusbInterruptTransferNative,
          _LibusbInterruptTransferDart
        >('libusb_interrupt_transfer');

    final ctxPtr = calloc<Pointer<Void>>();
    final listPtr = calloc<Pointer<Pointer<Void>>>();
    final descPtr = calloc<_LibusbDeviceDescriptor>();
    final handlePtr = calloc<Pointer<Void>>();
    final actualLenPtr = calloc<Int32>();
    final txBuf = calloc<Uint8>(Fx200Constants.interruptPacketBytes);
    final rxBuf = calloc<Uint8>(Fx200Constants.interruptPacketBytes);

    try {
      final initRc = init(ctxPtr);
      if (initRc != 0) {
        return HidExchangeResult(
          ok: false,
          errorMessage: 'libusb_init failed ($initRc).',
        );
      }
      final ctx = ctxPtr.value;
      try {
        final count = getList(ctx, listPtr);
        if (count < 0) {
          return HidExchangeResult(
            ok: false,
            errorMessage: 'libusb_get_device_list failed ($count).',
          );
        }
        final list = listPtr.value;
        Pointer<Void>? targetDev;
        try {
          for (var i = 0; i < count; i++) {
            final dev = list[i];
            if (dev == nullptr) break;
            if (getDesc(dev, descPtr) == 0) {
              final ref = descPtr.ref;
              if (Fx200Constants.supportedVendorIds.contains(ref.idVendor) &&
                  Fx200Constants.usbProductIds.contains(ref.idProduct)) {
                targetDev = dev;
                break;
              }
            }
          }
          if (targetDev == null) {
            return const HidExchangeResult(
              ok: false,
              errorMessage: 'No FX200 USB device connected.',
            );
          }

          final openRc = open(targetDev, handlePtr);
          if (openRc != 0) {
            final hint = openRc == -3
                ? ' (LIBUSB_ERROR_ACCESS: add udev rule for 34db:8001)'
                : '';
            return HidExchangeResult(
              ok: false,
              errorMessage: 'libusb_open failed ($openRc)$hint.',
            );
          }
        } finally {
          freeList(list, 1);
        }

        final handle = handlePtr.value;
        var detached = false;
        var claimed = false;
        try {
          if (Platform.isLinux &&
              driverActive(handle, Fx200Constants.hidInterfaceNumber) == 1) {
            final detachRc = detachDriver(
              handle,
              Fx200Constants.hidInterfaceNumber,
            );
            if (detachRc == 0) {
              detached = true;
            }
          }

          final claimRc = claimInterface(
            handle,
            Fx200Constants.hidInterfaceNumber,
          );
          if (claimRc != 0) {
            return HidExchangeResult(
              ok: false,
              errorMessage: 'libusb_claim_interface(3) failed ($claimRc).',
            );
          }
          claimed = true;

          final frame = Fx200Protocol.buildFrame(
            header0: Fx200Constants.frameHeader0,
            header1: Fx200Constants.frameHeader1,
            payload: payload,
          );
          final chunks = Fx200Protocol.splitInterruptChunks(frame);
          for (final chunk in chunks) {
            for (var i = 0; i < chunk.length; i++) {
              txBuf[i] = chunk[i];
            }
            actualLenPtr.value = 0;
            final outRc = interruptTransfer(
              handle,
              Fx200Constants.hidEndpointOut,
              txBuf,
              Fx200Constants.interruptPacketBytes,
              actualLenPtr,
              timeoutMs,
            );
            if (outRc != 0) {
              return HidExchangeResult(
                ok: false,
                txBytes: frame,
                errorMessage: 'HID OUT (0x05) failed ($outRc).',
              );
            }
          }

          actualLenPtr.value = 0;
          final inRc = interruptTransfer(
            handle,
            Fx200Constants.hidEndpointIn,
            rxBuf,
            Fx200Constants.interruptPacketBytes,
            actualLenPtr,
            timeoutMs,
          );
          if (inRc != 0) {
            return HidExchangeResult(
              ok: false,
              txBytes: frame,
              errorMessage: 'HID IN (0x84) failed ($inRc).',
            );
          }

          final rxLen = actualLenPtr.value;
          final rxBytes = Uint8List(rxLen);
          for (var i = 0; i < rxLen; i++) {
            rxBytes[i] = rxBuf[i];
          }
          return HidExchangeResult(
            ok: true,
            txBytes: frame,
            rxBytes: rxBytes,
            crcValid: Fx200Protocol.verifyFrame(rxBytes),
          );
        } finally {
          if (claimed) {
            releaseInterface(handle, Fx200Constants.hidInterfaceNumber);
          }
          if (detached && Platform.isLinux) {
            attachDriver(handle, Fx200Constants.hidInterfaceNumber);
          }
          close(handle);
        }
      } finally {
        exit(ctx);
      }
    } finally {
      calloc.free(ctxPtr);
      calloc.free(listPtr);
      calloc.free(descPtr);
      calloc.free(handlePtr);
      calloc.free(actualLenPtr);
      calloc.free(txBuf);
      calloc.free(rxBuf);
    }
  }
}
