import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../core/l10n/l10n.dart';

/// What to do with unsaved edits before switching preset.
enum UnsavedChangesChoice { save, discard, stay }

/// Asks what to do with the unsaved edits of [presetLabel] before switching
/// to [targetLabel]. Dismissing the dialog (Esc / click outside) means stay.
Future<UnsavedChangesChoice> showUnsavedChangesDialog(
  BuildContext context, {
  required String presetLabel,
  required String targetLabel,
}) async {
  final choice = await showDialog<UnsavedChangesChoice>(
    context: context,
    builder: (ctx) {
      final ext = Theme.of(ctx).extension<FxEditorThemeExtension>()!;
      final text = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ext.textPrimary),
            const SizedBox(width: 8),
            Text(tr('Unsaved changes')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            tr(
              '{0} has changes that are not saved. Save them before switching to {1}?',
              [presetLabel, targetLabel],
            ),
            style: text.bodyMedium?.copyWith(color: ext.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(UnsavedChangesChoice.stay),
            child: Text(tr('KEEP EDITING')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(UnsavedChangesChoice.discard),
            child: Text(tr('DON\'T SAVE')),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(UnsavedChangesChoice.save),
            child: Text(tr('SAVE & SWITCH')),
          ),
        ],
      );
    },
  );
  return choice ?? UnsavedChangesChoice.stay;
}
