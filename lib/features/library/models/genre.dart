import 'package:flutter/material.dart';

// The fixed genre tags. The enum name is what gets stored, so add values
// freely but never rename one. `subject` is the Open Library subject the
// search filter sends for it.
enum Genre {
  fantasy('Fantasy', 'fantasy', Icons.auto_awesome_rounded),
  scienceFiction(
    'Science Fiction',
    'science fiction',
    Icons.rocket_launch_rounded,
  ),
  romance('Romance', 'romance', Icons.favorite_rounded),
  romantasy('Romantasy', 'fantasy romance', Icons.auto_fix_high_rounded),
  mystery('Mystery', 'mystery', Icons.search_rounded),
  thriller('Thriller', 'thriller', Icons.bolt_rounded),
  horror('Horror', 'horror', Icons.dark_mode_rounded),
  historicalFiction(
    'Historical Fiction',
    'historical fiction',
    Icons.hourglass_bottom_rounded,
  ),
  literaryFiction(
    'Literary Fiction',
    'literary fiction',
    Icons.edit_note_rounded,
  ),
  classics('Classics', 'classics', Icons.account_balance_rounded),
  youngAdult('Young Adult', 'young adult fiction', Icons.school_rounded),
  lgbtq('LGBTQ+', 'lgbtq', Icons.diversity_3_rounded),
  erotica('Erotica', 'erotica', Icons.local_fire_department_rounded),
  smut('Smut', 'smut', Icons.whatshot_rounded),
  bdsm('BDSM', 'bdsm', Icons.link_rounded),
  darkRomance('Dark Romance', 'dark romance', Icons.heart_broken_rounded),
  graphicNovels('Graphic Novels', 'graphic novels', Icons.chat_bubble_rounded),
  manga('Manga', 'manga', Icons.auto_stories_rounded),
  poetry('Poetry', 'poetry', Icons.format_quote_rounded),
  biographyMemoir('Biography & Memoir', 'biography', Icons.person_rounded),
  history('History', 'history', Icons.public_rounded),
  selfHelp('Self-Help', 'self-help', Icons.spa_rounded),
  psychology('Psychology', 'psychology', Icons.psychology_rounded),
  trueCrime('True Crime', 'true crime', Icons.fingerprint_rounded);

  final String label;
  final String subject;
  final IconData icon;

  const Genre(this.label, this.subject, this.icon);
}
