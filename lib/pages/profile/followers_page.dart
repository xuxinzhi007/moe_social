import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/avatar_image.dart';

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
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    print('🔍 开始加载粉丝列表: userId=${widget.userId}');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      print('📡 发送API请求: userId=${widget.userId}, page=1, pageSize=10');
      final result = await ApiService.getFollowers(widget.userId, page: 1, pageSize: 10);

      print('📥 API响应: $result');

      // ApiService.getFollowers 已经返回了 User 对象列表，直接使用即可
      if (result.containsKey('followers') && result['followers'] != null) {
        final followers = result['followers'] as List<User>;

        print('📊 解析结果: followers=${followers.length}');

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
      print('❌ 加载粉丝列表失败: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFollowers,
              child: const Text('重试'),
            ),
          ],
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
          final user = _followers[index];
          return _buildUserItem(user);
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
        user.username ?? '未知用户',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: user.email != null ? Text(user.email!) : null,
      onTap: () {
        // 跳转到用户详情页面
        // Navigator.push(...)
      },
    );
  }
}
