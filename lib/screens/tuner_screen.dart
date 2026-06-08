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
  StreamSubscription<double?>? _pitchSub;
  StreamSubscription<double>? _signalSub;

  bool _listening = false;
  GuitarNote? _note;
  double _cents = 0;
  double _smoothedCents = 0;
  double _signalLevel = 0;
  int? _selectedString;

  @override
  void dispose() {
    _pitchSub?.cancel();
    _signalSub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _pitchSub?.cancel();
      await _signalSub?.cancel();
      await _audio.stop();
      setState(() {
        _listening = false;
        _note = null;
        _cents = 0;
        _signalLevel = 0;
      });
    } else {
      final ok = await _audio.start();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_audio.lastError ?? 'Could not start mic')),
          );
        }
        return;
      }

      _signalSub = _audio.signalStream.listen((rms) {
        if (rms < 0) {
          // Native error
          if (mounted) {
            setState(() { _listening = false; _signalLevel = 0; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_audio.lastError ?? 'Audio error'), backgroundColor: Colors.red),
            );
          }
          return;
        }
        if (mounted) setState(() => _signalLevel = rms.clamp(0.0, 1.0));
      });

      _pitchSub = _audio.pitchStream.listen((freq) {
        if (freq == null) return;
        final (note, cents) =
            GuitarNote.nearest(freq, restrictToString: _selectedString);
        final clamped = cents.clamp(-50.0, 50.0);
        if (mounted) {
          setState(() {
            // Snap (don't smooth) across note changes — e.g. switching strings
            // — so the needle doesn't sweep across the whole dial; smooth
            // within the same note to damp frame-to-frame detection jitter.
            _smoothedCents = (_note?.name == note.name)
                ? _smoothedCents * 0.7 + clamped * 0.3
                : clamped;
            _note = note;
            _cents = _smoothedCents;
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

            NoteDisplay(
              note: _note,
              cents: _cents,
              listening: _listening,
            ),

            const SizedBox(height: 32),

            TunerNeedle(cents: _listening ? _cents : 0),

            const SizedBox(height: 16),

            // Signal level bar — shows raw audio is arriving
            if (_listening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('MIC',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white30,
                                letterSpacing: 2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _signalLevel * 5,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation(
                                _signalLevel > 0.01
                                    ? const Color(0xFF66BB6A)
                                    : Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_signalLevel < 0.005 && _listening)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'No signal — check mic permission',
                          style: TextStyle(
                              fontSize: 10, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),

            const Spacer(flex: 1),

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
                          const BoxShadow(
                            color: Color(0x5966BB6A),
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
