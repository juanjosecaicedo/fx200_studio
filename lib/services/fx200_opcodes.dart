/// How much we actually know about a protocol command. Ordered from the
/// strongest to the weakest evidence.
enum Fx200Evidence {
  /// Sent / received by FX200 Studio and checked on a real FX200.
  verifiedOnPedal,

  /// Observed in USB captures of the official editor, layout matched
  /// byte-for-byte, but not yet exercised by FX200 Studio on the pedal.
  captured,

  /// Reconstructed from the official editor's code (FX200.exe), never seen
  /// on the wire.
  fromEditorCode,

  /// Seen or guessed, meaning not established. Never write it.
  unknown,

  /// Defined by FX200 Studio's own firmware patch
  /// (`fx200/firmware_patch/scenes`). Only sent when the pedal's `0x84`
  /// marker says that patch is installed (see [fx200CheckSendable]).
  customFirmware,
}

enum Fx200Direction { toPedal, fromPedal, both }

/// USB mode the command belongs to.
enum Fx200UsbMode {
  /// Normal mode: `0x34DB:0x8001`, interface 3, EP 0x05 / 0x84.
  normal,

  /// Update mode (VALUE held at power-on): `0x0483:0x5703`, interface 0,
  /// EP 0x02 / 0x81.
  update,
}

class Fx200OpcodeInfo {
  const Fx200OpcodeInfo(
    this.opcode,
    this.name,
    this.direction,
    this.evidence,
    this.source, {
    this.mode = Fx200UsbMode.normal,
    this.usedByApp = true,
  });

  final int opcode;
  final String name;
  final Fx200Direction direction;
  final Fx200Evidence evidence;

  /// Where the knowledge comes from (capture file, FX200.exe address, test).
  final String source;
  final Fx200UsbMode mode;

  /// False for commands FX200 Studio deliberately never sends.
  final bool usedByApp;
}

/// Every FX200 command FX200 Studio knows about, with the evidence behind
/// it. Rule: the app only *writes* commands at [Fx200Evidence.captured] or
/// better, or [Fx200Evidence.fromEditorCode] ones that were then verified
/// on the pedal (`test/protocol_registry_test.dart` enforces the list of
/// commands the code sends).
final List<Fx200OpcodeInfo> fx200Opcodes = List<Fx200OpcodeInfo>.unmodifiable(
  <Fx200OpcodeInfo>[
    // ---- normal mode ----------------------------------------------------
    const Fx200OpcodeInfo(
      0x00,
      'Probe',
      Fx200Direction.toPedal,
      Fx200Evidence.captured,
      'captura.pcapng; FX200.exe',
    ),
    const Fx200OpcodeInfo(
      0x10,
      'Answer to 0x84: [0x84, 16-byte device string]',
      Fx200Direction.fromPedal,
      Fx200Evidence.fromEditorCode,
      'U102 firmware handler 0x4528 (0x84 request -> 0x10 answer)',
    ),
    const Fx200OpcodeInfo(
      0x82,
      'Module page / UI state (meaning unknown)',
      Fx200Direction.both,
      Fx200Evidence.unknown,
      'captura-pedal-expresion, borrar-IRs; ignored',
      usedByApp: false,
    ),
    const Fx200OpcodeInfo(
      0x83,
      'Preset upload (pedal requests chunks)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'FX200.exe 0x4175a0 / 0x42c450; .pfl import + .bfl restore tests',
    ),
    const Fx200OpcodeInfo(
      0x84,
      'Handshake / device info ("FX200" + scenes-firmware marker)',
      Fx200Direction.both,
      Fx200Evidence.captured,
      'FX200.exe sub_402520; import-IRs.pcapng; U102 handler 0x4528 '
          '(only answers)',
    ),
    const Fx200OpcodeInfo(
      0x85,
      'User IR names (50 x 15 B)',
      Fx200Direction.fromPedal,
      Fx200Evidence.verifiedOnPedal,
      'import-IRs.pcapng; IR dialog test',
    ),
    const Fx200OpcodeInfo(
      0x86,
      'Active preset dump (8 x 512 B)',
      Fx200Direction.fromPedal,
      Fx200Evidence.captured,
      'captura.pcapng (end of 0xE0 dump)',
    ),
    for (var op = 0x91; op <= 0x9a; op++)
      Fx200OpcodeInfo(
        op,
        'Module state (FX..REV)',
        Fx200Direction.both,
        Fx200Evidence.verifiedOnPedal,
        'captura.pcapng; editor in daily use',
      ),
    const Fx200OpcodeInfo(
      0xa0,
      'Chain order + enabled flags',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura.pcapng; editor in daily use',
    ),
    const Fx200OpcodeInfo(
      0xa1,
      'SYSTEM block (46 B)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura-input-level.pcapng; SYSTEM / INPUT LEVEL test',
    ),
    const Fx200OpcodeInfo(
      0xa3,
      'Expression pedal assignment',
      Fx200Direction.both,
      Fx200Evidence.captured,
      'FX200.exe 0x411d50 / 0x42c290; captura-pedal-expresion.pcapng',
    ),
    const Fx200OpcodeInfo(
      0xa4,
      'Footswitch mode / CTRL mask / BPM',
      Fx200Direction.both,
      Fx200Evidence.captured,
      'captura.pcapng; FX200.exe 0x439d10',
    ),
    const Fx200OpcodeInfo(
      0xa5,
      'Preset dump chunk (8 x 512 B per preset)',
      Fx200Direction.fromPedal,
      Fx200Evidence.verifiedOnPedal,
      'captura.pcapng; .pfl / .bfl export tests',
    ),
    const Fx200OpcodeInfo(
      0xa6,
      'Select preset',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura.pcapng; editor in daily use',
    ),
    const Fx200OpcodeInfo(
      0xa8,
      'Save preset (index + name)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura.pcapng; editor in daily use',
    ),
    const Fx200OpcodeInfo(
      0xaa,
      'Backup read (type 2 = IR, type 5 = system data)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura-backup.pcapng; .bfl export identical to backup.bfl',
    ),
    const Fx200OpcodeInfo(
      0xab,
      'Backup write (official restore)',
      Fx200Direction.toPedal,
      Fx200Evidence.fromEditorCode,
      'FX200.exe 0x427dff; never sent by FX200 Studio',
      usedByApp: false,
    ),
    const Fx200OpcodeInfo(
      0xac,
      'Backup commit (official restore)',
      Fx200Direction.toPedal,
      Fx200Evidence.fromEditorCode,
      'FX200.exe 0x427b75; never sent by FX200 Studio',
      usedByApp: false,
    ),
    const Fx200OpcodeInfo(
      0xad,
      'Drum machine / metronome',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'FX200.exe 0x411cc0 / 0x42c250; DRUM test on the pedal',
    ),
    const Fx200OpcodeInfo(
      0xae,
      'Expression pedal VOLUME range',
      Fx200Direction.both,
      Fx200Evidence.captured,
      'FX200.exe 0x411eb0; captura-pedal-expresion.pcapng',
    ),
    const Fx200OpcodeInfo(
      0xbb,
      'Merge status (meaning unknown, replayed verbatim)',
      Fx200Direction.both,
      Fx200Evidence.captured,
      'captura.pcapng; only re-sent byte-for-byte as captured (backups)',
    ),
    const Fx200OpcodeInfo(
      0xe0,
      'Request full preset dump',
      Fx200Direction.toPedal,
      Fx200Evidence.verifiedOnPedal,
      'captura.pcapng; editor in daily use',
    ),
    const Fx200OpcodeInfo(
      0xe1,
      'User IR upload (7 chunks, acknowledged)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'import-IRs.pcapng; IR load test',
    ),
    const Fx200OpcodeInfo(
      0xe4,
      'User IR delete',
      Fx200Direction.toPedal,
      Fx200Evidence.verifiedOnPedal,
      'borrar-IRs.pcapng; IR delete test',
    ),

    // ---- update mode ----------------------------------------------------
    const Fx200OpcodeInfo(
      0x00,
      'Device info request (answer 0x01)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura4.pcapng; firmware test',
      mode: Fx200UsbMode.update,
    ),
    const Fx200OpcodeInfo(
      0xaa,
      'Update handshake (answer 0xAB)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura4.pcapng; firmware test',
      mode: Fx200UsbMode.update,
    ),
    const Fx200OpcodeInfo(
      0x02,
      'Start update (answer 0x03)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura4.pcapng; firmware test',
      mode: Fx200UsbMode.update,
    ),
    for (final op in const <int>[0x04, 0x06, 0x08])
      Fx200OpcodeInfo(
        op,
        'Firmware block (answer op + 1)',
        Fx200Direction.both,
        Fx200Evidence.verifiedOnPedal,
        'captura4.pcapng (16396 frames identical); firmware test',
        mode: Fx200UsbMode.update,
      ),
    const Fx200OpcodeInfo(
      0x0c,
      'Commit section (answer 0x0D)',
      Fx200Direction.both,
      Fx200Evidence.verifiedOnPedal,
      'captura4.pcapng; firmware test',
      mode: Fx200UsbMode.update,
    ),
    const Fx200OpcodeInfo(
      0xff,
      'Finish update (pedal reboots)',
      Fx200Direction.toPedal,
      Fx200Evidence.verifiedOnPedal,
      'captura4.pcapng; firmware test',
      mode: Fx200UsbMode.update,
    ),
    // ---- FX200 Studio scenes firmware (not in the stock firmware) -------
    const Fx200OpcodeInfo(
      0xf5,
      'Pedal scenes: info / select / read / write (custom firmware v2)',
      Fx200Direction.both,
      Fx200Evidence.customFirmware,
      'fx200/firmware_patch/scenes/scenes.c (scenes_usb_hook, hook at 0x6E64)',
    ),
  ],
);

/// Registry entry of [opcode] in [mode], or null if it is not documented.
Fx200OpcodeInfo? fx200OpcodeInfo(
  int opcode, {
  Fx200UsbMode mode = Fx200UsbMode.normal,
}) {
  for (final o in fx200Opcodes) {
    if (o.opcode == opcode && o.mode == mode) return o;
  }
  return null;
}

/// Thrown when code tries to send a command the registry does not allow.
class Fx200ForbiddenCommand implements Exception {
  const Fx200ForbiddenCommand(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The single gate every outgoing packet passes: only documented commands,
/// with known meaning and used by the app, may reach the pedal.
///
/// Commands of the custom firmware ([Fx200Evidence.customFirmware]) also
/// need [customFirmware] = true, which the caller sets only when the
/// connected pedal reported that firmware.
Fx200OpcodeInfo fx200CheckSendable(
  int opcode, {
  Fx200UsbMode mode = Fx200UsbMode.normal,
  bool customFirmware = false,
}) {
  final hex = '0x${opcode.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  final info = fx200OpcodeInfo(opcode, mode: mode);
  if (info == null) {
    throw Fx200ForbiddenCommand(
      '$hex is not a documented ${mode.name} command.',
    );
  }
  if (!info.usedByApp || info.evidence == Fx200Evidence.unknown) {
    throw Fx200ForbiddenCommand(
      '$hex (${info.name}) must not be sent: ${info.evidence.name}.',
    );
  }
  if (info.evidence == Fx200Evidence.customFirmware && !customFirmware) {
    throw Fx200ForbiddenCommand(
      '$hex (${info.name}) needs the FX200 Studio firmware patch.',
    );
  }
  if (info.direction == Fx200Direction.fromPedal) {
    throw Fx200ForbiddenCommand(
      '$hex (${info.name}) only comes from the pedal.',
    );
  }
  return info;
}
