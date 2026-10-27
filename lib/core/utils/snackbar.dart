import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';

// Replaces any visible snackbar with a new one.
// Capture the messenger before an await when the widget may unmount:
//   final messenger = ScaffoldMessenger.of(context);
//   await ...;
//   messenger.showMessage('Done');
extension SnackBarMessenger on ScaffoldMessengerState {
  void showMessage(String message) {
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showError(String message) {
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }
}
