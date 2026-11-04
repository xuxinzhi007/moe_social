import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// Flag 关闭或未注册原生服务时的深链占位。
class AutoglmUnavailablePage extends StatelessWidget {
  const AutoglmUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AutoGLM'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '服务未注册·不可用',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MoeTokens.titleText,
          ),
        ),
      ),
    );
  }
}
