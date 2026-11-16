import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/isbn.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/scanner/screens/isbn_scan_screen.dart';

// Adds, fixes or removes a library book's ISBN, typed or scanned
class EditIsbnSheet extends ConsumerStatefulWidget {
  final BookModel book;
  const EditIsbnSheet({super.key, required this.book});

  static Future<void> show(BuildContext context, BookModel book) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditIsbnSheet(book: book),
    );
  }

  @override
  ConsumerState<EditIsbnSheet> createState() => _EditIsbnSheetState();
}

class _EditIsbnSheetState extends ConsumerState<EditIsbnSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.book.isbn);

  bool _isSaving = false;
  // From the save, like a clash with another book; shown under the field
  // so it sits next to the ISBN that needs changing
  String? _error;

  bool get _isEmpty => _controller.text.trim().isEmpty;

  // An empty field removes the ISBN, but only when there was one
  bool get _isRemove => _isEmpty && widget.book.isbn != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const IsbnScanScreen()),
    );
    if (isbn == null || !mounted) return;
    setState(() {
      _controller.text = isbn;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final book = widget.book;
    final libraryId = book.libraryId;
    final bookId = book.id;
    if (libraryId == null || bookId == null) return;

    // Already checked by the validator, so this is null only when empty
    final isbn = _isEmpty ? null : toIsbn13(_controller.text);
    if (isbn == book.isbn) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    // Captured now: the sheet closes before the message shows
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateIsbn(libraryId, bookId, isbn);
      messenger.showMessage(isbn == null ? 'Removed ISBN' : 'Saved ISBN');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('updateIsbn failed: $e');
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSaving = false;
        _error = message.contains('already has')
            ? message
            : "Couldn't save, check your connection";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Bottom inset lifts the sheet above the keyboard
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ISBN', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            // Which book this is for, since the sheet covers the page
            Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              // Top-aligned, so helper and error text don't move the button
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    autofocus: widget.book.isbn == null,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _error = null),
                    onFieldSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: 'ISBN-10 or ISBN-13',
                      helperText: 'On the back cover, above the barcode',
                      errorText: _error,
                      errorMaxLines: 2,
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
                // main action. A scan only fills the field, never saves.
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
            const SizedBox(height: 24),
            FilledButton(
              // Nothing to save when there was no ISBN and none is typed
              onPressed: _isSaving || (_isEmpty && !_isRemove) ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRemove ? 'Remove ISBN' : 'Save ISBN'),
            ),
          ],
        ),
      ),
    );
  }
}
