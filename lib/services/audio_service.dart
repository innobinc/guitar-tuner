import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';

class AudioService {
  static const _channel = EventChannel('com.guitartuner.guitar_tuner/audio');
  final PitchDetector _detector = PitchDetector();
  final StreamController<double?> _pitchController =
      StreamController<double?>.broadcast();
  final StreamController<double> _signalController =
      StreamController<double>.broadcast();
  StreamSubscription? _audioSub;
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
      _audioSub = _channel.receiveBroadcastStream().listen(
        (dynamic data) {
          final Uint8List bytes;
          if (data is Uint8List) {
            bytes = data;
          } else if (data is List) {
            bytes = Uint8List.fromList(data.cast<int>());
          } else {
            return;
          }

          // Compute RMS for signal level indicator
          final samples = Int16List.view(bytes.buffer);
          double sum = 0;
          for (final s in samples) {
            final norm = s / 32768.0;
            sum += norm * norm;
          }
          final rms = sqrt(sum / samples.length);
          if (!_signalController.isClosed) _signalController.add(rms);

          // Pitch detection
          final freq = _detector.feed(bytes);
          if (!_pitchController.isClosed) _pitchController.add(freq);
        },
        onError: (error) {
          _lastError = error.toString();
          _isRunning = false;
          if (!_signalController.isClosed) _signalController.add(0.0);
        },
        cancelOnError: true,
      );
      _isRunning = true;
      return true;
    } on PlatformException catch (e) {
      _lastError = e.message;
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _audioSub?.cancel();
    _audioSub = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
    _pitchController.close();
    _signalController.close();
  }
}
