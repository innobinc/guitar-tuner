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

  // Returns (nearest note, cents deviation). Negative = flat, positive = sharp.
  static (GuitarNote, double) nearest(double frequency,
      {int? restrictToString}) {
    final candidates = restrictToString == null
        ? standard
        : standard.where((n) => n.stringNum == restrictToString).toList();
    if (candidates.isEmpty) return nearest(frequency);

    GuitarNote best = candidates.first;
    double bestCents = centsDiff(frequency, candidates.first.frequency);
    for (final note in candidates.skip(1)) {
      final c = centsDiff(frequency, note.frequency);
      if (c.abs() < bestCents.abs()) {
        best = note;
        bestCents = c;
      }
    }
    return (best, bestCents);
  }
}
