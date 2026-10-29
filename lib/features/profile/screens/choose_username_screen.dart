import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/profile/repositories/user_repository.dart';

// Shown by AuthGate when a signed-in user has no users/{uid} profile yet
class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() =>
      _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  late final List<String> _seeds;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUser!.uid;
    _seeds = List.generate(8, (i) => '${uid}_$i');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final user = AuthService().currentUser!;
    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text.trim().toLowerCase();

    try {
      await ref
          .read(userRepositoryProvider)
          .claimUsername(
            UserModel(
              uid: user.uid,
              username: username,
              name: _nameController.text.trim(),
              email: (user.email ?? '').toLowerCase(),
              avatarSeed: _seeds[_selected],
              createdAt: DateTime.now(),
            ),
          );
      // AuthGate swaps to Home once the profile doc appears
    } on UsernameTakenException {
      _showError('@$username is taken, try another');
    } catch (e) {
      _showError("Couldn't save, check your connection");
    } finally {
      // The screen may already be gone after a successful save
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Scrolls so the keyboard doesn't cause overflow
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/images/signup.png', height: 170),
                  const SizedBox(height: 24),
                  Text(
                    'Pick a username',
                    textAlign: TextAlign.center,
                    // GoogleFonts.dmSans so the w700 font file loads
                    style: GoogleFonts.dmSans(
                      textStyle: text.headlineMedium,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is how friends find you and invite you.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      textStyle: text.bodyMedium,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  TextFormField(
                    controller: _usernameController,
                    validator: UserModel.validateUsername,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'username',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(
                      hintText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _continue,
                    child: _isLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 8),
                  // Lets someone on the wrong account back out
                  TextButton(
                    onPressed: () => AuthService().signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
