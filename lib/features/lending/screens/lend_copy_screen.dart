import 'package:flutter/material.dart';
import 'package:shelf_snap/features/lending/forms/lend_copy_form.dart';

// Records a loan made outside the app, to an app user or a typed name.
// Pops with the borrower's name once the loan is saved.
class LendCopyScreen extends StatelessWidget {
  const LendCopyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lend a book'),
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
        titleSpacing: 0,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: LendCopyForm(),
        ),
      ),
    );
  }
}
