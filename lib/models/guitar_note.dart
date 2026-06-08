import 'dart:math';

class GuitarNote {
  final String name;
  final int stringNum; // 1 = high e, 6 = low E
  final double frequency;

  const GuitarNote(this.name, this.stringNum, this.frequency);

  static const List<GuitarNote> standard = [
    GuitarNote('E2', 6, 82.41),
    GuitarNote('A2', 5, 110.00),
    GuitarNote('D3', 4, 146.83),
    GuitarNote('G3', 3, 196.00),
    GuitarNote('B3', 2, 246.94),
    GuitarNote('e4', 1, 329.63),
  ];

  static double centsDiff(double detected, double target) {
    return 1200.0 * log(detected / target) / ln2;
  }

  // Octave multipliers tried against the detected frequency before matching.
  // Phone mics roll off below ~150 Hz, so pitch detection on the low strings
  // (E2/A2) often locks onto a harmonic instead of the fundamental. Trying
  // octave-shifted variants and keeping whichever lines up best with a known
  // guitar note corrects that without affecting frequencies already close
  // to their target (shift 1.0 wins those by a wide margin).
  static const List<double> _octaveShifts = [1.0, 0.5, 2.0, 1.0 / 3.0, 3.0];

  // Returns (nearest note, cents deviation). Negative = flat, positive = sharp.
  static (GuitarNote, double) nearest(double frequency,
      {int? restrictToString}) {
    final candidates = restrictToString == null
        ? standard
        : standard.where((n) => n.stringNum == restrictToString).toList();
    if (candidates.isEmpty) return nearest(frequency);

    GuitarNote best = candidates.first;
    double bestCents = double.infinity;
    for (final shift in _octaveShifts) {
      final shifted = frequency * shift;
      for (final note in candidates) {
        final c = centsDiff(shifted, note.frequency);
        if (c.abs() < bestCents.abs()) {
          best = note;
          bestCents = c;
        }
      }
    }
    return (best, bestCents);
  }
}
