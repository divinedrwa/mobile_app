import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

enum GuardConfirmTone { normal, warning, danger }

/// Simple confirm/cancel — thumb-friendly replacement for [AlertDialog].
Future<bool> showGuardConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  GuardConfirmTone tone = GuardConfirmTone.normal,
  IconData? icon,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GuardConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
      icon: icon,
    ),
  );
  return result ?? false;
}

/// Single-line text prompt (e.g. patrol start location).
Future<String?> showGuardTextPromptSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required String fieldLabel,
  String fieldHint = '',
  String confirmLabel = 'Confirm',
  String? initialValue,
}) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GuardTextPromptSheet(
      title: title,
      subtitle: subtitle,
      fieldLabel: fieldLabel,
      fieldHint: fieldHint,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
  return result;
}

class GuardCheckpointInput {
  const GuardCheckpointInput({
    required this.location,
    this.notes,
    this.issuesFound = false,
  });

  final String location;
  final String? notes;
  final bool issuesFound;
}

/// Patrol checkpoint form — location, notes, issues toggle.
Future<GuardCheckpointInput?> showGuardCheckpointSheet(
  BuildContext context,
) async {
  final result = await showModalBottomSheet<GuardCheckpointInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _GuardCheckpointSheet(),
  );
  return result;
}

class _GuardSheetShell extends StatelessWidget {
  const _GuardSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: GuardTokens.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GuardConfirmSheet extends StatelessWidget {
  const _GuardConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.tone,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final GuardConfirmTone tone;
  final IconData? icon;

  Color _accent(BuildContext context) {
    switch (tone) {
      case GuardConfirmTone.warning:
        return GuardTokens.warning;
      case GuardConfirmTone.danger:
        return GuardTokens.dangerBrand;
      case GuardConfirmTone.normal:
        return GuardTokens.guardAccentDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return _GuardSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: GuardTokens.headingStyle(context).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GuardTokens.bodyStyle(context).copyWith(
              color: GuardTokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(GuardTokens.btnSecondaryH),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
                    ),
                  ),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(GuardTokens.btnSecondaryH),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuardTextPromptSheet extends StatefulWidget {
  const _GuardTextPromptSheet({
    required this.title,
    this.subtitle,
    required this.fieldLabel,
    required this.fieldHint,
    required this.confirmLabel,
    this.initialValue,
  });

  final String title;
  final String? subtitle;
  final String fieldLabel;
  final String fieldHint;
  final String confirmLabel;
  final String? initialValue;

  @override
  State<_GuardTextPromptSheet> createState() => _GuardTextPromptSheetState();
}

class _GuardTextPromptSheetState extends State<_GuardTextPromptSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: widget.fieldLabel,
      hintText: widget.fieldHint.isEmpty ? null : widget.fieldHint,
      filled: true,
      fillColor: isDark
          ? GuardTokens.darkSurface.withValues(alpha: 0.55)
          : GuardTokens.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        borderSide: BorderSide(
          color: isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        borderSide: const BorderSide(color: GuardTokens.guardAccent, width: 1.6),
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return _GuardSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: GuardTokens.headingStyle(context).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              style: GuardTokens.captionStyle(context).copyWith(
                color: GuardTokens.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(context),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            style: GuardTokens.primaryFilled(context),
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _GuardCheckpointSheet extends StatefulWidget {
  const _GuardCheckpointSheet();

  @override
  State<_GuardCheckpointSheet> createState() => _GuardCheckpointSheetState();
}

class _GuardCheckpointSheetState extends State<_GuardCheckpointSheet> {
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _issuesFound = false;

  @override
  void dispose() {
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context, String label, {String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDark
          ? GuardTokens.darkSurface.withValues(alpha: 0.55)
          : GuardTokens.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        borderSide: BorderSide(
          color: isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        borderSide: const BorderSide(color: GuardTokens.guardAccent, width: 1.6),
      ),
    );
  }

  void _submit() {
    final loc = _location.text.trim();
    if (loc.isEmpty) return;
    Navigator.pop(
      context,
      GuardCheckpointInput(
        location: loc,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        issuesFound: _issuesFound,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GuardSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log checkpoint',
            style: GuardTokens.headingStyle(context).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Where are you on the patrol route?',
            style: GuardTokens.captionStyle(context).copyWith(
              color: GuardTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _location,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(
              context,
              'Location',
              hint: 'e.g. Parking B2, Pool area',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(context, 'Notes', hint: 'Optional'),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Issues found',
              style: GuardTokens.bodyStyle(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            value: _issuesFound,
            onChanged: (v) => setState(() => _issuesFound = v ?? false),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            style: GuardTokens.primaryFilled(context),
            child: const Text('Log checkpoint'),
          ),
        ],
      ),
    );
  }
}
