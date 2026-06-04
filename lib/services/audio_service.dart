import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
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

    await _recorder.openRecorder();

    final streamCtrl = StreamController<Food>();
    _audioSub = streamCtrl.stream.listen((food) {
      if (food is FoodData && food.data != null) {
        final freq = _detector.feed(Uint8List.fromList(food.data!));
        if (!_pitchController.isClosed) {
          _pitchController.add(freq);
        }
      }
    });

    await _recorder.startRecorderToStream(
      codec: Codec.pcm16,
      toStream: streamCtrl.sink,
      sampleRate: 44100,
      numChannels: 1,
    );

    _isRunning = true;
    return true;
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _recorder.stopRecorder();
    await _audioSub?.cancel();
    await _recorder.closeRecorder();
    _isRunning = false;
  }

  void dispose() {
    stop();
    _pitchController.close();
  }
}
