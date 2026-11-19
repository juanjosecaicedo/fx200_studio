import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'strings_es.dart';

/// Display languages (Software Guide p. 4: "Language: select display
/// language"). Pedal terms (module, parameter and model names, menu names
/// such as FOOTSWITCH or GLOBAL EQ) stay as the FX200 shows them.
enum AppLanguage {
  en('EN', 'English'),
  es('ES', 'Español');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;
}

/// Current language used by [tr]. Set by [languageProvider]; the app root
/// rebuilds the whole tree when it changes.
AppLanguage currentLanguage = AppLanguage.en;

/// Translates an English UI text. `{0}`, `{1}`... are replaced by [args].
/// Unknown texts fall back to English.
String tr(String en, [List<Object?> args = const <Object?>[]]) {
  var s = currentLanguage == AppLanguage.es ? (stringsEs[en] ?? en) : en;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

/// Remembers the chosen language in `~/.config/fx200_studio/settings.json`
/// (defaults to the system language).
class LanguageNotifier extends Notifier<AppLanguage> {
  static File? get _file {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return null;
    return File(
      '$home${Platform.pathSeparator}.config${Platform.pathSeparator}'
      'fx200_studio${Platform.pathSeparator}settings.json',
    );
  }

  @override
  AppLanguage build() {
    // Tests always run in English, whatever the machine is set to.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      currentLanguage = AppLanguage.en;
      return AppLanguage.en;
    }
    var lang = Platform.localeName.toLowerCase().startsWith('es')
        ? AppLanguage.es
        : AppLanguage.en;
    try {
      final f = _file;
      if (f != null && f.existsSync()) {
        final json = jsonDecode(f.readAsStringSync());
        final code = json is Map ? json['language'] : null;
        lang = AppLanguage.values.firstWhere(
          (l) => l.name == code,
          orElse: () => lang,
        );
      }
    } catch (_) {
      // Unreadable settings: keep the default.
    }
    currentLanguage = lang;
    return lang;
  }

  void set(AppLanguage lang) {
    currentLanguage = lang;
    state = lang;
    try {
      final f = _file;
      if (f == null) return;
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(<String, String>{'language': lang.name}));
    } catch (_) {
      // Not fatal: the choice just is not remembered.
    }
  }
}
