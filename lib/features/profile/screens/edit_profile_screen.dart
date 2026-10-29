import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/profile/repositories/user_repository.dart';

// Change the username and pick a different avatar
class EditProfileScreen extends ConsumerStatefulWidget {
  final UserModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  late final List<String> _seeds;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _usernameController.text = profile.username;

    // The current avatar comes first, so it starts selected.
    // Older accounts have no seed and use the uid instead.
    final current = profile.avatarSeed ?? profile.uid;
    _seeds = [
      current,
      ...List.generate(
        8,
        (i) => '${profile.uid}_$i',
      ).where((seed) => seed != current),
    ].take(8).toList();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim().toLowerCase();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(
            widget.profile,
            username: username,
            avatarSeed: _seeds[_selected],
          );
      // The profile stream refreshes the profile page
      navigator.pop();
      messenger.showMessage('Profile updated');
    } on UsernameTakenException {
      messenger.showError('@$username is taken, try another');
    } catch (e) {
      messenger.showError("Couldn't save, check your connection");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        titleTextStyle: text.titleMedium,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Avatar', style: text.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _seeds.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _selected = i),
                        // Every avatar has a ring so the picked one doesn't change size
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _selected
                                  ? AppColors.primary
                                  : AppColors.background,
                              width: 3,
                            ),
                          ),
                          child: ClayAvatar(seed: _seeds[i], radius: 28),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Username', style: text.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  validator: UserModel.validateUsername,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: 'username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _save,
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
