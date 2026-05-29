/// Poll model
class PollModel {
  final String id;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? createdBy;
  final bool hasVoted;
  final String? myVoteId;
  final int totalVotes;

  PollModel({
    required this.id,
    required this.question,
    required this.options,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.createdBy,
    this.hasVoted = false,
    this.myVoteId,
    this.totalVotes = 0,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) {
    // Backend sends `title`; legacy clients may send `question`.
    final question = (json['question'] ?? json['title']) as String? ?? '';

    // Backend sends `endDate`; legacy may send `expiresAt`.
    final expiresRaw = json['expiresAt'] ?? json['endDate'];

    // Backend sends `status` enum (ACTIVE/CLOSED/DRAFT); legacy may send `isActive` bool.
    final statusRaw = json['status'];
    final isActive = statusRaw is String
        ? statusRaw == 'ACTIVE'
        : (json['isActive'] as bool? ?? true);

    // Parse options — backend includes _count for votes
    final rawOptions = json['options'] as List? ?? [];

    // totalVotes can be explicit or from _count
    final countMap = json['_count'] as Map<String, dynamic>?;
    final totalVotes =
        json['totalVotes'] as int? ?? countMap?['votes'] as int? ?? 0;

    return PollModel(
      id: json['id'] as String,
      question: question,
      options: rawOptions.map((opt) => PollOption.fromJson(opt as Map<String, dynamic>)).toList(),
      createdAt: DateTime.parse((json['createdAt'] ?? DateTime.now().toIso8601String()).toString()),
      expiresAt: expiresRaw != null ? DateTime.tryParse(expiresRaw.toString()) : null,
      isActive: isActive,
      createdBy: json['createdBy'] as String?,
      hasVoted: json['hasVoted'] as bool? ?? false,
      myVoteId: json['myVoteId'] as String? ??
          json['myVoteOptionId'] as String?,
      totalVotes: totalVotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((opt) => opt.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      'isActive': isActive,
      if (createdBy != null) 'createdBy': createdBy,
      'hasVoted': hasVoted,
      if (myVoteId != null) 'myVoteId': myVoteId,
      'totalVotes': totalVotes,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get canVote => isActive && !hasVoted && !isExpired;
}

/// Poll option model
class PollOption {
  final String id;
  final String text;
  final int votes;

  PollOption({
    required this.id,
    required this.text,
    this.votes = 0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    // Backend sends `optionText`; legacy may send `text`.
    final text = (json['text'] ?? json['optionText']) as String? ?? '';

    // Vote count can be in `votes` or `_count.votes`.
    final countMap = json['_count'] as Map<String, dynamic>?;
    final votes = json['votes'] as int? ?? countMap?['votes'] as int? ?? 0;

    return PollOption(
      id: json['id'] as String,
      text: text,
      votes: votes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
    };
  }

  double getPercentage(int total) {
    if (total == 0) return 0;
    return (votes / total) * 100;
  }
}
