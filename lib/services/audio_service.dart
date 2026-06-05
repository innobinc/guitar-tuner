import 'dart:async';
import 'dart:typed_data';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';

class AudioService {
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

    final micStream = await MicStream.microphone(
      sampleRate: 44100,
      audioFormat: AudioFormat.ENCODING_PCM_16BIT,
      channelConfig: ChannelConfig.CHANNEL_IN_MONO,
    );

    if (micStream == null) return false;

    _audioSub = micStream.listen((rawData) {
      final bytes = rawData is Uint8List
          ? rawData
          : Uint8List.fromList(rawData.cast<int>());
      final freq = _detector.feed(bytes);
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
    await MicStream.destroy();
    _isRunning = false;
  }

  void dispose() {
    stop();
    _pitchController.close();
  }
}
