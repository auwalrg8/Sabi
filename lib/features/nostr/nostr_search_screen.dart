import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nostr_service.dart';
import 'nostr_profile_screen.dart';

/// Search type tabs
enum SearchType { users, notes, hashtags }

/// Nostr Search Screen - Full search functionality
class NostrSearchScreen extends StatefulWidget {
  const NostrSearchScreen({super.key});

  @override
  State<NostrSearchScreen> createState() => _NostrSearchScreenState();
}

class _NostrSearchScreenState extends State<NostrSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SearchType _currentTab = SearchType.users;
  bool _isSearching = false;
  String _query = '';

  // Search results
  List<Map<String, dynamic>> _userResults = [];
  List<NostrFeedPost> _noteResults = [];
  List<NostrFeedPost> _hashtagResults = [];

  // Recent searches
  List<String> _recentSearches = [];
  static const _recentSearchesKey = 'nostr_recent_searches';
  static const _maxRecentSearches = 10;

  // Trending hashtags
  List<String> _trendingHashtags = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRecentSearches();
    _loadTrendingHashtags();

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentTab = SearchType.values[_tabController.index];
    });
    // Re-search if we have a query
    if (_query.isNotEmpty) {
      _performSearch(_query);
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_recentSearchesKey);
      if (data != null && mounted) {
        setState(() => _recentSearches = data);
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches.remove(query); // Remove if exists
      _recentSearches.insert(0, query); // Add to front
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
      }
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      if (mounted) {
        setState(() => _recentSearches = []);
      }
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> _loadTrendingHashtags() async {
    final hashtags = await NostrService.getTrendingHashtags();
    if (mounted) {
      setState(() => _trendingHashtags = hashtags);
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    _saveRecentSearch(query.trim());
    _performSearch(query.trim());
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _query = query;
      _isSearching = true;
    });

    try {
      switch (_currentTab) {
        case SearchType.users:
          final results = await NostrService.searchUsers(query);
          if (mounted) {
            setState(() => _userResults = results);
          }
          break;

        case SearchType.notes:
          final results = await NostrService.searchNotes(query);
          if (mounted) {
            setState(() => _noteResults = results);
          }
          break;

        case SearchType.hashtags:
          final results = await NostrService.searchHashtag(query);
          if (mounted) {
            setState(() => _hashtagResults = results);
          }
          break;
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onHashtagTap(String hashtag) {
    _searchController.text = '#$hashtag';
    _tabController.animateTo(2); // Switch to hashtags tab
    _performSearch(hashtag);
    _saveRecentSearch('#$hashtag');
  }

  void _onUserTap(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NostrProfileScreen(
              pubkey: user['pubkey'] as String,
              initialName:
                  user['name'] as String? ?? user['display_name'] as String?,
              initialAvatarUrl: user['picture'] as String?,
            ),
      ),
    );
  }

  void _onNoteTap(NostrFeedPost post) {
    // Navigate to post detail or profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NostrProfileScreen(
              pubkey: post.authorPubkey,
              initialName: post.authorName,
              initialAvatarUrl: post.authorAvatar,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header with search bar
            _buildHeader(),

            // Tab bar
            _buildTabBar(),

            // Content
            Expanded(
              child: _query.isEmpty ? _buildEmptyState() : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 12.w),

          // Search field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onSubmitted: _onSearchSubmitted,
                onChanged: (value) {
                  // Debounced search could be added here
                },
                style: TextStyle(color: Colors.white, fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: _getSearchHint(),
                  hintStyle: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFFA1A1B2),
                    size: 20.sp,
                  ),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _userResults = [];
                                _noteResults = [];
                                _hashtagResults = [];
                              });
                            },
                            child: Icon(
                              Icons.close,
                              color: const Color(0xFFA1A1B2),
                              size: 20.sp,
                            ),
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSearchHint() {
    switch (_currentTab) {
      case SearchType.users:
        return 'Search users, npub...';
      case SearchType.notes:
        return 'Search notes, content...';
      case SearchType.hashtags:
        return 'Search #hashtags...';
    }
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFF7931A),
          borderRadius: BorderRadius.circular(10.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFFA1A1B2),
        labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 13.sp),
        dividerColor: Colors.transparent,
        padding: EdgeInsets.all(4.w),
        tabs: const [
          Tab(text: 'Users'),
          Tab(text: 'Notes'),
          Tab(text: 'Hashtags'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: _clearRecentSearches,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: const Color(0xFFF7931A),
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children:
                  _recentSearches.map((search) {
                    return GestureDetector(
                      onTap: () {
                        _searchController.text = search;
                        if (search.startsWith('#')) {
                          _tabController.animateTo(2);
                          _performSearch(search.substring(1));
                        } else if (search.startsWith('npub')) {
                          _tabController.animateTo(0);
                          _performSearch(search);
                        } else {
                          _performSearch(search);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: const Color(0xFF2A2A3E),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              search.startsWith('#')
                                  ? Icons.tag
                                  : search.startsWith('npub')
                                  ? Icons.person
                                  : Icons.history,
                              color: const Color(0xFFA1A1B2),
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              search,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
            SizedBox(height: 24.h),
          ],

          // Trending hashtags
          if (_trendingHashtags.isNotEmpty) ...[
            Text(
              'Trending Hashtags',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children:
                  _trendingHashtags.map((tag) {
                    return GestureDetector(
                      onTap: () => _onHashtagTap(tag),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF7931A).withOpacity(0.2),
                              const Color(0xFFF7931A).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: const Color(0xFFF7931A).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            color: const Color(0xFFF7931A),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],

          // Search tips
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: const Color(0xFFF7931A),
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Search Tips',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildTip('Users', 'Search by name or paste an npub'),
                SizedBox(height: 6.h),
                _buildTip('Notes', 'Search for keywords in posts'),
                SizedBox(height: 6.h),
                _buildTip('Hashtags', 'Find posts with #bitcoin, #nostr, etc.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 13.sp),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40.r,
              height: 40.r,
              child: const CircularProgressIndicator(
                color: Color(0xFFF7931A),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Searching...',
              style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildUserResults(),
        _buildNoteResults(),
        _buildHashtagResults(),
      ],
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty && _query.isNotEmpty) {
      return _buildNoResults('No users found');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return _UserResultCard(user: user, onTap: () => _onUserTap(user));
      },
    );
  }

  Widget _buildNoteResults() {
    if (_noteResults.isEmpty && _query.isNotEmpty) {
      return _buildNoResults('No notes found');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _noteResults.length,
      itemBuilder: (context, index) {
        final post = _noteResults[index];
        return _NoteResultCard(
          post: post,
          onTap: () => _onNoteTap(post),
          query: _query,
        );
      },
    );
  }

  Widget _buildHashtagResults() {
    if (_hashtagResults.isEmpty && _query.isNotEmpty) {
      return _buildNoResults('No posts with this hashtag');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final post = _hashtagResults[index];
        return _NoteResultCard(
          post: post,
          onTap: () => _onNoteTap(post),
          query: _query,
        );
      },
    );
  }

  Widget _buildNoResults(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: const Color(0xFFA1A1B2), size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(color: const Color(0xFFA1A1B2), fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try a different search term',
            style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}

/// User search result card
class _UserResultCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserResultCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name =
        user['name'] as String? ?? user['display_name'] as String? ?? 'Unknown';
    final picture = user['picture'] as String?;
    final nip05 = user['nip05'] as String?;
    final about = user['about'] as String?;
    final npub = user['npub'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFF2A2A3E),
              backgroundImage:
                  picture != null ? CachedNetworkImageProvider(picture) : null,
              child:
                  picture == null
                      ? Icon(Icons.person, color: Colors.white54, size: 24.sp)
                      : null,
            ),
            SizedBox(width: 12.w),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (nip05 != null) ...[
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.verified,
                          color: const Color(0xFFF7931A),
                          size: 14.sp,
                        ),
                      ],
                    ],
                  ),
                  if (nip05 != null)
                    Text(
                      nip05,
                      style: TextStyle(
                        color: const Color(0xFFA1A1B2),
                        fontSize: 12.sp,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (about != null && about.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        about,
                        style: TextStyle(
                          color: const Color(0xFF8B8B9E),
                          fontSize: 13.sp,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      '${npub.substring(0, 12)}...${npub.substring(npub.length - 8)}',
                      style: TextStyle(
                        color: const Color(0xFF6B6B80),
                        fontSize: 11.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: const Color(0xFFA1A1B2),
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Note search result card
class _NoteResultCard extends StatelessWidget {
  final NostrFeedPost post;
  final VoidCallback onTap;
  final String query;

  const _NoteResultCard({
    required this.post,
    required this.onTap,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor: const Color(0xFF2A2A3E),
                  backgroundImage:
                      post.authorAvatar != null
                          ? CachedNetworkImageProvider(post.authorAvatar!)
                          : null,
                  child:
                      post.authorAvatar == null
                          ? Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 16.sp,
                          )
                          : null,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatTime(post.timestamp),
                        style: TextStyle(
                          color: const Color(0xFF6B6B80),
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Content with highlighted query
            _buildHighlightedContent(post.content),

            // Stats row
            SizedBox(height: 8.h),
            Row(
              children: [
                _StatItem(icon: Icons.favorite_border, count: post.likeCount),
                SizedBox(width: 16.w),
                _StatItem(icon: Icons.repeat, count: post.repostCount),
                SizedBox(width: 16.w),
                _StatItem(
                  icon: Icons.chat_bubble_outline,
                  count: post.replyCount,
                ),
                SizedBox(width: 16.w),
                _StatItem(
                  icon: Icons.electric_bolt,
                  count: post.zapAmount,
                  isZap: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedContent(String content) {
    if (query.isEmpty) {
      return Text(
        content,
        style: TextStyle(color: const Color(0xFFE0E0E0), fontSize: 14.sp),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Simple highlight - find and highlight query
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerContent.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        content,
        style: TextStyle(color: const Color(0xFFE0E0E0), fontSize: 14.sp),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: const Color(0xFFE0E0E0), fontSize: 14.sp),
        children: [
          if (index > 0) TextSpan(text: content.substring(0, index)),
          TextSpan(
            text: content.substring(index, index + query.length),
            style: const TextStyle(
              backgroundColor: Color(0x40F7931A),
              color: Color(0xFFF7931A),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (index + query.length < content.length)
            TextSpan(text: content.substring(index + query.length)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isZap;

  const _StatItem({
    required this.icon,
    required this.count,
    this.isZap = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: isZap ? const Color(0xFFF7931A) : const Color(0xFF6B6B80),
          size: 14.sp,
        ),
        SizedBox(width: 4.w),
        Text(
          _formatCount(count),
          style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 12.sp),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
