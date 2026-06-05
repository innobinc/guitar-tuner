import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
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

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );

    _audioSub = stream.listen((bytes) {
      final freq = _detector.feed(Uint8List.fromList(bytes));
      if (!_pitchController.isClosed) {
        _pitchController.add(freq);
      }
    });

    _isRunning = true;
    return true;
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _audioSub?.cancel();
    await _recorder.stop();
    _isRunning = false;
  }

  void dispose() {
    stop();
    _pitchController.close();
  }
}
