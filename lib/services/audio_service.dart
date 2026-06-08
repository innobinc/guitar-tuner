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
  StreamController<Uint8List>? _pcmController;
  StreamSubscription? _pcmSub;
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

      _pcmController = StreamController<Uint8List>();
      _pcmSub = _pcmController!.stream.listen((bytes) {
        // Signal level (RMS)
        final samples = Int16List.view(bytes.buffer);
        double sum = 0;
        for (final s in samples) {
          final n = s / 32768.0;
          sum += n * n;
        }
        final rms = sqrt(sum / samples.length);
        if (!_signalController.isClosed) _signalController.add(rms);

        // Pitch detection
        final freq = _detector.feed(bytes);
        if (!_pitchController.isClosed) _pitchController.add(freq);
      });

      await _recorder.startRecorder(
        toStream: _pcmController!.sink,
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
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _pcmController?.close();
    _pcmController = null;
    try { await _recorder.closeRecorder(); } catch (_) {}
  }

  void dispose() {
    stop();
    _pitchController.close();
    _signalController.close();
  }
}
