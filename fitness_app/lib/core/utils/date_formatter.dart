/// Shared date formatting utilities.
///
/// Centralised here to avoid duplication across presentation files.
library;

/// Formats a [DateTime] as `dd/MM/yyyy`.
String formatShortDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year}';