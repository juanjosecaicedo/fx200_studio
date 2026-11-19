import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'fx200_firmware.dart';
import 'fx200_opcodes.dart';
import 'fx200_protocol.dart';
import 'usb_transport.dart';

/// USB identity of the FX200 in update mode (hold VALUE while powering on),
/// from the descriptors in `captura4.pcapng`.
const int fx200UpdateVendorId = 0x0483;
const int fx200UpdateProductId = 0x5703;

/// Progress / result of a firmware update running in a background isolate.
sealed class Fx200UpdateEvent {
  const Fx200UpdateEvent();
}

class Fx200UpdateProgress extends Fx200UpdateEvent {
  const Fx200UpdateProgress(this.done, this.total, this.step);
  final int done;
  final int total;
  final String step;
}

class Fx200UpdateDeviceInfo extends Fx200UpdateEvent {
  const Fx200UpdateDeviceInfo(this.info);
  final List<String> info;
}

class Fx200UpdateFinished extends Fx200UpdateEvent {
  const Fx200UpdateFinished({this.error});
  final String? error;
  bool get ok => error == null;
}

/// True when an FX200 in update mode is plugged in.
bool fx200UpdateModeConnected() {
  final scan = Fx200UsbTransport().scanForFx200();
  return scan.devices.any(
    (d) =>
        d.vendorId == fx200UpdateVendorId &&
        d.productId == fx200UpdateProductId,
  );
}

/// Flashes [fileBytes] (an `.fl` already validated with
/// [Fx200FirmwareImage.parse]) in a background isolate.
Stream<Fx200UpdateEvent> fx200FlashFirmware(Uint8List fileBytes) {
  final controller = StreamController<Fx200UpdateEvent>();
  final port = ReceivePort();
  port.listen((dynamic m) {
    if (m is! List || m.isEmpty) return;
    switch (m[0]) {
      case 'p':
        controller.add(
          Fx200UpdateProgress(m[1] as int, m[2] as int, m[3] as String),
        );
      case 'i':
        controller.add(Fx200UpdateDeviceInfo((m[1] as List).cast<String>()));
      case 'f':
        controller.add(Fx200UpdateFinished(error: m[1] as String?));
        port.close();
        controller.close();
    }
  });
  Isolate.spawn(_updateEntry, <Object>[port.sendPort, fileBytes]).catchError((
    Object e,
  ) {
    controller.add(Fx200UpdateFinished(error: '$e'));
    port.close();
    controller.close();
    return Isolate.current;
  });
  return controller.stream;
}

class _SessionPort implements Fx200UpdatePort {
  _SessionPort(this.session);
  final Fx200HidSession session;
  final Fx200FrameAssembler _assembler = Fx200FrameAssembler();
  final List<({int opcode, Uint8List body})> _pending =
      <({int opcode, Uint8List body})>[];

  @override
  void send(Uint8List packet) {
    if (packet.length > 5) {
      fx200CheckSendable(packet[5], mode: Fx200UsbMode.update);
    }
    final rc = session.sendRaw(packet, timeoutMs: 1000);
    if (rc != 0) {
      throw Fx200UpdateException('USB write failed ($rc).');
    }
  }

  @override
  ({int opcode, Uint8List body})? receive(int timeoutMs) {
    if (_pending.isNotEmpty) return _pending.removeAt(0);
    final r = session.pollIn(timeoutMs: timeoutMs);
    final data = r.data;
    if (data == null) {
      if (r.rc != -7 && r.rc != 0) {
        throw Fx200UpdateException(
          r.rc == -4
              ? 'The FX200 disconnected (USB -4).'
              : 'USB read failed (${r.rc}).',
        );
      }
      return null;
    }
    _pending.addAll(_assembler.feedPacket(data));
    return _pending.isEmpty ? null : _pending.removeAt(0);
  }
}

void _updateEntry(List<Object> args) {
  final out = args[0] as SendPort;
  final bytes = args[1] as Uint8List;
  Fx200HidSession? session;
  try {
    final image = Fx200FirmwareImage.parse(bytes);
    final opened = Fx200UsbTransport().openHidSession(
      vendorId: fx200UpdateVendorId,
      productId: fx200UpdateProductId,
      interfaceNumber: 0,
      endpointOut: 0x02,
      endpointIn: 0x81,
    );
    session = opened.session;
    if (session == null && (opened.error ?? '').contains('(-3)')) {
      throw const Fx200UpdateException(
        'No permission to open the FX200 in update mode. On Linux add a udev '
        'rule: SUBSYSTEM=="usb", ATTR{idVendor}=="0483", '
        'ATTR{idProduct}=="5703", MODE="0666" (then unplug and replug it).',
      );
    }
    if (session == null) {
      throw Fx200UpdateException(
        'FX200 in update mode not found (${opened.error}). Hold VALUE while '
        'switching the pedal on.',
      );
    }
    fx200RunFirmwareUpdate(
      _SessionPort(session),
      image,
      onProgress: (d, t, s) => out.send(<Object>['p', d, t, s]),
      onDeviceInfo: (info) => out.send(<Object>['i', info]),
    );
    out.send(<Object?>['f', null]);
  } catch (e) {
    out.send(<Object?>['f', '$e']);
  } finally {
    session?.close();
  }
}
