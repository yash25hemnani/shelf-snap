import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final fromEnv = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/+$'), '');
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    );
  }

  // Public web catalog of a public library, served by the wrapper
  static String catalogUrl(String handle) => '$baseUrl/l/$handle';
}
