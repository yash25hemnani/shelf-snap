import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ScannerCameraView extends StatelessWidget {
  final Future<CameraController> camera;

  const ScannerCameraView({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: camera,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Can't open the camera\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final controller = snapshot.data!;
        final previewSize = controller.value.previewSize!;

        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}
