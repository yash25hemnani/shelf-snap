import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/user_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/repositories/loan_repository.dart';
import 'package:shelf_snap/features/lending/widgets/loan_date_row.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

// Records a loan made outside the app, maybe from before it existed. The
// borrower is an app user picked by username, or just a typed name. Pops
// with the borrower's name once the loan is saved.
class LendCopyForm extends ConsumerStatefulWidget {
  const LendCopyForm({super.key});

  @override
  ConsumerState<LendCopyForm> createState() => _LendCopyFormState();
}

class _LendCopyFormState extends ConsumerState<LendCopyForm> {
  // Characters a username can have, with an optional @ in front
  static final _usernameLike = RegExp(r'^@?[a-zA-Z0-9._]+$');

  final _name = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  Timer? _debounce;

  String? _libraryId;
  BookModel? _book;
  UserModel? _borrower; // set when an app user is picked
  List<UserModel> _matches = [];
  late DateTime _lentOn = _today;
  late DateTime? _dueOn = _today.add(const Duration(days: 14));
  bool _saving = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _borrowerName => _borrower?.name ?? _name.text.trim();

  bool get _canSave =>
      !_saving &&
      _libraryId != null &&
      _book != null &&
      _borrowerName.isNotEmpty;

  // Runs on every keystroke in the name field
  void _onNameChanged(String text) {
    setState(() {});
    _debounce?.cancel();

    // A name with spaces can't be a username, so it saves a search
    if (!_usernameLike.hasMatch(text.trim())) {
      setState(() => _matches = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _searchUsers(text),
    );
  }

  Future<void> _searchUsers(String text) async {
    try {
      final users = await ref
          .read(userRepositoryProvider)
          .searchUsers(text.trim().replaceFirst('@', ''));
      if (!mounted || text != _name.text) return;
      setState(() => _matches = users);
    } catch (e) {
      // Matches are a nice-to-have; a typed name still works without them
      debugPrint('searchUsers failed: $e');
    }
  }

  void _pickBorrower(UserModel user) {
    _debounce?.cancel();
    setState(() {
      _borrower = user;
      _matches = [];
    });
  }

  void _clearBorrower() {
    setState(() {
      _borrower = null;
      _name.clear();
    });
  }

  Future<void> _pickLentOn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lentOn,
      firstDate: DateTime(2000),
      lastDate: _today,
      helpText: 'Lent on',
    );
    if (picked == null) return;

    setState(() {
      _lentOn = picked;
      // The return date has to come after the lent date
      if (_dueOn case final due? when !due.isAfter(picked)) _dueOn = null;
    });
  }

  Future<void> _pickDue() async {
    final first = _lentOn.add(const Duration(days: 1));
    final last = _today.add(const Duration(days: 365));
    final suggested = _lentOn.add(const Duration(days: 14));

    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? (suggested.isAfter(last) ? last : suggested),
      firstDate: first,
      lastDate: last,
      helpText: 'Return by',
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _save() async {
    final userId = AuthService().currentUser?.uid;
    final libraryId = _libraryId;
    final book = _book;
    if (userId == null || libraryId == null || book == null || !_canSave) {
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final name = _borrowerName;

    try {
      await ref
          .read(loanRepositoryProvider)
          .lendManually(
            libraryId: libraryId,
            book: book,
            borrowerName: name,
            userId: userId,
            borrowerId: _borrower?.uid,
            // Today means right now, so the time is kept
            lentOn: _lentOn == _today ? null : _lentOn,
            dueOn: _dueOn,
            note: _note.text,
          );

      if (!mounted) return;
      Navigator.pop(context, name);
    } catch (e) {
      debugPrint('lendManually failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showError(
        loanErrorText(e, "Couldn't save the loan, check your connection"),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    final userId = AuthService().currentUser?.uid ?? '';
    final libraries = ref
        .watch(userLibrariesProvider(userId))
        .valueOrNull
        ?.where((l) => l.id != null && l.canEdit(userId))
        .toList();

    // The only library is picked for the user
    if (_libraryId == null && libraries != null && libraries.length == 1) {
      _libraryId = libraries.first.id;
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Already lent outside the app? Add it here, even if it was '
            'before Shelf Snap.',
            style: muted,
          ),
          const SizedBox(height: 16),
          if (libraries == null)
            const Center(child: CircularProgressIndicator())
          else if (libraries.isEmpty)
            Text('You can only lend from libraries you manage.', style: muted)
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _libraryId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              dropdownColor: AppColors.background,
              elevation: 2,
              menuMaxHeight: 320,
              hint: const Text('Choose a library'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.local_library_outlined),
              ),
              items: [
                for (final lib in libraries)
                  DropdownMenuItem(
                    value: lib.id,
                    child: Text(lib.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() {
                _libraryId = id;
                // A book from the old library doesn't belong here
                _book = null;
                _search.clear();
              }),
            ),
            const SizedBox(height: 12),
            if (_libraryId case final libraryId?)
              _book == null
                  ? _BookSearch(
                      libraryId: libraryId,
                      controller: _search,
                      onChanged: () => setState(() {}),
                      onPicked: (book) => setState(() => _book = book),
                    )
                  : _PickedBook(
                      book: _book!,
                      onChange: () => setState(() => _book = null),
                    ),
            const SizedBox(height: 12),
            if (_borrower case final borrower?)
              _PickedPerson(user: borrower, onChange: _clearBorrower)
            else ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                onChanged: _onNameChanged,
                decoration: const InputDecoration(
                  hintText: 'Their name, or @username if they\'re on the app',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              for (final user in _matches.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(user: user, radius: 18),
                  title: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('@${user.username}'),
                  onTap: () => _pickBorrower(user),
                ),
            ],
            const SizedBox(height: 4),
            LoanDateRow(
              icon: Icons.event_available_outlined,
              label: 'Lent on',
              date: _lentOn,
              onTap: _pickLentOn,
            ),
            LoanDateRow(
              icon: Icons.event_repeat_outlined,
              label: 'Return by',
              date: _dueOn,
              onTap: _pickDue,
              onClear: () => setState(() => _dueOn = null),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add a note, like a phone number (optional)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(_saving ? 'Saving...' : 'Lend'),
            ),
          ],
        ],
      ),
    );
  }
}

// A search box with matching books under it; only books with a free copy
// can be picked
class _BookSearch extends ConsumerWidget {
  final String libraryId;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final ValueChanged<BookModel> onPicked;

  const _BookSearch({
    required this.libraryId,
    required this.controller,
    required this.onChanged,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    final query = controller.text;
    final results = query.trim().isEmpty
        ? null
        : ref.watch(
            bookQuerySearchProvider((libraryId: libraryId, query: query)),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            hintText: 'Search the library by title or author',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        if (results != null)
          results.when(
            data: (books) => books.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No matching books', style: muted),
                  )
                : Column(
                    children: [
                      for (final book in books.take(6))
                        _BookTile(
                          book: book,
                          onTap: book.availableCopies > 0
                              ? () => onPicked(book)
                              : null,
                        ),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Couldn't search, check your connection",
                style: muted,
              ),
            ),
          ),
      ],
    );
  }
}

// The chosen book, with a way to pick another
class _PickedBook extends StatelessWidget {
  final BookModel book;
  final VoidCallback onChange;

  const _PickedBook({required this.book, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _BookTile(
          book: book,
          trailing: TextButton(
            onPressed: onChange,
            child: const Text('Change'),
          ),
        ),
      ),
    );
  }
}

// The app user the book goes to, with a way to pick someone else
class _PickedPerson extends StatelessWidget {
  final UserModel user;
  final VoidCallback onChange;

  const _PickedPerson({required this.user, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: UserAvatar(user: user, radius: 18),
        title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('@${user.username}'),
        trailing: TextButton(onPressed: onChange, child: const Text('Change')),
      ),
    );
  }
}

// Cover, title and how many copies are free. Greyed out with no onTap.
class _BookTile extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _BookTile({required this.book, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final coverUrl = book.coverUrl;
    final free = book.availableCopies;

    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, color: AppColors.hint, size: 18)),
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: trailing != null || onTap != null,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 32,
          height: 48,
          child: coverUrl == null
              ? placeholder
              : Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        free > 0
            ? '$free of ${book.noOfCopies} on the shelf'
            : 'All copies are out',
      ),
      trailing: trailing,
    );
  }
}
