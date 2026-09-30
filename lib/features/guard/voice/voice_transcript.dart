/// Builds one transcript from a speech recognizer's stream of results.
///
/// Recognizers don't agree on what a result contains. Within one listening
/// session Android (speech_to_text ≥ 7.4, which honours `pauseFor`) and iOS
/// start a *new* utterance after the speaker pauses, and the next results hold
/// only the new words — so replacing the text with each result loses what was
/// said before the pause ("Ramesh … 98765" became just "98765"). Other devices
/// keep sending the whole session's words each time.
///
/// [add] tells the two apart: a result that continues or corrects the current
/// utterance replaces it; one that starts afresh after a pause is kept as a new
/// phrase; one that repeats everything so far replaces the whole session.
class VoiceTranscript {
  VoiceTranscript({this.correctionWindow = const Duration(milliseconds: 900)});

  /// Results closer together than this are the recognizer refining the same
  /// words, never a new utterance (the speaker can't pause that fast).
  final Duration correctionWindow;

  final List<String> _phrases = [];
  String _current = '';
  DateTime? _lastAt;

  /// Finished phrases plus the one being heard.
  String get text => [..._phrases, _current].where((s) => s.isNotEmpty).join(' ');

  /// The phrase being heard right now (shown lighter while listening).
  String get current => _current;

  /// Everything before [current].
  String get settled => _phrases.join(' ');

  bool get isEmpty => text.isEmpty;

  void clear() {
    _phrases.clear();
    _current = '';
    _lastAt = null;
  }

  /// Keeps the current phrase for good (end of a listening round).
  void commit() {
    if (_current.isNotEmpty) _phrases.add(_current);
    _current = '';
  }

  /// Replaces everything with text the user typed.
  void replaceAll(String typed) {
    clear();
    final t = typed.trim();
    if (t.isNotEmpty) _phrases.add(t);
  }

  /// Adds one recognizer result. [isFinal] closes the phrase.
  void add(String words, {bool isFinal = false, DateTime? at}) {
    final now = at ?? DateTime.now();
    final next = words.trim();
    final gap = _lastAt == null ? Duration.zero : now.difference(_lastAt!);
    _lastAt = now;
    if (next.isEmpty) return;

    final all = text;
    if (_phrases.isNotEmpty && _startsWith(next, all)) {
      // Recognizer repeats the whole session: take it as the new full text.
      _phrases
        ..clear()
        ..add(next);
      _current = '';
    } else if (_current.isEmpty || _continues(_current, next) || gap < correctionWindow) {
      _current = next;
    } else {
      // Fresh words after a pause: keep what was said before.
      _phrases.add(_current);
      _current = next;
    }
    if (isFinal) commit();
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '').trim();

  static bool _startsWith(String a, String prefix) {
    final na = _norm(a), np = _norm(prefix);
    return np.isNotEmpty && na.startsWith(np);
  }

  /// Same utterance: one extends the other, or both start with the same word
  /// (the recognizer corrected a later word).
  static bool _continues(String prev, String next) {
    final p = _norm(prev), n = _norm(next);
    if (p.isEmpty || n.isEmpty) return true;
    if (n.startsWith(p) || p.startsWith(n)) return true;
    return p.split(' ').first == n.split(' ').first;
  }
}
