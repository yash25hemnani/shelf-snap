const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// Short month name for 1–12, e.g. 3 → "Mar"
String monthShort(int month) => _months[month - 1];

// Day and short month, e.g. "2 Nov". The year is added when it isn't this
// year, e.g. "3 Mar 2025".
String dayMonth(DateTime date) {
  final short = '${date.day} ${monthShort(date.month)}';
  return date.year == DateTime.now().year ? short : '$short ${date.year}';
}
