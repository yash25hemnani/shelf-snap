import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class SpineBoxDetector {
  static const String _modelPath = 'assets/models/spine_detector.tflite';
  static const int _inputSize = 640;

  Interpreter? _interpreter;
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;

    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
    _isLoaded = true;

    print('SpineBoxDetector loaded successfully');
    print('  Input shape:  ${_interpreter!.getInputTensor(0).shape}');
    print('  Input type:   ${_interpreter!.getInputTensor(0).type}');
    print('  Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    print('  Output type:  ${_interpreter!.getOutputTensor(0).type}');
  }

  /// STAGE 2 ONLY — raw inference, no parsing, no swap-fix, no NMS.
  Future<void> debugRunInference(String imagePath) async {
    if (!_isLoaded || _interpreter == null) {
      print('SpineBoxDetector: not loaded, skipping debug inference');
      return;
    }

    final swDecode = Stopwatch()..start();
    final bytes = await File(imagePath).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      print('SpineBoxDetector: failed to decode image');
      return;
    }
    final resized = img.copyResize(original, width: _inputSize, height: _inputSize);
    swDecode.stop();

    final swTensor = Stopwatch()..start();
    final input = List.generate(
      1,
          (_) => List.generate(
        _inputSize,
            (y) => List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    );
    swTensor.stop();

    final output = List.generate(1, (_) => List.generate(6, (_) => List.filled(8400, 0.0)));

    final swRun = Stopwatch()..start();
    _interpreter!.run(input, output);
    swRun.stop();

    print('--- STAGE 2: RAW INFERENCE DEBUG ---');
    print('Decode+resize: ${swDecode.elapsedMilliseconds}ms');
    print('Tensor build:  ${swTensor.elapsedMilliseconds}ms');
    print('Model run:     ${swRun.elapsedMilliseconds}ms');
    print('Total:         ${swDecode.elapsedMilliseconds + swTensor.elapsedMilliseconds + swRun.elapsedMilliseconds}ms');

    final row = output[0];
    for (int r = 0; r < 6; r++) {
      double minV = row[r][0], maxV = row[r][0];
      for (final v in row[r]) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      print('  Row $r -> min=${minV.toStringAsFixed(4)} max=${maxV.toStringAsFixed(4)}');
    }

    int aboveThreshold = 0;
    for (int i = 0; i < 8400; i++) {
      if (row[4][i] > 0.25) aboveThreshold++;
    }
    print('  Raw detections with conf > 0.25: $aboveThreshold (out of 8400)');
    print('--- END STAGE 2 DEBUG ---');
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}