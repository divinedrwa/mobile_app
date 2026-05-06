import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/providers/content_provider.dart';

/// Modern Professional Polls List Screen
class PollsListScreen extends ConsumerStatefulWidget {
  const PollsListScreen({super.key});

  @override
  ConsumerState<PollsListScreen> createState() => _PollsListScreenState();
}

class _PollsListScreenState extends ConsumerState<PollsListScreen> {
  final Map<String, String?> _selectedVotes = {};

  @override
  Widget build(BuildContext context) {
    final pollsState = ref.watch(pollsProvider);

    return Container(
      color: const Color(0xFFF8F9FB),
      child: pollsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: DesignColors.error,
              ),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(pollsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rawPolls) {
          final polls = rawPolls.map(_toPollUiData).toList();
          final activePolls = polls
              .where((p) => p['isActive'] as bool)
              .toList();
          final closedPolls = polls
              .where((p) => !(p['isActive'] as bool))
              .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pollsProvider),
            child: activePolls.isEmpty && closedPolls.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.all(DesignSpacing.lg),
                    children: [
                      if (activePolls.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Active Polls',
                          'Cast your vote',
                          Colors.green,
                        ),
                        const SizedBox(height: 16),
                        ...activePolls.map(
                          (poll) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildModernPollCard(context, poll),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (closedPolls.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Closed Polls',
                          'View results',
                          DesignColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        ...closedPolls.map(
                          (poll) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildModernPollCard(context, poll),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesignColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernPollCard(BuildContext context, Map<String, dynamic> poll) {
    final isActive = poll['isActive'] as bool;
    final hasVoted = poll['hasVoted'] as bool;
    final myOptionId = poll['myOptionId'] as String?;
    final options = (poll['options'] as List).cast<Map<String, dynamic>>();
    final pendingPick = _selectedVotes[poll['id']];
    final effectivePick =
        hasVoted ? myOptionId : pendingPick;

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignRadius.borderXL,
        border: isActive
            ? Border.all(color: Colors.green.shade200, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: DesignRadius.borderXL,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: DesignRadius.borderXL,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.done_all,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CLOSED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isActive && hasVoted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: DesignRadius.borderXL,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.how_to_vote, size: 15, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'YOU VOTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                Icons.people_outline,
                size: 18,
                color: DesignColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${poll['votes']} votes',
                style: TextStyle(
                  fontSize: 13,
                  color: DesignColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Question
          Text(
            poll['question'] as String,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignColors.textPrimary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          if (isActive && hasVoted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.08),
                borderRadius: DesignRadius.borderLG,
                border: Border.all(color: DesignColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: DesignColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your flat already voted. Your choice is highlighted below.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Options
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final oid = option['id'] as String;
            final isSelected =
                effectivePick != null && effectivePick == oid;
            final percentage = option['percentage'] as int;
            final showResults = hasVoted || !isActive;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < options.length - 1 ? 12 : 0,
              ),
              child: _buildPollOption(
                option['text'] as String,
                percentage,
                isSelected,
                showResults,
                () {
                  if (isActive && !hasVoted) {
                    setState(() {
                      _selectedVotes[poll['id']] = oid;
                    });
                  }
                },
              ),
            );
          }),

          // Vote Button
          if (isActive && !hasVoted) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedVotes[poll['id']] != null
                    ? () async {
                        final selectedId = _selectedVotes[poll['id']];
                        if (selectedId == null) return;
                        final errorMsg = await ref
                            .read(pollVoteProvider.notifier)
                            .vote(
                              pollId: poll['id'] as String,
                              optionId: selectedId,
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              errorMsg ??
                                  'Vote submitted successfully!',
                            ),
                            backgroundColor: errorMsg != null
                                ? Colors.red
                                : Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        if (errorMsg == null) {
                          setState(() {
                            _selectedVotes.remove(poll['id'] as String);
                          });
                          ref.invalidate(pollsProvider);
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderLG,
                  ),
                ),
                child: const Text(
                  'Submit Vote',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          // End Date
          if (poll['endDate'] != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Ends ${poll['endDate']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: DesignColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPollOption(
    String text,
    int percentage,
    bool isSelected,
    bool showResults,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: showResults ? null : onTap,
      borderRadius: DesignRadius.borderLG,
      child: Container(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        decoration: BoxDecoration(
          color: showResults
              ? (isSelected
                    ? DesignColors.primary.withValues(alpha: 0.1)
                    : DesignColors.background)
              : DesignColors.background,
          borderRadius: DesignRadius.borderLG,
          border: Border.all(
            color: isSelected
                ? DesignColors.primary
                : (showResults ? Colors.grey[300]! : DesignColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Progress bar background
            if (showResults)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DesignColors.primary.withValues(alpha: 0.15),
                        DesignColors.primary.withValues(alpha: 0.05),
                      ],
                      stops: [percentage / 100, percentage / 100],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

            // Content
            Row(
              children: [
                if (!showResults)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? DesignColors.primary
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isSelected
                          ? DesignColors.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                if (!showResults) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: DesignColors.textPrimary,
                    ),
                  ),
                ),
                if (showResults)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DesignColors.primary
                          : Colors.grey[300],
                      borderRadius: DesignRadius.borderLG,
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : DesignColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(DesignSpacing.xl),
            decoration: BoxDecoration(
              color: DesignColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.poll_outlined, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'No Polls Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new polls',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _toPollUiData(Map<String, dynamic> poll) {
    final optionsRaw = poll['options'] as List? ?? const [];
    final totalVotes = (poll['_count']?['votes'] as num?)?.toInt() ?? 0;
    final options = optionsRaw.whereType<Map>().map((raw) {
      final option = Map<String, dynamic>.from(raw);
      final votes = (option['_count']?['votes'] as num?)?.toInt() ?? 0;
      final pct = totalVotes > 0 ? ((votes * 100) / totalVotes).round() : 0;
      return {
        'id': option['id']?.toString() ?? '',
        'text': option['optionText']?.toString() ?? 'Option',
        'percentage': pct,
      };
    }).toList();

    final status = (poll['status']?.toString() ?? '').toUpperCase();
    final isActive = status == 'ACTIVE';
    final myVoteRaw = poll['myVoteOptionId'];
    final myOptionId =
        myVoteRaw != null && myVoteRaw.toString().trim().isNotEmpty
            ? myVoteRaw.toString()
            : null;
    final hasVotedServer = poll['hasVoted'] == true;
    final hasVoted = hasVotedServer || (myOptionId != null && myOptionId.isNotEmpty);

    return {
      'id': poll['id']?.toString() ?? '',
      'question': poll['title']?.toString() ?? 'Poll',
      'isActive': isActive,
      'votes': totalVotes,
      'myOptionId': myOptionId,
      'hasVoted': hasVoted,
      'endDate': poll['endDate'] != null
          ? DateTime.tryParse(
              poll['endDate'].toString(),
            )?.toLocal().toString().split(' ').first
          : null,
      'options': options,
    };
  }
}
