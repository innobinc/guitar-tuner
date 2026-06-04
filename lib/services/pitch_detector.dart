import 'dart:typed_data';

class PitchDetector {
  static const double _threshold = 0.10;
  static const int _bufferSize = 4096;
  static const int _sampleRate = 44100;

  final List<double> _accumulator = [];

  // Feed raw PCM16 bytes; returns a frequency in Hz when a full buffer is ready, else null.
  double? feed(Uint8List bytes) {
    final samples = Int16List.sublistView(bytes);
    for (final s in samples) {
      _accumulator.add(s / 32768.0);
    }
    if (_accumulator.length < _bufferSize) return null;

    final buffer = _accumulator.sublist(0, _bufferSize);
    _accumulator.removeRange(0, _bufferSize ~/ 2); // 50% overlap
    return _yin(buffer);
  }

  double? _yin(List<double> buffer) {
    final half = buffer.length ~/ 2;
    final yin = List<double>.filled(half, 0.0);

    // Difference function
    for (int tau = 1; tau < half; tau++) {
      for (int i = 0; i < half; i++) {
        final d = buffer[i] - buffer[i + tau];
        yin[tau] += d * d;
      }
    }

    // Cumulative mean normalized difference
    yin[0] = 1.0;
    double running = 0.0;
    for (int tau = 1; tau < half; tau++) {
      running += yin[tau];
      yin[tau] *= tau / running;
    }

    // Absolute threshold — find first dip below threshold
    int tau = 2;
    while (tau < half) {
      if (yin[tau] < _threshold) {
        while (tau + 1 < half && yin[tau + 1] < yin[tau]) {
          tau++;
        }
        break;
      }
      tau++;
    }

    if (tau >= half || yin[tau] >= _threshold) return null;

    // Parabolic interpolation for sub-sample accuracy
    double betterTau;
    if (tau > 0 && tau < half - 1) {
      final s0 = yin[tau - 1], s1 = yin[tau], s2 = yin[tau + 1];
      final denom = 2 * (2 * s1 - s2 - s0);
      betterTau = denom.abs() < 1e-10 ? tau.toDouble() : tau + (s2 - s0) / denom;
    } else {
      betterTau = tau.toDouble();
    }

    final freq = _sampleRate / betterTau;
    // Sanity check: guitar range ~70 Hz – 400 Hz
    if (freq < 70 || freq > 400) return null;
    return freq;
  }
}
