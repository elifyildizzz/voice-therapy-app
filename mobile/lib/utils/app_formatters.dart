String formatAppDate(DateTime value, {bool withTime = false}) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();

  if (!withTime) {
    return '$day.$month.$year';
  }

  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.$year • $hour:$minute';
}
