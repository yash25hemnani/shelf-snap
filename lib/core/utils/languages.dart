/// Languages the original-language picker offers, ISO code → name.
/// ISO 639-1 (2 letters) where one exists, otherwise ISO 639-2 (3 letters).
const languageNames = <String, String>{
  'en': 'English',

  // Indian languages
  'hi': 'Hindi',
  'bn': 'Bengali',
  'mr': 'Marathi',
  'te': 'Telugu',
  'ta': 'Tamil',
  'gu': 'Gujarati',
  'ur': 'Urdu',
  'kn': 'Kannada',
  'or': 'Odia',
  'ml': 'Malayalam',
  'pa': 'Punjabi',
  'as': 'Assamese',
  'mai': 'Maithili',
  'sa': 'Sanskrit',
  'ne': 'Nepali',
  'sd': 'Sindhi',
  'ks': 'Kashmiri',
  'kok': 'Konkani',
  'doi': 'Dogri',
  'mni': 'Manipuri',
  'brx': 'Bodo',
  'sat': 'Santali',

  // Other languages
  'fr': 'French',
  'de': 'German',
  'es': 'Spanish',
  'it': 'Italian',
  'pt': 'Portuguese',
  'nl': 'Dutch',
  'sv': 'Swedish',
  'no': 'Norwegian',
  'da': 'Danish',
  'fi': 'Finnish',
  'pl': 'Polish',
  'cs': 'Czech',
  'hu': 'Hungarian',
  'ru': 'Russian',
  'uk': 'Ukrainian',
  'el': 'Greek',
  'tr': 'Turkish',
  'he': 'Hebrew',
  'ar': 'Arabic',
  'fa': 'Persian',
  'sw': 'Swahili',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'th': 'Thai',
  'vi': 'Vietnamese',
  'id': 'Indonesian',
  'si': 'Sinhala',
  'la': 'Latin',
};

/// "French" for "fr"; falls back to the upper-case code for anything not listed.
String languageName(String code) =>
    languageNames[code.toLowerCase()] ?? code.toUpperCase();
