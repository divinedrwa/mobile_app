import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/design_haptics.dart';
import '../ui/guard_tokens.dart';

/// One shared recognizer: initializing is slow, so it's done once per app run.
final SpeechToText _speech = SpeechToText();
bool? _speechReady;

Future<bool> _ensureSpeech() async {
  if (_speechReady == true) return true;
  try {
    _speechReady = await _speech.initialize();
  } catch (_) {
    _speechReady = false;
  }
  return _speechReady!;
}

/// Live "what's still missing" check for the voice sheet: label → found yet.
typedef GuardVoiceChecklist = Map<String, bool> Function(String text);

/// Opens the voice sheet and returns what the guard said, or null if cancelled.
///
/// [title] tells the guard what to say, e.g. "Say name, mobile and flat".
/// [checklist] shows ticks for each detail heard so far (e.g. Mobile, Flat).
Future<String?> showGuardVoiceSheet(
  BuildContext context, {
  required String title,
  String? example,
  GuardVoiceChecklist? checklist,
}) {
  DesignHaptics.selection();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _GuardVoiceSheet(title: title, example: example, checklist: checklist),
  );
}

class _GuardVoiceSheet extends StatefulWidget {
  const _GuardVoiceSheet({required this.title, this.example, this.checklist});

  final String title;
  final String? example;
  final GuardVoiceChecklist? checklist;

  @override
  State<_GuardVoiceSheet> createState() => _GuardVoiceSheetState();
}

/// listening: mic on · paused: mic off, words kept · unavailable: no recognizer.
enum _VoiceStatus { starting, listening, paused, unavailable }

class _GuardVoiceSheetState extends State<_GuardVoiceSheet>
    with SingleTickerProviderStateMixin {
  /// Android ends a recognition after ~2 s of silence; we quietly start a new one
  /// and keep adding words, so pausing to think doesn't lose the entry.
  static const _silenceLimit = Duration(seconds: 10);
  static const _sessionLimit = Duration(seconds: 90);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  final _editor = TextEditingController();

  _VoiceStatus _status = _VoiceStatus.starting;

  /// Text kept from before (typed corrections), plus the words of each
  /// recognition round keyed by round number. Android often delivers a round's
  /// final words after the next round has started, so late words still land in
  /// their own slot instead of being dropped or doubled.
  String _base = '';
  final SplayTreeMap<int, String> _rounds = SplayTreeMap();
  String? _note;

  /// True while the guard wants the mic on (until Done, pause, or silence).
  bool _wantListening = false;
  DateTime _lastSpeechAt = DateTime.now();
  DateTime _sessionStart = DateTime.now();
  String? _locale;
  int _segment = 0;

  /// Rounds up to this number were folded into [_base] and are ignored.
  int _ignoreUpTo = 0;

  /// The guard typed in the box while paused.
  bool _editorDirty = false;
  Timer? _restartTimer;

  String get _text =>
      [_base, ..._rounds.values].where((s) => s.trim().isNotEmpty).join(' ').trim();

  /// Everything except the round being heard right now (shown in full colour).
  String get _committed => [
        _base,
        for (final e in _rounds.entries)
          if (e.key != _segment || !_wantListening) e.value,
      ].where((s) => s.trim().isNotEmpty).join(' ').trim();

  /// The round being heard right now (shown lighter while listening).
  String get _partial => _wantListening ? (_rounds[_segment] ?? '') : '';

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _wantListening = false;
    _restartTimer?.cancel();
    _pulse.dispose();
    _editor.dispose();
    if (_speech.isListening) unawaited(_speech.cancel());
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() => _status = _VoiceStatus.starting);
    final ok = await _ensureSpeech();
    if (!mounted) return;
    if (!ok) {
      setState(() => _status = _VoiceStatus.unavailable);
      return;
    }
    _locale ??= await _preferredLocale();
    _speech.errorListener = _onError;
    _speech.statusListener = _onStatus;
    _resume();
  }

  /// Turns the mic on and keeps the words already heard.
  void _resume() {
    _commitEdits();
    _wantListening = true;
    _lastSpeechAt = DateTime.now();
    _sessionStart = DateTime.now();
    _note = null;
    _listenSegment();
  }

  Future<void> _listenSegment() async {
    if (!mounted || !_wantListening) return;
    final segment = ++_segment;
    setState(() => _status = _VoiceStatus.listening);
    try {
      await _speech.listen(
        onResult: (r) => _onResult(r, segment),
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      _segmentEnded(const Duration(milliseconds: 600));
    }
  }

  void _onResult(SpeechRecognitionResult r, int segment) {
    if (!mounted || segment <= _ignoreUpTo) return;
    final words = r.recognizedWords.trim();
    if (words.isEmpty) return;
    setState(() {
      _lastSpeechAt = DateTime.now();
      _rounds[segment] = words;
      // Words that arrive just after pausing still show in the edit box.
      if (_status == _VoiceStatus.paused && !_editorDirty) _editor.text = _text;
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    // "done" comes after the round's final words; "notListening" can come
    // before them, so wait longer there to avoid cutting those words off.
    if (status == SpeechToText.doneStatus) {
      _segmentEnded(const Duration(milliseconds: 300));
    } else if (status == SpeechToText.notListeningStatus) {
      _segmentEnded(const Duration(milliseconds: 1200));
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    // no_match / speech_timeout are just silence — keep going.
    final silence = e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout';
    if (!silence) {
      _pauseMic(note: 'Microphone stopped. Tap the mic to continue.');
      return;
    }
    _segmentEnded(const Duration(milliseconds: 300));
  }

  /// A recognition round ended (silence, time limit or result): start another
  /// after [delay] unless the guard is done or has been quiet for a while.
  void _segmentEnded(Duration delay) {
    if (!mounted || !_wantListening) return;
    final now = DateTime.now();
    if (now.difference(_lastSpeechAt) > _silenceLimit ||
        now.difference(_sessionStart) > _sessionLimit) {
      _pauseMic(
        note: _text.isEmpty
            ? "Didn't hear anything. Tap the mic and speak."
            : 'Paused. Tap the mic to add more, or tap Done.',
      );
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () {
      if (mounted && _wantListening && !_speech.isListening) _listenSegment();
    });
  }

  void _pauseMic({String? note}) {
    _wantListening = false;
    _restartTimer?.cancel();
    if (_speech.isListening) unawaited(_speech.stop());
    if (!mounted) return;
    setState(() {
      _status = _VoiceStatus.paused;
      _note = note;
      _editor.text = _text;
      _editorDirty = false;
    });
  }

  /// Keeps corrections the guard typed while paused (they replace what was heard).
  void _commitEdits() {
    if (!_editorDirty) return;
    _base = _editor.text.trim();
    _rounds.clear();
    _ignoreUpTo = _segment;
    _editorDirty = false;
  }

  void _startOver() {
    _pauseMic();
    setState(() {
      _base = '';
      _rounds.clear();
      _ignoreUpTo = _segment;
      _editor.clear();
      _editorDirty = false;
      _note = null;
    });
    _resume();
  }

  void _done() {
    _commitEdits();
    final text = _text;
    _pauseMic();
    DesignHaptics.success();
    Navigator.of(context).pop(text);
  }

  /// Indian English when the phone has it (better for names and numbers).
  Future<String?> _preferredLocale() async {
    try {
      final locales = await _speech.locales();
      for (final id in ['en_IN', 'en-IN', 'hi_IN', 'hi-IN']) {
        if (locales.any((l) => l.localeId == id)) return id;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listening = _status == _VoiceStatus.listening || _status == _VoiceStatus.starting;
    final paused = _status == _VoiceStatus.paused;
    final text = paused ? _editor.text : _text;
    final hasText = text.trim().isNotEmpty;
    final checks = widget.checklist?.call(text);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          GuardTokens.padScreen,
          0,
          GuardTokens.padScreen,
          GuardTokens.padScreen + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GuardTokens.headingStyle(context).copyWith(fontSize: 18),
            ),
            if (widget.example != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.example!,
                textAlign: TextAlign.center,
                style: GuardTokens.captionStyle(context),
              ),
            ],
            const SizedBox(height: 18),
            Center(child: _micButton(listening)),
            const SizedBox(height: 12),
            Text(
              switch (_status) {
                _VoiceStatus.starting => 'Starting microphone…',
                _VoiceStatus.listening => hasText
                    ? 'Listening… take your time, pauses are fine'
                    : 'Listening… speak now',
                _VoiceStatus.paused => _note ?? 'Paused. Tap the mic to add more.',
                _VoiceStatus.unavailable => 'Voice input is not available on this phone. Please type instead.',
              },
              textAlign: TextAlign.center,
              style: GuardTokens.captionStyle(context).copyWith(
                fontWeight: FontWeight.w600,
                color: _status == _VoiceStatus.unavailable ? GuardTokens.warning : null,
              ),
            ),
            if (checks != null && checks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in checks.entries) _CheckPill(label: e.key, done: e.value),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _transcript(theme, paused),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(GuardTokens.btnPrimaryH),
                    ),
                    onPressed: !hasText || _status == _VoiceStatus.unavailable ? null : _startOver,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Clear', maxLines: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: GuardTokens.primaryFilled(context).copyWith(
                      minimumSize: WidgetStateProperty.all(
                        const Size.fromHeight(GuardTokens.btnPrimaryH),
                      ),
                    ),
                    onPressed: hasText ? _done : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Live words while listening; an editable box while paused to fix mistakes.
  Widget _transcript(ThemeData theme, bool paused) {
    final decoration = BoxDecoration(
      color: GuardTokens.guardAccent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
      border: Border.all(color: GuardTokens.guardAccent.withValues(alpha: 0.25)),
    );
    const style = TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w700);
    if (paused) {
      return Container(
        decoration: decoration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: _editor,
          minLines: 2,
          maxLines: 5,
          style: style,
          onChanged: (_) => setState(() => _editorDirty = true),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Your words appear here — tap to correct',
          ),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Text.rich(
        TextSpan(
          children: [
            if (_committed.isNotEmpty) TextSpan(text: '$_committed '),
            TextSpan(
              text: _partial,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            if (_committed.isEmpty && _partial.isEmpty)
              TextSpan(
                text: 'Your words appear here',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
        style: style.copyWith(color: theme.colorScheme.onSurface),
      ),
    );
  }

  Widget _micButton(bool listening) {
    return Semantics(
      button: true,
      label: listening ? 'Pause microphone' : 'Start microphone',
      child: GestureDetector(
        onTap: switch (_status) {
          _VoiceStatus.listening => () => _pauseMic(),
          _VoiceStatus.paused => _resume,
          _ => null,
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = listening ? 1 + _pulse.value * 0.18 : 1.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GuardTokens.guardAccent.withValues(alpha: listening ? 0.16 : 0.08),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listening ? GuardTokens.dangerBrand : GuardTokens.guardAccentDeep,
              boxShadow: [
                BoxShadow(
                  color: GuardTokens.guardAccentDeep.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              listening ? Icons.pause_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

/// "✓ Mobile" once heard, "○ Flat" while still missing.
class _CheckPill extends StatelessWidget {
  const _CheckPill({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? GuardTokens.success : GuardTokens.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? GuardTokens.success.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: done ? 0.5 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Small mic button for a text field's suffix: speaks into [onText].
class GuardMicButton extends StatelessWidget {
  const GuardMicButton({
    super.key,
    required this.title,
    required this.onText,
    this.example,
    this.enabled = true,
  });

  final String title;
  final String? example;
  final bool enabled;
  final ValueChanged<String> onText;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Speak',
      onPressed: !enabled
          ? null
          : () async {
              final text = await showGuardVoiceSheet(context, title: title, example: example);
              if (text != null && text.isNotEmpty) onText(text);
            },
      icon: Icon(Icons.mic_none_rounded, color: GuardTokens.guardAccentDeep),
    );
  }
}
