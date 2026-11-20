/// What the connected FX200's firmware can do beyond the stock V2.0.1,
/// read from the device string of the `0x84` handshake.
///
/// The pedal sends 16 bytes: `"FX200"` + NUL padding. It sends them in a
/// spontaneous `0x84` frame, and as the `0x10` answer (`[0x84, 16 B]`) to a
/// `0x84` request (U102 handler 0x4528). The custom scenes firmware puts a
/// marker after the NUL (`"SCN"` + patch version at bytes 6..9), so anything
/// reading the C string still sees "FX200"
/// (`fx200/tools/fx200_patch_scenes.py`).
class Fx200FirmwareFeatures {
  const Fx200FirmwareFeatures({
    required this.deviceName,
    this.scenesPatchVersion,
  });

  /// Opcode of the answer to a `0x84` request.
  static const int opHandshakeAnswer = 0x10;
  static const int opHandshake = 0x84;
  static const int deviceStringLength = 16;

  final String deviceName;

  /// Version of the on-pedal scenes patch, or null on stock firmware.
  final int? scenesPatchVersion;

  /// True when the firmware stores and switches scenes itself
  /// (FS MODE = SCENE).
  bool get hasPedalScenes => scenesPatchVersion != null;

  /// Patch version 2 adds the USB command `0xF5` to see and edit the
  /// pedal's scenes from the app (`fx200_pedal_scenes.dart`).
  bool get hasPedalSceneCommand => (scenesPatchVersion ?? 0) >= 2;

  /// Parses a `0x84` (spontaneous) or `0x10` (answer) frame; null for any
  /// other frame.
  static Fx200FirmwareFeatures? fromFrame(int opcode, List<int> body) {
    final List<int> s;
    if (opcode == opHandshake && body.length >= deviceStringLength) {
      s = body.sublist(0, deviceStringLength);
    } else if (opcode == opHandshakeAnswer &&
        body.length > deviceStringLength &&
        body[0] == opHandshake) {
      s = body.sublist(1, deviceStringLength + 1);
    } else {
      return null;
    }
    final nul = s.indexOf(0);
    final name = String.fromCharCodes(
      s.sublist(0, nul < 0 ? s.length : nul).where((c) => c >= 32 && c < 127),
    );
    if (name.isEmpty) return null;
    final hasMarker =
        nul >= 0 &&
        nul + 4 < s.length &&
        s[nul + 1] == 0x53 && // S
        s[nul + 2] == 0x43 && // C
        s[nul + 3] == 0x4E && // N
        s[nul + 4] > 0;
    return Fx200FirmwareFeatures(
      deviceName: name,
      scenesPatchVersion: hasMarker ? s[nul + 4] : null,
    );
  }
}
