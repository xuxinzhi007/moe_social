import 'package:flutter/material.dart';

import '../../../auth_service.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../theme/moe_tokens.dart';
import '../../../widgets/feishu_enterprise_invite_banner.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/motion/moe_pressable.dart';
import '../../../widgets/motion/moe_reveal.dart';
import '../../../widgets/motion/moe_sheet.dart';

Future<void> showFeishuBindSheet(BuildContext context) async {
  final userId = AuthService.currentUser;
  if (userId == null || userId.isEmpty) {
    MoeToast.error(context, '请先登录');
    return;
  }

  User currentUser;
  try {
    currentUser = await ApiService.getUserInfo(userId);
  } catch (_) {
    if (context.mounted) {
      MoeToast.error(context, '加载用户信息失败，请稍后重试');
    }
    return;
  }

  final emailController =
      TextEditingController(text: currentUser.feishuEmail.trim());
  var busy = false;

  if (!context.mounted) {
    emailController.dispose();
    return;
  }

  await MoeSheet.show<void>(
    context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final bound = currentUser.feishuEmail.trim().isNotEmpty ||
              currentUser.feishuBound;
          final boundLabel = currentUser.feishuName.isNotEmpty
              ? currentUser.feishuName
              : currentUser.feishuEmail;
          final notificationEmail = currentUser.feishuEmail.isNotEmpty
              ? currentUser.feishuEmail
              : '飞书 OAuth 已绑定';

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoeReveal(
                  child: const Text(
                    '飞书通知',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                MoeReveal(
                  delay: const Duration(milliseconds: 30),
                  child: Text(
                    currentUser.feishuBound
                        ? '已绑定飞书账号（$boundLabel），可以接收企业内机器人通知。'
                        : '填写企业飞书邮箱或完成飞书登录后，可接收角色卡创建、更新和删除等通知。',
                    style: const TextStyle(
                      fontSize: 13,
                      color: MoeTokens.hintText,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const MoeReveal(
                  delay: Duration(milliseconds: 60),
                  child: FeishuEnterpriseInviteBanner(),
                ),
                const SizedBox(height: 16),
                MoeReveal(
                  delay: const Duration(milliseconds: 90),
                  child: TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '企业飞书邮箱',
                      hintText: 'you@feishu.cn',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                if (bound) ...[
                  const SizedBox(height: 10),
                  MoeReveal(
                    delay: const Duration(milliseconds: 120),
                    child: Text(
                      '当前通知邮箱：$notificationEmail',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00A86B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                MoeReveal(
                  delay: const Duration(milliseconds: 150),
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              MoeToast.error(ctx, '请输入飞书邮箱');
                              return;
                            }
                            setLocal(() => busy = true);
                            try {
                              final updated =
                                  await ApiService.bindFeishuEmail(email);
                              currentUser = updated;
                              if (ctx.mounted) {
                                MoeToast.success(ctx, '飞书绑定成功');
                              }
                            } catch (_) {
                              if (ctx.mounted) {
                                MoeToast.error(ctx, '绑定失败，请稍后重试');
                              }
                            } finally {
                              setLocal(() => busy = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(busy ? '保存中...' : '保存绑定'),
                  ),
                ),
                const SizedBox(height: 10),
                MoeReveal(
                  delay: const Duration(milliseconds: 180),
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setLocal(() => busy = true);
                            try {
                              await ApiService.sendFeishuTestCard();
                              if (ctx.mounted) {
                                MoeToast.success(ctx, '测试卡片已发送，请在飞书中查看');
                              }
                            } catch (_) {
                              if (ctx.mounted) {
                                MoeToast.error(ctx, '发送失败，请稍后重试');
                              }
                            } finally {
                              setLocal(() => busy = false);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('发送测试卡片'),
                  ),
                ),
                if (bound) ...[
                  const SizedBox(height: 8),
                  MoeReveal(
                    delay: const Duration(milliseconds: 210),
                    child: Center(
                      child: MoePressable(
                        borderRadius: BorderRadius.circular(
                          MoeTokens.radiusFull,
                        ),
                        onTap: busy
                            ? null
                            : () async {
                                setLocal(() => busy = true);
                                try {
                                  final updated =
                                      await ApiService.unbindFeishuEmail();
                                  currentUser = updated;
                                  emailController.clear();
                                  if (ctx.mounted) {
                                    MoeToast.success(ctx, '已解除绑定');
                                  }
                                } catch (_) {
                                  if (ctx.mounted) {
                                    MoeToast.error(ctx, '解绑失败，请稍后重试');
                                  }
                                } finally {
                                  setLocal(() => busy = false);
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            '解除绑定',
                            style: TextStyle(
                              color: busy
                                  ? Colors.red.withValues(alpha: 0.45)
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
  emailController.dispose();
}
