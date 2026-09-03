import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The most a session note may hold.
///
/// Long enough for "felt strong, shoulder twinged on the last set of presses —
/// drop to 80% next week", short enough that the field stays a note rather
/// than becoming a journal the history list has to render.
const int kSessionNoteMaxLength = 280;

/// Writes or clears the note on a session.
///
/// Returns the new note — null to clear it — or nothing if dismissed. The
/// caller cannot tell "cleared" from "cancelled" by the value alone, so this
/// resolves to a record rather than a bare string.
Future<({String? note})?> showSessionNoteDialog(
  BuildContext context, {
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');

  return showDialog<({String? note})>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial == null ? 'Add a note' : 'Edit note'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        maxLength: kSessionNoteMaxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'How did it go?',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (initial != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OneRepColors.error),
            onPressed: () => Navigator.pop(context, (note: null)),
            child: const Text('Remove'),
          ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            // Blank is a clear, not an empty note — the repository applies the
            // same rule, so the two cannot disagree.
            Navigator.pop(context, (note: text.isEmpty ? null : text));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// A session's note, or an invitation to write one.
///
/// Sits in the detail sheet rather than on the history row: a note is worth
/// reading when you have opened a session, and would crowd a list of them.
class SessionNoteSection extends StatelessWidget {
  const SessionNoteSection({
    super.key,
    required this.note,
    required this.onEdit,
  });

  final String? note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = note;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: OneRepColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: text == null
                ? OneRepColors.surfaceHighest
                : OneRepColors.gold.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              text == null ? Icons.add_comment_outlined : Icons.notes,
              size: 16,
              color: text == null
                  ? OneRepColors.textSecondary
                  : OneRepColors.gold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text ?? 'Add a note',
                style: TextStyle(
                  color: text == null
                      ? OneRepColors.textSecondary
                      : OneRepColors.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: text == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
