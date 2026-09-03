import 'package:flutter/material.dart';

/// Asks for a new name, pre-filled with the current one.
///
/// Splits and routines could only be created and deleted, so correcting a
/// typo meant destroying the thing and rebuilding it — and deleting a split
/// takes every routine and every planned exercise with it. One dialog serves
/// both, because renaming is the same act either way.
///
/// Returns null if dismissed, or if the name was left unchanged or blank —
/// callers then have nothing to write.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String current,
  String label = 'Name',
}) async {
  final controller = TextEditingController(text: current);

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  final trimmed = result?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == current) return null;
  return trimmed;
}
