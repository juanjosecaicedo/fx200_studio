import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../core/fx200_constants.dart';
import 'fx200_protocol.dart';
import 'usb_transport.dart';

/// Mirror of `struct hid_device_info` (hidapi >= 0.8; the fields we read keep
/// the same offsets in every released version).
final class _HidDeviceInfo extends Struct {
  external Pointer<Utf8> path;
  @Uint16()
  external int vendorId;
  @Uint16()
  external int productId;
  external Pointer<Void> serialNumber;
  @Uint16()
  external int releaseNumber;
  external Pointer<Void> manufacturerString;
  external Pointer<Void> productString;
  @Uint16()
  external int usagePage;
  @Uint16()
  external int usage;
  @Int32()
  external int interfaceNumber;
  external Pointer<_HidDeviceInfo> next;
}

typedef _InitN = Int32 Function();
typedef _InitD = int Function();
typedef _EnumN = Pointer<_HidDeviceInfo> Function(Uint16, Uint16);
typedef _EnumD = Pointer<_HidDeviceInfo> Function(int, int);
typedef _FreeEnumN = Void Function(Pointer<_HidDeviceInfo>);
typedef _FreeEnumD = void Function(Pointer<_HidDeviceInfo>);
typedef _OpenPathN = Pointer<Void> Function(Pointer<Utf8>);
typedef _OpenPathD = Pointer<Void> Function(Pointer<Utf8>);
typedef _WriteN = Int32 Function(Pointer<Void>, Pointer<Uint8>, IntPtr);
typedef _WriteD = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _ReadN = Int32 Function(Pointer<Void>, Pointer<Uint8>, IntPtr, Int32);
typedef _ReadD = int Function(Pointer<Void>, Pointer<Uint8>, int, int);
typedef _CloseN = Void Function(Pointer<Void>);
typedef _CloseD = void Function(Pointer<Void>);

/// hidapi bindings used on Windows and macOS, where the OS owns the HID
/// interface and libusb cannot claim it (Windows would need a Zadig/WinUSB
/// driver swap, macOS needs root). hidapi talks to the OS HID stack and needs
/// no driver or elevated permission.
class _Hidapi {
  _Hidapi(DynamicLibrary lib)
    : init = lib.lookupFunction<_InitN, _InitD>('hid_init'),
      enumerate = lib.lookupFunction<_EnumN, _EnumD>('hid_enumerate'),
      freeEnumeration = lib.lookupFunction<_FreeEnumN, _FreeEnumD>(
        'hid_free_enumeration',
      ),
      openPath = lib.lookupFunction<_OpenPathN, _OpenPathD>('hid_open_path'),
      write = lib.lookupFunction<_WriteN, _WriteD>('hid_write'),
      readTimeout = lib.lookupFunction<_ReadN, _ReadD>('hid_read_timeout'),
      close = lib.lookupFunction<_CloseN, _CloseD>('hid_close');

  final _InitD init;
  final _EnumD enumerate;
  final _FreeEnumD freeEnumeration;
  final _OpenPathD openPath;
  final _WriteD write;
  final _ReadD readTimeout;
  final _CloseD close;

  static _Hidapi? _cached;

  static DynamicLibrary? _openLibrary() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      if (Platform.isWindows) ...[
        '$exeDir${sep}hidapi.dll',
        'hidapi.dll',
        'libhidapi-0.dll',
      ],
      if (Platform.isMacOS) ...[
        '$exeDir/../Frameworks/libhidapi.dylib',
        'libhidapi.dylib',
        '/opt/homebrew/lib/libhidapi.dylib',
        '/usr/local/lib/libhidapi.dylib',
      ],
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

  /// Loads hidapi once; `null` when the library is missing.
  static _Hidapi? load() {
    if (_cached != null) return _cached;
    final lib = _openLibrary();
    if (lib == null) return null;
    try {
      final api = _Hidapi(lib);
      if (api.init() != 0) return null;
      return _cached = api;
    } catch (_) {
      return null;
    }
  }
}

String get _missingLibMessage => Platform.isMacOS
    ? 'hidapi library not found. Install it with "brew install hidapi" '
          'or use the packaged FX200 Studio build.'
    : 'hidapi.dll not found next to the application. Reinstall FX200 Studio.';

class _Entry {
  _Entry(this.path, this.vid, this.pid, this.release, this.iface);
  final String path;
  final int vid;
  final int pid;
  final int release;
  final int iface;
}

/// Windows/macOS implementation of the USB layer on top of hidapi.
abstract final class HidapiBackend {
  static List<_Entry> _enumerate(_Hidapi api) {
    final out = <_Entry>[];
    var node = api.enumerate(0, 0);
    final head = node;
    while (node != nullptr) {
      final ref = node.ref;
      if (Fx200Constants.supportedVendorIds.contains(ref.vendorId)) {
        out.add(
          _Entry(
            ref.path.toDartString(),
            ref.vendorId,
            ref.productId,
            ref.releaseNumber,
            ref.interfaceNumber,
          ),
        );
      }
      node = ref.next;
    }
    if (head != nullptr) api.freeEnumeration(head);
    return out;
  }

  static UsbScanResult scan() {
    final api = _Hidapi.load();
    if (api == null) {
      return UsbScanResult(
        devices: const <Fx200UsbDevice>[],
        errorMessage: _missingLibMessage,
      );
    }
    final seen = <int>{};
    final devices = <Fx200UsbDevice>[];
    for (final e in _enumerate(api)) {
      if (!seen.add(e.vid << 16 | e.pid)) continue;
      devices.add(
        Fx200UsbDevice(
          vendorId: e.vid,
          productId: e.pid,
          bcdDevice: e.release,
        ),
      );
    }
    return UsbScanResult(devices: devices);
  }

  static ({Fx200HidSession? session, String? error}) open({
    int? vendorId,
    int? productId,
    required int interfaceNumber,
  }) {
    final api = _Hidapi.load();
    if (api == null) return (session: null, error: _missingLibMessage);

    var candidates = _enumerate(api)
        .where(
          (e) =>
              (vendorId == null || e.vid == vendorId) &&
              (productId == null || e.pid == productId) &&
              // Default live mode: only the known application PID.
              (vendorId != null ||
                  (e.vid == Fx200Constants.secondaryUsbVendorId &&
                      e.pid == Fx200Constants.secondaryUsbProductId)),
        )
        .toList();
    if (candidates.isEmpty) {
      return (session: null, error: 'No FX200 USB device connected.');
    }
    // Prefer the requested interface. Some macOS hidapi builds report -1 for
    // the interface number; then fall back to whatever the device exposes.
    final exact = candidates.where((e) => e.iface == interfaceNumber).toList();
    if (exact.isNotEmpty) candidates = exact;

    String? lastError;
    for (final e in candidates) {
      final pathPtr = e.path.toNativeUtf8();
      try {
        final handle = api.openPath(pathPtr);
        if (handle != nullptr) {
          return (session: _HidapiSession(api, handle), error: null);
        }
        lastError = 'hid_open_path failed for ${e.path}.';
      } finally {
        calloc.free(pathPtr);
      }
    }
    return (
      session: null,
      error:
          '$lastError ${Platform.isMacOS ? "Check System Settings > Privacy & "
                    "Security > Input Monitoring." : "Is another program "
                    "(official FX200 editor) using the pedal?"}',
    );
  }
}

/// HID session over hidapi. Reports carry no report ID, so every write is
/// prefixed with a `0x00` byte that hidapi strips before sending.
class _HidapiSession implements Fx200HidSession {
  _HidapiSession(this._api, this._handle)
    : _tx = calloc<Uint8>(Fx200Constants.interruptPacketBytes + 1),
      _rx = calloc<Uint8>(Fx200Constants.interruptPacketBytes);

  final _Hidapi _api;
  final Pointer<Void> _handle;
  final Pointer<Uint8> _tx;
  final Pointer<Uint8> _rx;
  bool _closed = false;

  @override
  bool get isOpen => !_closed;

  @override
  int sendRaw(List<int> rawFrame, {int timeoutMs = 100}) {
    if (_closed) return -1;
    final chunks = Fx200Protocol.splitInterruptChunks(
      Uint8List.fromList(rawFrame),
    );
    const size = Fx200Constants.interruptPacketBytes;
    for (final chunk in chunks) {
      _tx[0] = 0;
      for (var i = 0; i < size; i++) {
        _tx[i + 1] = i < chunk.length ? chunk[i] : 0;
      }
      if (_api.write(_handle, _tx, size + 1) < 0) return -1;
    }
    return 0;
  }

  @override
  ({int rc, Uint8List? data}) pollIn({int timeoutMs = 10}) {
    if (_closed) return (rc: -1, data: null);
    final n = _api.readTimeout(
      _handle,
      _rx,
      Fx200Constants.interruptPacketBytes,
      timeoutMs,
    );
    if (n > 0) return (rc: 0, data: Uint8List.fromList(_rx.asTypedList(n)));
    if (n == 0) return (rc: -7, data: null); // timeout, like libusb
    return (rc: -4, data: null); // device gone / I/O error
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _api.close(_handle);
    calloc.free(_tx);
    calloc.free(_rx);
  }
}
