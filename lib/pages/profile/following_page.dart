import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_error_state.dart';

class FollowingPage extends StatefulWidget {
  final String userId;

  const FollowingPage({
    super.key,
    required this.userId,
  });

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  List<User> _followings = [];
  bool _isLoading = true;
  bool _hasError = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFollowings();
  }

  Future<void> _loadFollowings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _loadError = null;
      });
    }

    try {
      final result =
          await ApiService.getFollowings(widget.userId, page: 1, pageSize: 10);

      if (result.containsKey('followings') && result['followings'] != null) {
        final followings = result['followings'] as List<User>;

        if (mounted) {
          setState(() {
            _followings = followings;
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
      appBar: AppBar(
        title: const Text('关注'),
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
          scene: MoeErrorScene.following,
          variant: MoeErrorVariant.plain,
          onRetry: _loadFollowings,
        ),
      );
    }

    if (_followings.isEmpty) {
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
              '暂无关注',
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
      onRefresh: _loadFollowings,
      child: ListView.builder(
        itemCount: _followings.length,
        itemBuilder: (context, index) {
          return _buildUserItem(_followings[index]);
        },
      ),
    );
  }

  Widget _buildUserItem(User user) {
    return ListTile(
      leading: NetworkAvatarImage(
        imageUrl: user.avatar,
        radius: 24,
        placeholderIcon: Icons.person,
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: user.email.isNotEmpty ? Text(user.email) : null,
      onTap: () {
        // 跳转到用户详情页面
        // Navigator.push(...)
      },
    );
  }
}
