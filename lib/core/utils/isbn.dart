// Typed ISBNs, turned into the ISBN-13 that saved books use, so a book
// added by hand matches the same edition scanned from its barcode.

// Digits (and a final X for ISBN-10) with spaces and dashes dropped
String _clean(String text) =>
    text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

bool _validIsbn10(String s) {
  if (!RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final digit = s[i] == 'X' ? 10 : int.parse(s[i]);
    sum += digit * (10 - i);
  }
  return sum % 11 == 0;
}

int _isbn13CheckDigit(String first12) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(first12[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10;
}

bool _validIsbn13(String s) {
  if (!RegExp(r'^\d{13}$').hasMatch(s)) return false;
  return _isbn13CheckDigit(s.substring(0, 12)) == int.parse(s[12]);
}

// The ISBN-13 for a typed ISBN-10 or ISBN-13, or null when it isn't a
// valid one (wrong length or check digit)
String? toIsbn13(String text) {
  final s = _clean(text);
  if (_validIsbn13(s)) return s;
  if (!_validIsbn10(s)) return null;

  final first12 = '978${s.substring(0, 9)}';
  return '$first12${_isbn13CheckDigit(first12)}';
}
