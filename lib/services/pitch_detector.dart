import 'dart:typed_data';

class PitchDetector {
  static const double _threshold = 0.15; // raised: real mics need more tolerance
  static const int _bufferSize = 8192;   // doubled: better low-freq resolution
  static const int _sampleRate = 44100;

  final List<double> _accumulator = [];

  // Feed raw PCM16LE bytes; returns frequency in Hz when buffer is ready, else null.
  // Uses ByteData (byte-addressable) instead of Int16List.sublistView because
  // chunks from the platform stream can start at odd byte offsets, which
  // Int16List.sublistView rejects with "Offset must be a multiple of BYTES_PER_ELEMENT".
  double? feed(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final sampleCount = bd.lengthInBytes ~/ 2;
    for (int i = 0; i < sampleCount; i++) {
      _accumulator.add(bd.getInt16(i * 2, Endian.little) / 32768.0);
    }
    if (_accumulator.length < _bufferSize) return null;

    final buffer = _accumulator.sublist(0, _bufferSize);
    _accumulator.removeRange(0, _bufferSize ~/ 2);
    return _yin(buffer);
  }

  double? _yin(List<double> buffer) {
    // Check signal level — skip if too quiet
    double rms = 0;
    for (final s in buffer) rms += s * s;
    rms = (rms / buffer.length).toDouble();
    if (rms < 0.0001) return null;

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
      if (running == 0) { yin[tau] = 1.0; continue; }
      yin[tau] *= tau / running;
    }

    // Absolute threshold
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

    // Parabolic interpolation
    double betterTau;
    if (tau > 0 && tau < half - 1) {
      final s0 = yin[tau - 1], s1 = yin[tau], s2 = yin[tau + 1];
      final denom = 2 * (2 * s1 - s2 - s0);
      betterTau = denom.abs() < 1e-10 ? tau.toDouble() : tau + (s2 - s0) / denom;
    } else {
      betterTau = tau.toDouble();
    }
    if (betterTau <= 0) return null;

    final freq = _sampleRate / betterTau;
    if (freq < 60 || freq > 500) return null; // slightly wider guitar range
    return freq;
  }
}
