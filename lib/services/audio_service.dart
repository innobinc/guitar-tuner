import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';

class AudioService {
  static const _channel = EventChannel('com.guitartuner.guitar_tuner/audio');
  final PitchDetector _detector = PitchDetector();
  final StreamController<double?> _pitchController =
      StreamController<double?>.broadcast();
  StreamSubscription? _audioSub;
  bool _isRunning = false;

  Stream<double?> get pitchStream => _pitchController.stream;

  Future<bool> start() async {
    if (_isRunning) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

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
          final freq = _detector.feed(bytes);
          if (!_pitchController.isClosed) _pitchController.add(freq);
        },
        onError: (error) {
          // Native error — stop gracefully
          _isRunning = false;
        },
        cancelOnError: true,
      );
      _isRunning = true;
      return true;
    } on PlatformException {
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
  }
}
