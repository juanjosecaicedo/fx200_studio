import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/editor_theme.dart';
import 'presentation/pages/editor_page.dart';

void main() {
  runApp(const ProviderScope(child: Fx200StudioApp()));
}

class Fx200StudioApp extends StatelessWidget {
  const Fx200StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FX200 Studio',
      debugShowCheckedModeBanner: false,
      theme: buildFxEditorTheme(),
      home: const EditorPage(),
    );
  }
}
