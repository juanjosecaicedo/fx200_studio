import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';

/// Small editable value box: shows [text], applies typed values on Enter or
/// when focus leaves, Esc reverts.
class ValueField extends StatefulWidget {
  const ValueField({
    super.key,
    required this.text,
    required this.accent,
    required this.parse,
    required this.onSubmit,
    this.width = 72,
  });

  final String text;
  final Color accent;
  final int? Function(String text) parse;
  final ValueChanged<int> onSubmit;
  final double width;

  @override
  State<ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<ValueField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        final v = widget.parse(_controller.text);
        _controller.text = widget.text;
        if (v != null && v != widget.parse(widget.text)) widget.onSubmit(v);
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final active = _focus.hasFocus;
    return Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: active ? ext.elevatedSurface : ext.panelSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? widget.accent : ext.subtleBorder),
      ),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            _controller.text = widget.text;
            _focus.unfocus();
          },
        },
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: active ? widget.accent : ext.textPrimary),
          cursorColor: widget.accent,
          decoration: const InputDecoration.collapsed(hintText: ''),
          onSubmitted: (_) => _focus.unfocus(),
          onTapOutside: (_) => _focus.unfocus(),
        ),
      ),
    );
  }
}
