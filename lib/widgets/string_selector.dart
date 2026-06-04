import 'package:flutter/material.dart';
import '../models/guitar_note.dart';

class StringSelector extends StatelessWidget {
  final int? selectedString; // null = AUTO
  final ValueChanged<int?> onSelect;

  const StringSelector({
    super.key,
    required this.selectedString,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SELECT STRING',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white30,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chip(context, null, 'AUTO'),
            const SizedBox(width: 6),
            ...GuitarNote.standard.reversed.map(
              (note) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _chip(context, note.stringNum, note.name),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, int? stringNum, String label) {
    final selected = selectedString == stringNum;
    return GestureDetector(
      onTap: () => onSelect(stringNum),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: stringNum == null ? 52 : 44,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF66BB6A)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF66BB6A)
                : Colors.white12,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : Colors.white60,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
