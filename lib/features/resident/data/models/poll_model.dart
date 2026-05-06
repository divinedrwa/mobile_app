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
    return PollModel(
      id: json['id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List)
          .map((opt) => PollOption.fromJson(opt))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdBy: json['createdBy'] as String?,
      hasVoted: json['hasVoted'] as bool? ?? false,
      myVoteId: json['myVoteId'] as String? ??
          json['myVoteOptionId'] as String?,
      totalVotes: json['totalVotes'] as int? ?? 0,
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
    return PollOption(
      id: json['id'] as String,
      text: json['text'] as String,
      votes: json['votes'] as int? ?? 0,
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
