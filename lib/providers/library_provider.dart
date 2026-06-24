import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/library_repository.dart';
import '../models/library_model.dart';
import '../models/book_result.dart';

final libraryRepositoryProvider = Provider((ref) => LibraryRepository());

// All libraries for a user
final userLibrariesProvider = StreamProvider.family<List<LibraryModel>, String>(
      (ref, userId) => ref.watch(libraryRepositoryProvider).watchUserLibraries(userId),
);

// Books inside a specific library
final libraryBooksProvider = StreamProvider.family<List<BookResult>, String>(
      (ref, libraryId) => ref.watch(libraryRepositoryProvider).watchBooks(libraryId),
);

// Available genres
final genresProvider = FutureProvider<List<String>>(
      (ref) => ref.watch(libraryRepositoryProvider).fetchGenres(),
);
