import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_error_state.dart';

class FollowersPage extends StatefulWidget {
  final String userId;

  const FollowersPage({
    super.key,
    required this.userId,
  });

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  List<User> _followers = [];
  bool _isLoading = true;
  bool _hasError = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _loadError = null;
      });
    }

    try {
      final result =
          await UserService.getFollowers(widget.userId, page: 1, pageSize: 10);

      if (result.containsKey('followers') && result['followers'] != null) {
        final followers = result['followers'] as List<User>;

        if (mounted) {
          setState(() {
            _followers = followers;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        throw Exception('API返回数据格式错误');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _loadError = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('粉丝'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: MoeErrorState.fromError(
          _loadError,
          scene: MoeErrorScene.followers,
          variant: MoeErrorVariant.plain,
          onRetry: _loadFollowers,
        ),
      );
    }

    if (_followers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无粉丝',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowers,
      child: ListView.builder(
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          return _buildUserItem(_followers[index]);
        },
      ),
    );
  }

  Widget _buildUserItem(User user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
          onTap: () {
            // 跳转到用户详情页面
            // Navigator.push(...)
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                NetworkAvatarImage(
                  imageUrl: user.avatar,
                  radius: 24,
                  placeholderIcon: Icons.person_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
