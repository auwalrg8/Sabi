import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sabi_wallet/features/zaps/domain/models/post.dart';

part 'zaps_provider.g.dart';

@riverpod
class ZapsNotifier extends _$ZapsNotifier {
  @override
  List<Post> build() {
    return [
      const Post(
        id: '1',
        authorName: 'Chidi',
        authorInitial: 'C',
        zapAmount: '₦5000',
        timestamp: '5 hours ago',
        content: 'Just dropped a new podcast episode',
        likes: 24,
        comments: 8,
      ),
      const Post(
        id: '2',
        authorName: 'Blessing',
        authorInitial: 'B',
        zapAmount: '₦1,000',
        timestamp: '1 hours ago',
        content: 'Who else is stacking sats this week? 💪',
        likes: 24,
        comments: 8,
      ),
      const Post(
        id: '3',
        authorName: 'Mubarak',
        authorInitial: 'M',
        zapAmount: '₦2500',
        timestamp: 'Yesterday',
        content: 'Bitcoin don reach new high! E go still go up? 📈',
        likes: 50,
        comments: 2,
      ),
      const Post(
        id: '4',
        authorName: 'Blessing',
        authorInitial: 'B',
        zapAmount: '₦1,000',
        timestamp: '1 hours ago',
        content: 'Who else is stacking sats this week? 💪',
        likes: 24,
        comments: 8,
      ),
    ];
  }

  void toggleLike(String postId) {
    state =
        state.map((post) {
          if (post.id == postId) {
            return post.copyWith(
              isLiked: !post.isLiked,
              likes: post.isLiked ? post.likes - 1 : post.likes + 1,
            );
          }
          return post;
        }).toList();
  }

  void addPost(Post post) {
    state = [post, ...state];
  }
}
