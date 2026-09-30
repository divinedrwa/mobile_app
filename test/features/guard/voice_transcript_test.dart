import 'package:flutter_test/flutter_test.dart';
import 'package:divine_app/features/guard/voice/voice_transcript.dart';

void main() {
  final t0 = DateTime(2026, 9, 30, 19);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('keeps words said before a pause when the recognizer starts afresh', () {
    final v = VoiceTranscript();
    v.add('Ra', at: at(0));
    v.add('Ramesh', at: at(300));
    // Pause, then the recognizer reports only the new utterance.
    v.add('98765', at: at(3000));
    v.add('98765 43210', at: at(3400));
    v.add('flat', at: at(6000));
    v.add('flat A 25', at: at(6400));
    expect(v.text, 'Ramesh 98765 43210 flat A 25');
  });

  test('partial results that grow replace the current phrase', () {
    final v = VoiceTranscript();
    v.add('Ramesh', at: at(0));
    v.add('Ramesh Kumar', at: at(400));
    v.add('Ramesh Kumar delivery', at: at(900));
    expect(v.text, 'Ramesh Kumar delivery');
  });

  test('quick correction of the first word is not a new phrase', () {
    final v = VoiceTranscript();
    v.add('Rakesh', at: at(0));
    v.add('Ramesh', at: at(250));
    expect(v.text, 'Ramesh');
  });

  test('recognizer that repeats the whole session does not duplicate', () {
    final v = VoiceTranscript();
    v.add('Ramesh', at: at(0));
    v.add('98765', at: at(3000));
    v.add('Ramesh 98765 flat A 25', at: at(6000));
    expect(v.text, 'Ramesh 98765 flat A 25');
  });

  test('a final result closes the phrase; next round appends', () {
    final v = VoiceTranscript();
    v.add('Ramesh', at: at(0), isFinal: true);
    v.add('delivery', at: at(200));
    expect(v.text, 'Ramesh delivery');
  });

  test('typed correction replaces everything', () {
    final v = VoiceTranscript();
    v.add('Ramesh', at: at(0));
    v.replaceAll('Suresh 98765 43210');
    v.add('flat A 25', at: at(5000));
    expect(v.text, 'Suresh 98765 43210 flat A 25');
  });
}
