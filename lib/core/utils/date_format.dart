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
