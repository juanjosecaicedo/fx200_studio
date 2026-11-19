import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/l10n.dart';
import 'core/theme/editor_theme.dart';
import 'presentation/pages/editor_page.dart';

void main() {
  runApp(const ProviderScope(child: Fx200StudioApp()));
}

class Fx200StudioApp extends ConsumerWidget {
  const Fx200StudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    currentLanguage = language;
    return MaterialApp(
      title: 'FX200 Studio',
      debugShowCheckedModeBanner: false,
      theme: buildFxEditorTheme(),
      // Keyed by language so every (also const) widget is rebuilt with the
      // new texts; the editor state lives in providers and is kept.
      home: KeyedSubtree(
        key: ValueKey<AppLanguage>(language),
        child: const EditorPage(),
      ),
    );
  }
}
