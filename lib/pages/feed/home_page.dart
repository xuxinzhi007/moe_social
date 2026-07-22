import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/like_state_manager.dart';
import '../../widgets/post_skeleton.dart';
import '../../utils/error_handler.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../utils/post_navigation.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/home_stories_bar.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/personalized_card.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import 'create_post_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Post> _allPosts = [];
  List<Post> _displayPosts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 10;
  Object? _feedError;
  String? _loadMoreErrorMessage;
  DateTime? _lastUpdatedAt;
  bool _isPrimaryRequestInFlight = false;
  bool _shouldReloadAfterCurrent = false;
  bool _queuedResetContent = false;
  bool _isLoadMoreRequestInFlight = false;

  _HomeFeedMode _mode = _HomeFeedMode.hot;
  TopicTag? _activeTopic;

  late TabController _tabController;

  // Available topic tags collected from loaded posts + official tags
  List<TopicTag> _availableTags = [];

  final ScrollController _scrollController = ScrollController();
  Timer? _loadMoreTimer;
  final LikeStateManager _likeManager = LikeStateManager();

  /// Feed 入场动效去重：按「模式 + 话题 + 帖子 id」分桶，下拉刷新不重播。
  final Set<String> _revealedFeedKeys = {};

  static const _tabs = [
    (
      label: '\u70ed\u95e8',
      icon: Icons.whatshot_rounded,
      mode: _HomeFeedMode.hot
    ),
    (
      label: '\u6700\u65b0',
      icon: Icons.new_releases_rounded,
      mode: _HomeFeedMode.latest
    ),
    (
      label: '\u5173\u6ce8',
      icon: Icons.star_rounded,
      mode: _HomeFeedMode.following
    ),
  ];

  String _feedRevealKey(String postId) =>
      '${_mode.name}_${_activeTopic?.id ?? 'all'}_$postId';

  String get _sectionTitle {
    if (_activeTopic != null) return '#${_activeTopic!.name}';
    switch (_mode) {
      case _HomeFeedMode.hot:
        return '\u70ed\u95e8\u52a8\u6001';
      case _HomeFeedMode.latest:
        return '\u6700\u65b0\u52a8\u6001';
      case _HomeFeedMode.following:
        return '\u5173\u6ce8\u52a8\u6001';
      case _HomeFeedMode.topic:
        return '\u5206\u7c7b\u52a8\u6001';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_scrollListener);
    _availableTags = TopicTag.officialTags.take(12).toList();
    _fetchPosts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _loadMoreTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final newMode = _tabs[_tabController.index].mode;
    if (_mode == newMode && _activeTopic == null) return;
    setState(() {
      _mode = newMode;
      _activeTopic = null; // Clear topic filter on tab change
    });
    _fetchPosts(resetContent: true);
    // Rebuild topic tags after resetting
    _refreshAvailableTags();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    final threshold = maxScroll > 0 ? maxScroll - 300 : 0;
    final isNearBottom = currentScroll >= threshold ||
        (maxScroll > 0 && currentScroll >= maxScroll - 50);
    if (isNearBottom) _scheduleLoadMore();
  }

  void _scheduleLoadMore() {
    _loadMoreTimer?.cancel();
    _loadMoreTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && !_isLoading && !_isLoadingMore && _hasMore) {
        _loadMorePosts();
      }
    });
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.pushNamed(context, '/create-post');
    await _handleCreatePostResult(result);
  }

  Future<void> _handleCreatePostResult(dynamic result) async {
    if (!mounted || result == null) return;
    if (result is Post) {
      _insertCreatedPost(result);
    }
    // 缂傚倸鍊搁崐鎼佸磹閹间礁纾归柣鎴ｅГ閸ゅ嫰鏌涢锝嗙缂佹劖顨堥埀顒€绠嶉崕鍗灻洪妸鈺佺婵鍩栭悡娆戠磽娴ｉ潧鐏╅柡瀣〒缁辨帡鍩€椤掑嫬绀冩い蹇庣娴滅偓顨ラ悙鑼虎闁告梹纰嶆穱濠囶敃閿濆孩鐤佸銈冨灪閹告悂鍩㈡惔銊ョ閻庣數顭堥獮鍫熺節閻㈤潧浠滄俊顐ｇ懇瀹曟繂螖娴ｈ鐝烽悷婊冪箳濡叉劙骞掑Δ鈧猾宥夋煃瑜滈崜娆撯€﹂崶褉鏋庨柟鎯х－閸樻椽鏌熼崗鑲╂殬闁告柨鐭傞幃锟犳晸閻樺磭鍘卞┑鐐村灥瀹曨剟鎮橀敐鍡愪簻闁挎棁顕ч弸銈囩磼鏉堛劌绗х紒杈ㄥ浮婵偓闁绘ɑ褰冮婊堟⒒娴ｅ憡鎲稿┑顕€娼х叅婵犲﹤鐗嗙粻鏌ユ煏韫囨洖顎屾繛灏栨櫊閺屻倝骞栨担瑙勯敪闂侀€炲苯澧扮紒顕呭灦婵＄敻宕熼姘鳖啋闂佸憡顨堥崑鐔哥妤ｅ啯鈷?闂傚倸鍊搁崐鐑芥嚄閸洍鈧箓宕奸姀鈥冲簥濠德板€愰崑鎾绘煃鐠囪尙效鐎殿喗鎸虫慨鈧柣妯虹－閳ь剦鍓熷铏圭磼濡搫顫庨梺杞扮閹诧繝濡靛▎鎾崇鐎瑰壊鍠氶崬鐢告煟閻樼儤銆冮悹鈧敃鍌氱？闁归偊鍠氱壕濂告煟濡櫣锛嶆繛鍙夋尦閺岋紕浠﹂崜褎鍒涢悗娈垮櫘閸ｏ綁鐛鈧畷婊勭瑹婵犲嫬鎯炴繝纰夌磿閸嬫垿宕愰弴鐏荤懓顫濈捄铏诡槶闂佺粯妫侀崑鎰暤娓氣偓閺岀喖鎮滃鍡樼暥缂備胶濮垫繛濠囧蓟閻旇　鍋撻悽娈跨劸閸熺顪冮妶蹇曞埌鐎殿喖澧庨幑銏犫槈閵忕姷顓洪梺缁樺姈濞兼瑧鍠婂澶嬬厽閹兼番鍨婚埢鎾绘煛閸涱喚娲撮柡浣稿暣婵偓闁炽儲鍓氶崵銈夋⒑閸濆嫷妲归柛銊ㄦ硾閻ｉ潧顓奸崱鏇犵畾濡炪倖鍔х€靛矂寮抽幒妤佺厾闁告劘灏欓崺锝嗐亜閵忊剝顥堥柡灞芥椤撳ジ宕卞▎蹇撶闂傚倸鍊风粈渚€鎮樺┑瀣垫晞闁搞儺鍓欏Ч鍙夋叏濡炶浜鹃梺?    await _fetchPosts(resetContent: false);
  }

  void _insertCreatedPost(Post post) {
    if (_activeTopic != null) {
      final matchesTopic = post.topicTags.any((t) => t.id == _activeTopic!.id);
      if (!matchesTopic) return;
    }
    if (_mode == _HomeFeedMode.following) return;
    final exists = _allPosts.any((p) => p.id == post.id);
    if (exists) return;
    setState(() {
      _allPosts = [post, ..._allPosts];
      _displayPosts = List<Post>.from(_allPosts);
      _lastUpdatedAt = DateTime.now();
    });
    _refreshAvailableTags();
  }

  Future<void> _fetchPosts({bool resetContent = true}) async {
    if (_isPrimaryRequestInFlight) {
      _shouldReloadAfterCurrent = true;
      _queuedResetContent = _queuedResetContent || resetContent;
      return;
    }
    _isPrimaryRequestInFlight = true;
    final hasExistingPosts = _displayPosts.isNotEmpty;
    if (mounted) {
      setState(() {
        _feedError = null;
        _loadMoreErrorMessage = null;
        _hasMore = true;
        _currentPage = 1;
        if (!hasExistingPosts) {
          // 首次加载：显示 skeleton
          _isLoading = true;
          _isRefreshing = false;
        } else {
          // 已有内容：静默刷新，保留旧内容直到新数据到达
          _isRefreshing = true;
          _isLoading = false;
        }
      });
    }
    try {
      final result = await _fetchPostsForMode(page: 1);
      if (!mounted) return;
      setState(() {
        _allPosts = result.posts;
        _displayPosts = List<Post>.from(result.posts);
        _currentPage = 1;
        _hasMore = _mode.supportsPagination
            ? result.posts.length < result.total
            : false;
        _feedError = null;
        _lastUpdatedAt = DateTime.now();
      });
      _refreshAvailableTags();
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedError = e;
          _hasMore = false;
        });
      }
      _handleError(e);
    } finally {
      final shouldReload = _shouldReloadAfterCurrent;
      final queuedReset = _queuedResetContent;
      _isPrimaryRequestInFlight = false;
      _shouldReloadAfterCurrent = false;
      _queuedResetContent = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
      if (shouldReload) {
        unawaited(_fetchPosts(resetContent: queuedReset));
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        _isLoadMoreRequestInFlight ||
        !_hasMore) {
      return;
    }
    _isLoadMoreRequestInFlight = true;
    setState(() {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
    });
    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchPostsForMode(page: nextPage);
      if (!mounted) return;
      if (result.posts.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }
      setState(() {
        _allPosts.addAll(result.posts);
        _displayPosts = List<Post>.from(_allPosts);
        _currentPage = nextPage;
        _hasMore =
            _mode.supportsPagination ? _allPosts.length < result.total : false;
        _loadMoreErrorMessage = null;
        _lastUpdatedAt = DateTime.now();
      });
      _refreshAvailableTags();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadMoreErrorMessage =
              MoeErrorCopy.resolve(e, scene: MoeErrorScene.feed).subtitle;
        });
      }
      _handleError(e);
    } finally {
      _isLoadMoreRequestInFlight = false;
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _refreshAvailableTags() {
    final byId = <String, TopicTag>{};
    for (final tag in TopicTag.officialTags) {
      byId[tag.id] = tag;
    }
    for (final p in _allPosts) {
      for (final tag in p.topicTags) {
        byId[tag.id] = tag;
      }
    }
    final tags = byId.values.toList();
    tags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    final nextTags = tags.take(15).toList();
    if (_isSameTagSequence(_availableTags, nextTags)) return;
    if (mounted) setState(() => _availableTags = nextTags);
  }

  bool _isSameTagSequence(List<TopicTag> a, List<TopicTag> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _handleError(dynamic error) {
    if (mounted) {
      if (error is Exception) {
        ErrorHandler.handleException(context, error);
      } else {
        ErrorHandler.showError(context,
            '\u52a0\u8f7d\u9996\u9875\u52a8\u6001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
      }
    }
  }

  void _toggleLike(String postId) {
    final isLiked = _likeManager.getStatusNotifier(postId).value;
    final likeCount = _likeManager.getCountNotifier(postId).value;
    _updateLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: likeCount);
  }

  // 婵犵數濮烽弫鎼佸磻濞戙埄鏁嬫い鎾跺枑閸欏繘鏌熺紒銏犳灈缂佺姷濞€楠炴牕菐椤掆偓婵¤偐绱掗悩宕囧⒌闁哄瞼鍠栭幃娆擃敆閳ь剚鏅堕娑氱闂傚倹娼欏畵鍡涙煛鐏炵偓绀冪€垫澘瀚板畷鐓庘攽閸℃娼涢梻鍌欐祰濡椼劎绮堟笟鈧幃銉︾附缁嬭法鐣哄┑掳鍊愰崑鎾绘煃閽樺妲搁柍璇茬Ч椤㈡顦遍梺顓у灡椤ㄣ儵鎮欑€涙ê纾抽梺绯曟櫔缁绘繂鐣烽妸鈺婃晩闂傚倸顕弳妤呮⒑閼姐倕鏋戠紒顔肩Ф閹广垽宕熼瀣剁秮楠炲洭顢栭懞銉︽澑闂備焦鎮堕崕顕€寮笟鈧鎼佸冀椤撶喎鈧灚顨ラ悙鑼虎闁告梹宀搁弻锝夊棘閹稿寒妫﹂悗娈垮枟閹歌櫕鎱ㄩ埀顒勬煟濡吋鏆╅柛姗嗗墴濮婄粯鎷呴悜妯烘畬濡炪倖娲﹂崣鍐ㄧ暦閹达附鍊锋繛鏉戭儐閻忎線鏌ｉ悩鍙夋悙婵☆垰锕ら妴?rebuild闂傚倸鍊搁崐鐑芥倿閿旈敮鍋撶粭娑樻噽閻瑩鏌熺€涙绠伴柤鐗堝閵囧嫰鏁愰崨顖滎槬eButton 闂傚倷娴囬褍顫濋敃鍌︾稏濠㈣埖鍔栭崑銈夋煛閸モ晛小闁绘帒锕ョ换娑㈠幢濡纰嶉梺?ValueListenable 闂傚倸鍊峰ù鍥敋瑜忛幑銏ゅ箳濡も偓绾惧鏌熼悧鍫熺凡缁炬儳顭烽弻鐔煎礈瑜忕敮娑㈡煃闁垮鐏﹂柕鍥у瀵剟骞愭惔銏犲壍濠电姷顣介埀顒傚仺閸嬨垽鏌＄仦鍓ф创闁糕晪绻濆畷鎺戭煥閸曨偄鐏￠梺璇插椤旀牠宕抽鈧畷婊冣槈閵忕姵鐎銈嗘磵閸嬫挻銇勯姀锛勬噰鐎规洘绮忛¨浣逛繆?
  void _updateLikeSnapshot({
    required String postId,
    required bool isLiked,
    required int likeCount,
  }) {
    final allIndex = _allPosts.indexWhere((p) => p.id == postId);
    if (allIndex != -1) {
      _allPosts[allIndex] = _allPosts[allIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
    }
    final displayIndex = _displayPosts.indexWhere((p) => p.id == postId);
    if (displayIndex != -1) {
      _displayPosts[displayIndex] = _displayPosts[displayIndex].copyWith(
        isLiked: isLiked,
        likes: likeCount,
      );
    }
  }

  String _apiFeedMode() {
    switch (_mode) {
      case _HomeFeedMode.hot:
        return 'hot';
      case _HomeFeedMode.latest:
        return 'latest';
      case _HomeFeedMode.following:
        return 'following';
      case _HomeFeedMode.topic:
        return 'latest';
    }
  }

  String? _apiTopicTagId() {
    if (_activeTopic != null) return _activeTopic!.id;
    return null;
  }

  Future<_PostPageResult> _fetchPostsForMode({required int page}) async {
    final result = await PostService.getPosts(
      page: page,
      pageSize: _pageSize,
      feedMode: _apiFeedMode(),
      topicTagId: _apiTopicTagId(),
    );
    final posts = result['posts'] as List<Post>;
    final totalRaw = result['total'];
    final total =
        totalRaw is int ? totalRaw : (totalRaw is num ? totalRaw.toInt() : 0);
    return _PostPageResult(posts: posts, total: total);
  }

  void _onTopicSelected(TopicTag? tag) {
    if (tag?.id == _activeTopic?.id) {
      // Deselect
      setState(() {
        _activeTopic = null;
        _mode = _tabs[_tabController.index].mode;
      });
    } else {
      setState(() {
        _activeTopic = tag;
        if (tag != null) _mode = _HomeFeedMode.topic;
      });
    }
    _fetchPosts(resetContent: true);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      template: PageTemplate.fullscreen,
      backgroundColor: MoeTheme.of(context).pageBackground,
      body: RefreshIndicator(
        onRefresh: () => _fetchPosts(resetContent: false),
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // SliverAppBar with TabBar in bottom 闂?Flutter-idiomatic, no SliverPersistentHeader needed
            _buildSliverAppBar(context),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: PersonalizedCard(),
              ),
            ),
            SliverToBoxAdapter(
              child:
                  HomeStoriesBar(onCreatePostSuccess: _handleCreatePostResult),
            ),
            // Topic tags row 闂?plain SliverToBoxAdapter, no dynamic-extent issues
            SliverToBoxAdapter(child: _buildFeedSectionTitle(context)),
            if (_feedError != null && _displayPosts.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildInlineErrorBanner(
                  message: MoeErrorCopy.resolve(_feedError,
                          scene: MoeErrorScene.feed)
                      .subtitle,
                  onRetry: () => _fetchPosts(resetContent: false),
                ),
              ),
            if (_isLoading && _displayPosts.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const PostSkeleton(),
                  childCount: 6,
                ),
              )
            else if (_feedError != null && _displayPosts.isEmpty)
              SliverToBoxAdapter(
                child: _buildFeedErrorState(),
              )
            else if (!_isLoading && _displayPosts.isEmpty)
              SliverToBoxAdapter(child: _buildFeedEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => MoeStaggerReveal(
                    index: index,
                    itemKey: _feedRevealKey(_displayPosts[index].id),
                    revealedKeys: _revealedFeedKeys,
                    child: _buildPostCard(_displayPosts[index]),
                  ),
                  childCount: _displayPosts.length,
                ),
              ),
            SliverToBoxAdapter(child: _buildBottomIndicator()),
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final expandedHeight = screenWidth < 360 ? 66.0 : 70.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      backgroundColor: MoeTokens.surface1,
      surfaceTintColor: Colors.transparent,
      foregroundColor: MoeTokens.titleText,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: MoeTokens.gradientPrimary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) =>
                MoeTokens.gradientText.createShader(bounds),
            child: const Text(
              'Moe Social',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: MoeTokens.titleText),
          onPressed: () {
            MoeToast.info(
                context, '\u641c\u7d22\u529f\u80fd\u5373\u5c06\u4e0a\u7ebf');
          },
          tooltip: '\u641c\u7d22',
        ),
        IconButton(
          tooltip: 'AI \u52a9\u624b\u8bbe\u7f6e',
          onPressed: () =>
              Navigator.pushNamed(context, '/virtual-avatar-settings'),
          icon: const Icon(
            Icons.smart_toy_rounded,
            color: MoeTokens.titleText,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded,
              color: MoeTokens.titleText),
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          tooltip: '\u626b\u7801\u6dfb\u52a0\u597d\u53cb',
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: MoeTokens.titleText),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.activityUnreadCount == 0)
                  return const SizedBox.shrink();
                return Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MoeTokens.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 8, minHeight: 8),
                    child: provider.activityUnreadCount > 99
                        ? const Text(
                            '99+',
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          )
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildFeedSectionTitle(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: MoeTokens.gradientPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sectionTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildFeedModeSwitcher(context)),
                const SizedBox(width: 8),
                _buildRefreshButton(),
              ],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: MoeTokens.gradientPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sectionTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFeedModeSwitcher(context),
                const SizedBox(width: 8),
                _buildRefreshButton(),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMetaChip(
                icon:
                    _isRefreshing ? Icons.sync_rounded : Icons.schedule_rounded,
                text: _lastUpdatedText(),
              ),
              if (_activeTopic != null)
                _buildMetaChip(
                  icon: Icons.filter_alt_rounded,
                  text: '#${_activeTopic!.name}',
                  accentColor: _activeTopic!.color,
                  onTap: () => _onTopicSelected(null),
                  trailing: const Icon(Icons.close_rounded, size: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    Color? accentColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final color = accentColor ?? MoeTokens.hintText;
    return InkWell(
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accentColor != null
              ? accentColor.withValues(alpha: 0.14)
              : MoeTokens.surface1.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(
            color: accentColor != null
                ? color.withValues(alpha: 0.28)
                : MoeTokens.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              IconTheme(
                data: IconThemeData(color: color, size: 14),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedModeSwitcher(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _mode == tab.mode;
          return Padding(
            padding: EdgeInsets.only(right: index == _tabs.length - 1 ? 0 : 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              onTap: () {
                if (_tabController.index == index) return;
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isSelected ? MoeTokens.gradientPrimary : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 13,
                      color: isSelected ? Colors.white : MoeTokens.hintText,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return TextButton.icon(
      onPressed: _isLoading || _isRefreshing
          ? null
          : () => _fetchPosts(resetContent: false),
      style: TextButton.styleFrom(
        foregroundColor: MoeTokens.primary,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: Text(_isRefreshing ? '\u5237\u65b0\u4e2d' : '\u5237\u65b0'),
    );
  }

  String _lastUpdatedText() {
    if (_isRefreshing) return '\u6b63\u5728\u5237\u65b0\u5185\u5bb9...';
    final updatedAt = _lastUpdatedAt;
    if (updatedAt == null)
      return '\u5c1a\u672a\u52a0\u8f7d\u6700\u65b0\u52a8\u6001';
    final hour = updatedAt.hour.toString().padLeft(2, '0');
    final minute = updatedAt.minute.toString().padLeft(2, '0');
    return '\u6700\u540e\u66f4\u65b0 ' + hour + ':' + minute;
  }

  Widget _buildInlineErrorBanner({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MoeTokens.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(
            color: MoeTokens.warning.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: MoeTokens.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MoeTokens.titleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading || _isRefreshing ? null : onRetry,
              child: const Text('\u91cd\u8bd5'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: MoeErrorState.fromError(
        _feedError,
        scene: MoeErrorScene.feed,
        onRetry: () {
          if (_isLoading) return;
          _fetchPosts(resetContent: true);
        },
      ),
    );
  }

  Widget _buildFeedEmptyState() {
    if (_mode == _HomeFeedMode.following) {
      return _buildUnifiedStatePanel(
        icon: Icons.star_border_rounded,
        title: '\u5173\u6ce8\u7684\u4eba\u8fd8\u6ca1\u6709\u53d1\u52a8\u6001',
        subtitle:
            '\u5148\u53bb\u793e\u533a\u901b\u901b\u8bdd\u9898\uff0c\u6216\u8005\u53bb\u597d\u53cb\u9875\u8ba4\u8bc6\u65b0\u670b\u53cb\uff0c\u8ba9\u9996\u9875\u6162\u6162\u70ed\u95f9\u8d77\u6765\u3002',
        accentColor: const Color(0xFFFFB347),
        action: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/community'),
            icon: const Icon(Icons.forum_rounded, size: 20),
            label: const Text('\u53bb\u793e\u533a'),
            style: FilledButton.styleFrom(
              backgroundColor: MoeTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
        secondaryAction: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/friends'),
            icon: const Icon(Icons.people_rounded, size: 20),
            label: const Text('\u627e\u597d\u53cb'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MoeTokens.primary,
              side: BorderSide(color: MoeTokens.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      );
    }

    final topicName = _activeTopic?.name;
    final inTopic = _activeTopic != null;
    return _buildUnifiedStatePanel(
      icon: Icons.auto_awesome_rounded,
      title: inTopic
          ? '#' +
              (topicName ?? '') +
              ' \u4e0b\u6682\u65f6\u8fd8\u6ca1\u6709\u52a8\u6001'
          : '\u8fd9\u91cc\u8fd8\u662f\u7a7a\u7684',
      subtitle: inTopic
          ? '\u6362\u4e2a\u8bdd\u9898\u770b\u770b\uff0c\u6216\u8005\u81ea\u5df1\u53d1\u4e00\u6761\u5e26\u4e0a\u8fd9\u4e2a\u6807\u7b7e\u7684\u52a8\u6001\u5427\u3002'
          : '\u53d1\u4e00\u6761\u52a8\u6001\u8bb0\u5f55\u4eca\u5929\uff0c\u6216\u8005\u53bb\u597d\u53cb\u9875\u8ba4\u8bc6\u65b0\u670b\u53cb\u3002',
      accentColor: MoeTokens.primary,
      action: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _openCreatePost,
          icon: const Icon(Icons.edit_rounded, size: 20),
          label: const Text('\u53d1\u5e03\u52a8\u6001'),
          style: FilledButton.styleFrom(
            backgroundColor: MoeTokens.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      secondaryAction: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/friends'),
          icon: const Icon(Icons.people_rounded, size: 20),
          label: const Text('\u627e\u597d\u53cb'),
          style: OutlinedButton.styleFrom(
            foregroundColor: MoeTokens.primary,
            side: BorderSide(color: MoeTokens.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedStatePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Widget action,
    Widget? secondaryAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: MoeTokens.surfaceBorder),
          boxShadow: MoeTokens.shadowCard(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: MoeTokens.gradientSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: MoeTokens.hintText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            action,
            if (secondaryAction != null) ...[
              const SizedBox(height: 12),
              secondaryAction,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: const MoeSmallLoading(),
            label:
                '濠电姷鏁告慨鐢割敊閺嶎厼绐楁俊銈呭暞瀹曟煡鏌熼柇锕€鏋涚紒韬插€濋弻锕€螣娓氼垱顎嗛梺鑲╁鐎笛囧Φ閸曨喚鐤€闁规崘娉涢。铏圭磽娴ｆ彃浜炬繝銏ｅ煐閸旀牠鎮￠悢闀愮箚妞ゆ牗绮岀敮鍫曟煕閺傛鍎戠紒杈ㄥ笚閹峰懎鐣￠弶璺ㄣ偖闂備礁鎼惌澶屾崲濠靛棛鏆﹂柛顐ｆ礀鎯熼梺鎸庢煥婢т粙鍩㈣箛鏂剧箚?..',
          ),
        ),
      );
    } else if (_loadMoreErrorMessage != null &&
        _displayPosts.isNotEmpty &&
        !_isLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFFB347),
              size: 18,
            ),
            label: '\u52a0\u8f7d\u66f4\u591a\u5931\u8d25',
            accentColor: const Color(0xFFFFB347),
            trailing: TextButton(
              onPressed: _isLoadingMore ? null : _loadMorePosts,
              child: const Text('\u91cd\u8bd5'),
            ),
          ),
        ),
      );
    } else if (!_hasMore && _displayPosts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Center(
          child: _buildBottomStateCapsule(
            icon: Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.grey[500],
              size: 18,
            ),
            label:
                '闂傚倷娴囬褍顫濋敃鍌︾稏濠㈣埖鍔栭崑銈夋煛閸モ晛小闁绘帒锕ョ换娑㈠幢濡櫣浠撮梺鎼炲妽缁诲牓寮婚妸鈺傚亜闁告繂瀚呴姀銏㈢＜闁逞屽墴瀹曞崬鈽夊▎鎴濆箰濠电姰鍨煎▔娑氣偓娑掓櫇濞戠數鎹勯崨闈涢叄瀹曞爼濡搁敂杞拌檸闂?~',
          ),
        ),
      );
    } else if (_hasMore && !_isLoading && !_isRefreshing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (_isLoadingMore || _isRefreshing)
                ? null
                : () {
                    if (!_isLoading &&
                        !_isRefreshing &&
                        !_isLoadingMore &&
                        _hasMore) {
                      _loadMorePosts();
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: MoeTokens.gradientPrimary,
                borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                border: Border.all(color: MoeTokens.surfaceBorder),
                boxShadow: MoeTokens.shadowSm(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '\u70b9\u51fb\u52a0\u8f7d\u66f4\u591a',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomStateCapsule({
    required Widget icon,
    required String label,
    Color? accentColor,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MoeTokens.surface1.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: MoeTokens.titleText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    Future<void> openDetail() async {
      final result = await openPostDetail(context, post);
      if (!mounted || result == null) return;
      setState(() {
        final allIndex = _allPosts.indexWhere((p) => p.id == post.id);
        if (allIndex != -1) {
          final updated = _allPosts[allIndex].copyWith(comments: result);
          _allPosts[allIndex] = updated;
          final displayIndex = _displayPosts.indexWhere((p) => p.id == post.id);
          if (displayIndex != -1) _displayPosts[displayIndex] = updated;
        }
      });
    }

    return PostCard(
      key: ValueKey('home_post_${post.id}'),
      post: post,
      onCardTap: () => unawaited(openDetail()),
      onLike: () => _toggleLike(post.id),
      onComment: () => unawaited(openDetail()),
      onAvatarTap: () {
        Navigator.pushNamed(context, '/user-profile', arguments: {
          'userId': post.userId,
          'userName': post.userName,
          'userAvatar': post.userAvatar,
          'heroTag': 'avatar_${post.id}',
        });
      },
      onEdit: post.userId == (AuthService.currentUser ?? '')
          ? () async {
              final updated = await Navigator.push<Post>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePostPage(initialPost: post),
                ),
              );
              if (updated != null && mounted) {
                setState(() {
                  final merged = updated.copyWith(
                    likes: post.likes,
                    comments: post.comments,
                    isLiked: post.isLiked,
                    userName: updated.userName.isNotEmpty
                        ? updated.userName
                        : post.userName,
                    userAvatar: updated.userAvatar.isNotEmpty
                        ? updated.userAvatar
                        : post.userAvatar,
                  );
                  final ai = _allPosts.indexWhere((p) => p.id == updated.id);
                  if (ai != -1) _allPosts[ai] = merged;
                  final di =
                      _displayPosts.indexWhere((p) => p.id == updated.id);
                  if (di != -1) _displayPosts[di] = merged;
                });
              }
            }
          : null,
      onDelete: post.userId == (AuthService.currentUser ?? '')
          ? () async {
              try {
                await PostService.deletePost(post.id);
                if (!mounted) return;
                setState(() {
                  _allPosts.removeWhere((p) => p.id == post.id);
                  _displayPosts.removeWhere((p) => p.id == post.id);
                });
                _likeManager.evictPost(post.id);
              } catch (e) {
                if (mounted)
                  ErrorHandler.showError(context,
                      '闂傚倸鍊搁崐椋庣矆娓氣偓楠炲鏁嶉崟顒佹闂佺粯鍔曢顓犵不妤ｅ啯鐓冪憸婊堝礈濮樿鲸宕叉繛鎴欏灩瀹告繃銇勯幘璺哄壉闁告柨顦甸幃妤呭垂椤愶絿鍑￠柣搴㈠嚬閸樺ジ鈥﹂崶顏嗙杸婵炴垼椴搁弲婵嬫⒑闂堟侗妲归柛鏃€鐗曠叅闁绘梻鍘ч拑?e');
              }
            }
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Enums & helpers
// ---------------------------------------------------------------------------

enum _HomeFeedMode { hot, latest, following, topic }

extension on _HomeFeedMode {
  bool get supportsPagination => true;
}

class _PostPageResult {
  final List<Post> posts;
  final int total;
  const _PostPageResult({required this.posts, required this.total});
}
