import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/main_nav_controller.dart';
import '../../widgets/ai/ai_brand_tokens.dart';

/// 兼容旧路由 `/match`：跳转到主界面「探索 · 同好」。
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
    context.read<MainNavController>().requestExplore(subTab: 0);
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AiBrandTokens.chatBackground,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
