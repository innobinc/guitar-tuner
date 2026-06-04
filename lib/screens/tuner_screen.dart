import 'dart:async';
import 'package:flutter/material.dart';
import '../models/guitar_note.dart';
import '../services/audio_service.dart';
import '../widgets/note_display.dart';
import '../widgets/tuner_needle.dart';
import '../widgets/string_selector.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  final AudioService _audio = AudioService();
  StreamSubscription<double?>? _sub;

  bool _listening = false;
  GuitarNote? _note;
  double _cents = 0;
  int? _selectedString; // null = auto

  @override
  void dispose() {
    _sub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _sub?.cancel();
      await _audio.stop();
      setState(() {
        _listening = false;
        _note = null;
        _cents = 0;
      });
    } else {
      final ok = await _audio.start();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }
      _sub = _audio.pitchStream.listen((freq) {
        if (freq == null) return;
        final (note, cents) =
            GuitarNote.nearest(freq, restrictToString: _selectedString);
        if (mounted) {
          setState(() {
            _note = note;
            _cents = cents.clamp(-50.0, 50.0);
          });
        }
      });
      setState(() => _listening = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'GUITAR TUNER',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white38,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Note display
            NoteDisplay(
              note: _note,
              cents: _cents,
              listening: _listening,
            ),

            const SizedBox(height: 32),

            // Tuner needle
            TunerNeedle(cents: _listening ? _cents : 0),

            const Spacer(flex: 1),

            // Mic button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF2A2A2A),
                  border: Border.all(
                    color: _listening
                        ? const Color(0xFF66BB6A)
                        : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: _listening
                      ? [
                          BoxShadow(
                            color: const Color(0xFF66BB6A).withOpacity(0.35),
                            blurRadius: 20,
                            spreadRadius: 4,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none,
                  color: _listening ? Colors.black : Colors.white54,
                  size: 32,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // String selector
            StringSelector(
              selectedString: _selectedString,
              onSelect: (s) => setState(() => _selectedString = s),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
