import 'dart:io';

/// Per-user settings folder for FX200 Studio on every desktop OS.
///
/// Linux keeps `~/.config/fx200_studio` (existing installs), Windows uses
/// `%APPDATA%\fx200_studio`, macOS `~/Library/Application Support/fx200_studio`.
Directory? fx200SettingsDir() {
  final env = Platform.environment;
  final sep = Platform.pathSeparator;
  String? base;
  if (Platform.isWindows) {
    base = env['APPDATA'];
    if (base == null && env['USERPROFILE'] != null) {
      base = '${env['USERPROFILE']}${sep}AppData${sep}Roaming';
    }
  } else if (Platform.isMacOS) {
    final home = env['HOME'];
    if (home != null) base = '$home/Library/Application Support';
  } else {
    final xdg = env['XDG_CONFIG_HOME'];
    final home = env['HOME'];
    base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : (home != null ? '$home/.config' : null);
  }
  if (base == null) return null;
  return Directory('$base${sep}fx200_studio');
}

/// A file inside [fx200SettingsDir], or `null` if no home folder is known.
File? fx200SettingsFile(String name) {
  final dir = fx200SettingsDir();
  if (dir == null) return null;
  return File('${dir.path}${Platform.pathSeparator}$name');
}
