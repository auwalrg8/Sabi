class Post {
  final String id;
  final String authorName;
  final String authorInitial;
  final String zapAmount;
  final String timestamp;
  final String content;
  final int likes;
  final int comments;
  final bool isLiked;

  const Post({
    required this.id,
    required this.authorName,
    required this.authorInitial,
    required this.zapAmount,
    required this.timestamp,
    required this.content,
    required this.likes,
    required this.comments,
    this.isLiked = false,
  });

  Post copyWith({
    String? id,
    String? authorName,
    String? authorInitial,
    String? zapAmount,
    String? timestamp,
    String? content,
    int? likes,
    int? comments,
    bool? isLiked,
  }) {
    return Post(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorInitial: authorInitial ?? this.authorInitial,
      zapAmount: zapAmount ?? this.zapAmount,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
