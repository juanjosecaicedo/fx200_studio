import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/l10n/l10n.dart';
import 'package:fx200_studio/core/l10n/strings_es.dart';

/// Every Spanish entry must match a tr() key in the UI code (catches typos
/// that would silently leave a text in English), and keep its placeholders.
void main() {
  final keys = <String>{};
  for (final f in <FileSystemEntity>[
    ...Directory('lib/presentation').listSync(recursive: true),
    ...Directory('lib/services').listSync(recursive: true),
  ]) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final src = f.readAsStringSync();
    for (final m in RegExp(r"\btr\(\s*'((?:[^'\\]|\\.)*)'").allMatches(src)) {
      keys.add(
        m
            .group(1)!
            .replaceAllMapped(
              RegExp(r'\\(.)'),
              (e) => e.group(1) == 'n' ? '\n' : e.group(1)!,
            ),
      );
    }
  }
  const dynamicKeys = <String>{
    // translated at display time (status codes and updater step names)
    'USB OFFLINE', 'FIRMWARE UPDATE', 'Connecting', 'Preparing the pedal',
    'Starting',
    'Done',
    'Done (the pedal restarted)',
    'Main MCU application',
    'Audio engine (DSP MCU)',
    'Audio resources', 'Factory presets', 'DISPLAY',
  };

  test('every Spanish text belongs to a key used in the UI', () {
    final unused = stringsEs.keys
        .where((k) => !keys.contains(k) && !dynamicKeys.contains(k))
        .toList();
    expect(unused, isEmpty);
  });

  test('translations keep the placeholders', () {
    final ph = RegExp(r'\{\d+\}');
    stringsEs.forEach((en, es) {
      final a = ph.allMatches(en).map((m) => m.group(0)).toSet();
      final b = ph.allMatches(es).map((m) => m.group(0)).toSet();
      expect(b, a, reason: en);
    });
  });

  test('tr() falls back to English and fills placeholders', () {
    currentLanguage = AppLanguage.es;
    expect(tr('SAVE'), 'GUARDAR');
    expect(tr('Copy {0}', ['012']), 'Copiar 012');
    expect(tr('Not translated {0}', [1]), 'Not translated 1');
    currentLanguage = AppLanguage.en;
    expect(tr('Copy {0}', ['012']), 'Copy 012');
  });
}
