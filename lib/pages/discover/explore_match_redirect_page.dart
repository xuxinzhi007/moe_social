import 'package:flutter/material.dart';

import '../../widgets/ai/ai_brand_tokens.dart';

/// 兼容旧路由 `/match`：跳转到同好与联系人页面。
class ExploreMatchRedirectPage extends StatefulWidget {
  const ExploreMatchRedirectPage({super.key});

  @override
  State<ExploreMatchRedirectPage> createState() =>
      _ExploreMatchRedirectPageState();
}

class _ExploreMatchRedirectPageState extends State<ExploreMatchRedirectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  void _redirect() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/friends');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AiBrandTokens.chatBackground,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
