import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/isbn.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/repositories/library_repository.dart';
import 'package:shelf_snap/features/scanner/screens/isbn_scan_screen.dart';

// Adds a book typed in by hand, for books with no barcode or that search
// can't find. Only the title is required.
class AddBookForm extends ConsumerStatefulWidget {
  final String libraryId;
  const AddBookForm({super.key, required this.libraryId});

  @override
  ConsumerState<AddBookForm> createState() => _AddBookFormState();
}

class _AddBookFormState extends ConsumerState<AddBookForm> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _pagesController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _coverController = TextEditingController();

  bool _isSaving = false;

  // The cover shown in the preview. Updated a moment after typing stops,
  // so each keystroke doesn't fetch a half-typed link.
  String? _previewUrl;
  Timer? _previewTimer;

  // Empty text field -> null, so Firestore stores null rather than ""
  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  bool _isWebUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  void _onCoverChanged(String text) {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final url = text.trim();
      setState(() => _previewUrl = _isWebUrl(url) ? url : null);
    });
  }

  // A scan only fills the field; the book saves when the form is submitted
  Future<void> _scan() async {
    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const IsbnScanScreen()),
    );
    if (isbn == null || !mounted) return;
    _isbnController.text = isbn;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _pagesController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final isbn = _optional(_isbnController);
    final pages = _optional(_pagesController);
    final book = BookModel(
      title: _titleController.text.trim(),
      // "Neil Gaiman, Terry Pratchett" -> two authors
      authors: _authorController.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
      // Already checked by the validator, so this isn't null when typed
      isbn: isbn == null ? null : toIsbn13(isbn),
      pageCount: pages == null ? null : int.parse(pages),
      publisher: _optional(_publisherController),
      publishedDate: _optional(_yearController),
      coverUrl: _optional(_coverController),
      source: BookSource.manual,
    );

    setState(() => _isSaving = true);
    // Captured now: the form closes before the message shows
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .addBooks(widget.libraryId, [book]);
      messenger.showMessage(LibraryRepository.savedMessage(result));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('add manual book failed: $e');
      messenger.showError("Couldn't add the book");
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _previewUrl;
    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, color: AppColors.hint)),
    );

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a book', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a title'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Authors (optional)',
                helperText: 'Separate more than one with commas',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              // Top-aligned, so the error text doesn't move the button
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _isbnController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'ISBN (optional)',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      return toIsbn13(text) == null
                          ? 'Not a valid ISBN-10 or ISBN-13'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Same height as the field; outlined so Save stays the
                // main action
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Scan'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pagesController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Pages'),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      final n = int.tryParse(text);
                      return n == null || n <= 0 ? 'Whole number' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Year'),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      final year = int.tryParse(text);
                      final ok =
                          text.length == 4 &&
                          year != null &&
                          year <= DateTime.now().year + 1;
                      return ok ? null : 'e.g. 2001';
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _publisherController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Publisher (optional)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // What the cover will look like; the placeholder when the
                // link is empty or doesn't load
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 72,
                    child: previewUrl == null
                        ? placeholder
                        : Image.network(
                            previewUrl,
                            key: ValueKey(previewUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => placeholder,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _coverController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onChanged: _onCoverChanged,
                    onFieldSubmitted: (_) => _onSubmit(),
                    decoration: const InputDecoration(
                      labelText: 'Cover image link (optional)',
                      helperText: 'Paste a link to the cover picture',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      return _isWebUrl(text)
                          ? null
                          : 'Use a link starting with https://';
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _onSubmit,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add book'),
            ),
          ],
        ),
      ),
    );
  }
}
