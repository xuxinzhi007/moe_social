import 'package:flutter/material.dart';

import '../../../auth_service.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../widgets/feishu_enterprise_invite_banner.dart';
import '../../../widgets/moe_toast.dart';

Future<void> showFeishuBindSheet(BuildContext context) async {
  final userId = AuthService.currentUser;
  if (userId == null || userId.isEmpty) {
    MoeToast.error(context, '请先登录');
    return;
  }

  User currentUser;
  try {
    currentUser = await ApiService.getUserInfo(userId);
  } catch (e) {
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

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final bound = currentUser.feishuEmail.trim().isNotEmpty ||
              currentUser.feishuBound;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '飞书通知',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUser.feishuBound
                        ? '已绑定飞书（${currentUser.feishuName.isNotEmpty ? currentUser.feishuName : currentUser.feishuEmail}）。'
                            '可接收企业内机器人通知。'
                        : '非必须。填写企业飞书邮箱或使用飞书登录后，可接收角色卡创建/更新/删除通知；'
                            '须为本企业成员。',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.45,
                    ),
                  ),
                  const FeishuEnterpriseInviteBanner(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '企业飞书邮箱',
                      hintText: 'you@feishu.cn',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (bound) ...[
                    const SizedBox(height: 10),
                    Text(
                      '通知邮箱：${currentUser.feishuEmail.isNotEmpty ? currentUser.feishuEmail : '（飞书 OAuth 已绑定）'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00A86B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
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
                              setLocal(() => busy = false);
                            } catch (e) {
                              setLocal(() => busy = false);
                              if (ctx.mounted) {
                                MoeToast.error(ctx, '绑定失败，请稍后重试');
                              }
                            }
                          },
                    child: Text(busy ? '保存中…' : '保存绑定'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setLocal(() => busy = true);
                            try {
                              await ApiService.sendFeishuTestCard();
                              if (ctx.mounted) {
                                MoeToast.success(
                                  ctx,
                                  '测试卡片已发送，请在飞书查看',
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                MoeToast.error(ctx, '发送失败，请稍后重试');
                              }
                            } finally {
                              setLocal(() => busy = false);
                            }
                          },
                    child: const Text('发送测试卡片'),
                  ),
                  if (bound) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
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
                                setLocal(() => busy = false);
                              } catch (e) {
                                setLocal(() => busy = false);
                                if (ctx.mounted) {
                                  MoeToast.error(ctx, '解绑失败，请稍后重试');
                                }
                              }
                            },
                      child: const Text(
                        '解除绑定',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
  emailController.dispose();
}
