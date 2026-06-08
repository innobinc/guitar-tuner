import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final PitchDetector _detector = PitchDetector();
  final StreamController<double?> _pitchController =
      StreamController<double?>.broadcast();
  final StreamController<double> _signalController =
      StreamController<double>.broadcast();
  StreamController<Food>? _foodController;
  StreamSubscription? _foodSub;
  bool _isRunning = false;
  String? _lastError;

  Stream<double?> get pitchStream => _pitchController.stream;
  Stream<double> get signalStream => _signalController.stream;
  String? get lastError => _lastError;

  Future<bool> start() async {
    if (_isRunning) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _lastError = 'Microphone permission denied';
      return false;
    }

    try {
      await _recorder.openRecorder();

      _foodController = StreamController<Food>();
      _foodSub = _foodController!.stream.listen((food) {
        if (food is FoodData && food.data != null) {
          final bytes = Uint8List.fromList(food.data!);

          // Signal level (RMS)
          final samples = Int16List.view(bytes.buffer);
          double sum = 0;
          for (final s in samples) {
            final n = s / 32768.0;
            sum += n * n;
          }
          final rms = sqrt(sum / samples.length);
          if (!_signalController.isClosed) _signalController.add(rms);

          // Pitch
          final freq = _detector.feed(bytes);
          if (!_pitchController.isClosed) _pitchController.add(freq);
        }
      });

      await _recorder.startRecorder(
        toStream: _foodController!.sink,
        codec: Codec.pcm16,
        sampleRate: 44100,
        numChannels: 1,
      );

      _isRunning = true;
      return true;
    } catch (e) {
      _lastError = e.toString();
      await _cleanup();
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    try { await _recorder.stopRecorder(); } catch (_) {}
    await _cleanup();
    _isRunning = false;
  }

  Future<void> _cleanup() async {
    await _foodSub?.cancel();
    _foodSub = null;
    await _foodController?.close();
    _foodController = null;
    try { await _recorder.closeRecorder(); } catch (_) {}
  }

  void dispose() {
    stop();
    _pitchController.close();
    _signalController.close();
  }
}
