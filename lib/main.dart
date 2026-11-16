import 'package:material_ui/material_ui.dart';

import 'ui/home_page.dart';

void main() {
  runApp(const Fx200StudioApp());
}

class Fx200StudioApp extends StatelessWidget {
  const Fx200StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FX200 Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFF6D00),
      ),
      home: const Fx200HomePage(),
    );
  }
}
