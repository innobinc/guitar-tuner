import 'package:flutter/material.dart';
import '../models/guitar_note.dart';

class NoteDisplay extends StatelessWidget {
  final GuitarNote? note;
  final double cents;
  final bool listening;

  const NoteDisplay({
    super.key,
    required this.note,
    required this.cents,
    required this.listening,
  });

  @override
  Widget build(BuildContext context) {
    final inTune = note != null && cents.abs() < 5;
    final noteColor = inTune
        ? const Color(0xFF66BB6A)
        : (note == null ? Colors.white24 : Colors.white);

    String statusText;
    Color statusColor;
    if (!listening) {
      statusText = 'Tap mic to start';
      statusColor = Colors.white38;
    } else if (note == null) {
      statusText = 'Listening...';
      statusColor = Colors.white38;
    } else if (inTune) {
      statusText = 'IN TUNE';
      statusColor = const Color(0xFF66BB6A);
    } else if (cents < 0) {
      statusText = 'FLAT';
      statusColor = const Color(0xFF42A5F5);
    } else {
      statusText = 'SHARP';
      statusColor = const Color(0xFFEF5350);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          note?.name ?? '--',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w300,
            color: noteColor,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          note != null
              ? '${cents >= 0 ? '+' : ''}${cents.round()}¢'
              : '',
          style: const TextStyle(
            fontSize: 22,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.4)),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              color: statusColor,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
