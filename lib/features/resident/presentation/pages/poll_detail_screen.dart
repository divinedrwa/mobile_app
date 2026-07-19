import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/telemetry/business_analytics.dart';
import '../../data/models/poll_model.dart';
import '../../data/providers/content_provider.dart';

/// Poll Detail & Voting Screen
class PollDetailScreen extends ConsumerStatefulWidget {
  final PollModel poll;

  const PollDetailScreen({
    super.key,
    required this.poll,
  });

  @override
  ConsumerState<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends ConsumerState<PollDetailScreen> {
  String? _selectedOptionId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedOptionId = widget.poll.myVoteId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Text(
          'Poll Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DesignColors.primary,
                    DesignColors.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badges
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      _buildBadge(
                        widget.poll.isActive ? 'ACTIVE' : 'CLOSED',
                        widget.poll.isActive ? DesignColors.success : Colors.grey,
                      ),
                      if (widget.poll.hasVoted)
                        _buildBadge('YOU VOTED', Colors.orange),
                      if (widget.poll.isExpired)
                        _buildBadge('EXPIRED', Colors.red),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Question
                  Text(
                    widget.poll.question,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Meta Info
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.poll.totalVotes} total votes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(widget.poll.createdAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            
            // Options
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.poll.hasVoted ? 'Poll Results' : 'Choose an option',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Options List
                  ...widget.poll.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final percentage = option.getPercentage(widget.poll.totalVotes);
                    final isSelected = _selectedOptionId == option.id;
                    final isMyVote = widget.poll.myVoteId == option.id;

                    return _buildOptionCard(
                      option,
                      index,
                      percentage,
                      isSelected,
                      isMyVote,
                    );
                  }),
                  
                  // Expiry Info
                  if (widget.poll.expiresAt != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: widget.poll.isExpired
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: DesignRadius.borderMD,
                        border: Border.all(
                          color: widget.poll.isExpired
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.poll.isExpired
                                ? Icons.error
                                : Icons.event,
                            color: widget.poll.isExpired
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.poll.isExpired
                                  ? 'This poll has ended'
                                  : 'Ends on ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.poll.expiresAt!)}',
                              style: TextStyle(
                                color: widget.poll.isExpired
                                    ? Colors.red
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
      bottomNavigationBar: widget.poll.canVote && _selectedOptionId != null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: DesignColors.surface,
                border: Border(top: BorderSide(color: DesignColors.borderLight.withValues(alpha: 0.9))),
                boxShadow: DesignElevation.sm,
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(DesignSpacing.lg, 0, DesignSpacing.lg, DesignSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md),
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submitVote,
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md + 2),
                      shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('Submit Vote', style: DesignTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildOptionCard(
    PollOption option,
    int index,
    double percentage,
    bool isSelected,
    bool isMyVote,
  ) {
    final showResults = widget.poll.hasVoted || !widget.poll.canVote;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: DesignColors.surface,
        borderRadius: DesignRadius.borderLG,
        child: InkWell(
          onTap: widget.poll.canVote
              ? () => setState(() => _selectedOptionId = option.id)
              : null,
          borderRadius: DesignRadius.borderLG,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: DesignRadius.borderLG,
              border: Border.all(
                color: isSelected
                    ? DesignColors.primary
                    : (isMyVote && showResults)
                        ? DesignColors.success
                        : DesignColors.borderLight,
                width: isSelected || (isMyVote && showResults) ? 2 : 1,
              ),
              boxShadow: DesignElevation.sm,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Radio/Check Icon
                  if (widget.poll.canVote)
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? DesignColors.primary : Colors.grey,
                    )
                  else if (isMyVote)
                    Icon(
                      Icons.check_circle,
                      color: DesignColors.success,
                    )
                  else
                    const Icon(
                      Icons.circle_outlined,
                      color: Colors.grey,
                    ),
                  
                  const SizedBox(width: AppSpacing.sm),
                  
                  // Option Text
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        fontWeight: isSelected || isMyVote
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  // Percentage & Votes
                  if (showResults) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isMyVote ? DesignColors.success : null,
                          ),
                        ),
                        Text(
                          '${option.votes} votes',
                          style: TextStyle(
                            fontSize: 12,
                            color: DesignColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              
              // Progress Bar
              if (showResults) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: DesignRadius.borderXS,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage / 100),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: DesignColors.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMyVote ? DesignColors.success : DesignColors.primary,
                        ),
                        minHeight: 8,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    ).animate().fadeIn(
          duration: 300.ms,
          delay: DesignAnimations.staggerFor(index + 2),
        );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: DesignRadius.borderXS,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _submitVote() async {
    if (_selectedOptionId == null) return;
    setState(() {
      _isSubmitting = true;
    });

    final errorMsg = await ref.read(pollVoteProvider.notifier).vote(
          pollId: widget.poll.id,
          optionId: _selectedOptionId!,
        );
    ref.invalidate(pollsProvider);

    if (mounted) {
      if (errorMsg == null) {
        DesignHaptics.success();
        unawaited(BusinessAnalytics.track(BusinessAnalytics.pollVote));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg ?? 'Vote submitted successfully!',
          ),
          backgroundColor:
              errorMsg != null ? DesignColors.error : DesignColors.success,
        ),
      );
      if (errorMsg == null) context.pop();
    }
    if (mounted) setState(() => _isSubmitting = false);
  }
}
