import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';
import 'package:farmly/core/api_config.dart';
import 'package:farmly/data/mock_data.dart';

// Provider to fetch posts from API + merge with mock data
final communityPostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  List<Map<String, dynamic>> allPosts = [];

  // Try fetching from API
  try {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.communityPosts}'))
        .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final apiPosts = (data['posts'] as List?)?.map((p) {
        return <String, dynamic>{
          'id': p['id'].toString(),
          'farmerName': p['user_name'] ?? 'शेतकरी',
          'farmerNameEn': p['user_name'] ?? 'Farmer',
          'region': p['user_location'] ?? 'Maharashtra',
          'cropType': p['crop_type'] ?? 'General',
          'cropTypeMarathi': p['crop_type'] ?? 'सामान्य',
          'question': p['content'] ?? '',
          'questionEn': p['content'] ?? '',
          'questionHi': p['content'] ?? '',
          'likes': p['likes'] ?? 0,
          'comments': p['comments_count'] ?? 0,
          'timeAgo': 'now',
          'timeAgoMarathi': 'आता',
          'fromApi': true,
        };
      }).toList() ?? [];
      allPosts.addAll(apiPosts);
    }
  } catch (_) {}

  // Always add mock posts
  allPosts.addAll(MockCommunityPosts.posts);
  return allPosts;
});

// Search query provider
final communitySearchProvider = StateProvider<String>((ref) => '');

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final postsAsync = ref.watch(communityPostsProvider);
    final searchQuery = ref.watch(communitySearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('community_feed')),
        actions: [
          IconButton(
            onPressed: () => _showSearchDialog(context, ref),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showNewPostDialog(context, l10n, ref);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.translate('new_post')),
      ),
      body: postsAsync.when(
        data: (posts) {
          // Apply search filter
          final filtered = searchQuery.isEmpty
              ? posts
              : posts.where((p) {
                  final q = searchQuery.toLowerCase();
                  final name = (p['farmerNameEn'] ?? '').toString().toLowerCase();
                  final content = (p['questionEn'] ?? '').toString().toLowerCase();
                  final crop = (p['cropType'] ?? '').toString().toLowerCase();
                  return name.contains(q) || content.contains(q) || crop.contains(q);
                }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    searchQuery.isEmpty ? 'No posts yet. Be the first to post!' : 'No posts match your search.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final post = filtered[index];
              return _PostCard(
                post: post,
                locale: locale,
                l10n: l10n,
                delay: index * 150,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, st) => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: MockCommunityPosts.posts.length,
          itemBuilder: (context, index) {
            final post = MockCommunityPosts.posts[index];
            return _PostCard(
              post: post,
              locale: locale,
              l10n: l10n,
              delay: index * 150,
            );
          },
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(communitySearchProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Posts'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by name, content, or crop...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            ref.read(communitySearchProvider.notifier).state = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(communitySearchProvider.notifier).state = '';
              controller.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showNewPostDialog(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    final textController = TextEditingController();
    String selectedCrop = 'Cotton';
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.translate('new_post'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              // Crop type selector
              Wrap(
                spacing: 8,
                children: ['Cotton', 'Soybean', 'Grape', 'Sugarcane'].map((crop) {
                  final isSelected = selectedCrop == crop;
                  return ChoiceChip(
                    label: Text(crop),
                    selected: isSelected,
                    onSelected: (sel) => setSheetState(() => selectedCrop = crop),
                    selectedColor: AppColors.primaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '${l10n.translate('new_post')}...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📷 Photo feature coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('📷'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isPosting
                          ? null
                          : () async {
                              if (textController.text.trim().isEmpty) return;
                              setSheetState(() => isPosting = true);

                              try {
                                final authService = ref.read(authServiceProvider);
                                final token = await authService.getToken();

                                final response = await http.post(
                                  Uri.parse('${ApiConfig.baseUrl}${ApiConfig.communityPosts}'),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    if (token != null) 'Authorization': 'Bearer $token',
                                  },
                                  body: jsonEncode({
                                    'content': textController.text.trim(),
                                    'crop_type': selectedCrop,
                                  }),
                                );

                                if (response.statusCode == 200) {
                                  ref.invalidate(communityPostsProvider);
                                  if (context.mounted) Navigator.pop(context);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Post published! ✅'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                } else {
                                  setSheetState(() => isPosting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error posting. Login first. (${response.statusCode})'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setSheetState(() => isPosting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Connection error. Please try again.'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isPosting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Post'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final Locale locale;
  final AppLocalizations l10n;
  final int delay;

  const _PostCard({
    required this.post,
    required this.locale,
    required this.l10n,
    required this.delay,
  });

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late int _likes;
  bool _isLiked = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _likes = (widget.post['likes'] as int?) ?? 0;
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);

    if (widget.post['fromApi'] == true) {
      try {
        final postId = widget.post['id'];
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.communityPosts}/$postId/like'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _likes = data['likes'] ?? (_likes + 1);
            _isLiked = true;
          });
        }
      } catch (_) {
        setState(() {
          _likes++;
          _isLiked = true;
        });
      }
    } else {
      setState(() {
        _likes++;
        _isLiked = true;
      });
    }
    setState(() => _isLiking = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMarathi = widget.locale.languageCode == 'mr';
    final post = widget.post;

    // Safe initial extraction - fix RangeError
    final farmerName = post['farmerName'] as String? ?? 'F';
    final initial = farmerName.isNotEmpty ? farmerName.substring(0, 1) : 'F';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMarathi ? post['farmerName'] as String? ?? '' : post['farmerNameEn'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Text(
                          post['region'] as String? ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${isMarathi ? post['timeAgoMarathi'] ?? '' : post['timeAgo'] ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isMarathi ? post['cropTypeMarathi'] as String? ?? '' : post['cropType'] as String? ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Question
          Text(
            isMarathi
                ? post['question'] as String? ?? ''
                : widget.locale.languageCode == 'hi'
                    ? post['questionHi'] as String? ?? ''
                    : post['questionEn'] as String? ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          // Image placeholder
          if (post['fromApi'] != true)
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.image, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            ),
          if (post['fromApi'] != true) const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              // Like button - functional
              GestureDetector(
                onTap: _isLiked ? null : _handleLike,
                child: Row(
                  children: [
                    Icon(
                      _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 20,
                      color: _isLiked ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_likes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: _isLiked ? AppColors.primary : AppColors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Comments
              Row(
                children: [
                  Icon(Icons.comment_outlined, size: 20, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${post['comments'] ?? post['comments_count'] ?? 0}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const Spacer(),
              if (post['fromApi'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🟢 Live',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () {
                  final content = post['questionEn'] ?? post['question'] ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Share: "$content"'),
                      action: SnackBarAction(label: 'OK', onPressed: () {}),
                    ),
                  );
                },
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: widget.delay)).slideY(begin: 0.1);
  }
}
