import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  final int pending;
  final int maxPending;
  final VoidCallback onPressed;

  const ShutterButton({
    super.key,
    required this.pending,
    required this.maxPending,
    required this.onPressed,
  });

  bool get _full => pending >= maxPending;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _full ? null : onPressed,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _full ? Colors.white54 : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: pending > 0
                    ? Center(
                        child: Text(
                          '$pending/$maxPending',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            if (pending > 0)
              const IgnorePointer(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
