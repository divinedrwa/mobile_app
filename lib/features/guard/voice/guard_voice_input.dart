import 'dart:async';

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

/// Opens the voice sheet and returns what the guard said, or null if cancelled.
///
/// [title] tells the guard what to say, e.g. "Say name, mobile and flat".
Future<String?> showGuardVoiceSheet(
  BuildContext context, {
  required String title,
  String? example,
}) {
  DesignHaptics.selection();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _GuardVoiceSheet(title: title, example: example),
  );
}

class _GuardVoiceSheet extends StatefulWidget {
  const _GuardVoiceSheet({required this.title, this.example});

  final String title;
  final String? example;

  @override
  State<_GuardVoiceSheet> createState() => _GuardVoiceSheetState();
}

enum _VoiceStatus { starting, listening, done, unavailable, error }

class _GuardVoiceSheetState extends State<_GuardVoiceSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  _VoiceStatus _status = _VoiceStatus.starting;
  String _text = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _pulse.dispose();
    if (_speech.isListening) unawaited(_speech.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _status = _VoiceStatus.starting;
      _text = '';
      _error = null;
    });
    final ok = await _ensureSpeech();
    if (!mounted) return;
    if (!ok) {
      setState(() => _status = _VoiceStatus.unavailable);
      return;
    }
    _speech.errorListener = (SpeechRecognitionError e) {
      if (!mounted) return;
      setState(() {
        _status = _text.isEmpty ? _VoiceStatus.error : _VoiceStatus.done;
        _error = e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout'
            ? "Didn't catch that. Tap the mic and speak again."
            : 'Voice input stopped. Tap the mic to try again.';
      });
    };
    _speech.statusListener = (status) {
      if (!mounted) return;
      if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
        if (_status == _VoiceStatus.listening) {
          setState(() => _status = _text.isEmpty ? _VoiceStatus.error : _VoiceStatus.done);
          _error ??= _text.isEmpty ? "Didn't catch that. Tap the mic and speak again." : null;
        }
      }
    };
    setState(() => _status = _VoiceStatus.listening);
    await _speech.listen(
      onResult: _onResult,
      localeId: await _preferredLocale(),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
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

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() {
      _text = r.recognizedWords;
      if (r.finalResult) _status = _VoiceStatus.done;
    });
    if (r.finalResult && _text.trim().isNotEmpty) {
      DesignHaptics.success();
    }
  }

  void _use() => Navigator.of(context).pop(_text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listening = _status == _VoiceStatus.listening || _status == _VoiceStatus.starting;
    final canUse = _text.trim().isNotEmpty && !listening;

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
            const SizedBox(height: 22),
            Center(child: _micButton(listening)),
            const SizedBox(height: 14),
            Text(
              switch (_status) {
                _VoiceStatus.starting => 'Starting microphone…',
                _VoiceStatus.listening => 'Listening… speak now',
                _VoiceStatus.done => 'Got it. Check and tap Use.',
                _VoiceStatus.unavailable => 'Voice input is not available on this phone.',
                _VoiceStatus.error => _error ?? 'Tap the mic to try again.',
              },
              textAlign: TextAlign.center,
              style: GuardTokens.captionStyle(context).copyWith(
                fontWeight: FontWeight.w600,
                color: _status == _VoiceStatus.error || _status == _VoiceStatus.unavailable
                    ? GuardTokens.warning
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GuardTokens.guardAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                border: Border.all(
                  color: GuardTokens.guardAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _text.isEmpty ? 'Your words appear here' : _text,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: _text.isEmpty ? FontWeight.w500 : FontWeight.w700,
                  color: _text.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(GuardTokens.btnPrimaryH),
                    ),
                    onPressed: listening || _status == _VoiceStatus.unavailable ? null : _start,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Speak again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: GuardTokens.primaryFilled(context).copyWith(
                      minimumSize: WidgetStateProperty.all(
                        const Size.fromHeight(GuardTokens.btnPrimaryH),
                      ),
                    ),
                    onPressed: canUse ? _use : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _micButton(bool listening) {
    return GestureDetector(
      onTap: listening
          ? () => _speech.stop()
          : (_status == _VoiceStatus.unavailable ? null : _start),
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
            color: GuardTokens.guardAccentDeep,
            boxShadow: [
              BoxShadow(
                color: GuardTokens.guardAccentDeep.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
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
