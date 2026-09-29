import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/companion_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/moe_toast.dart';

/// 单独的换头像页。
///
/// 系统相册会暂停当前 Activity。编辑页里有滚动表单和输入框，在那一页直接选图会把语义树打断。
/// 选中后就在这一页上传，再把地址带回编辑页。
class CompanionAvatarStudioPage extends StatefulWidget {
  const CompanionAvatarStudioPage({
    super.key,
    required this.emoji,
    required this.avatarUrl,
  });

  final String emoji;
  final String avatarUrl;

  @override
  State<CompanionAvatarStudioPage> createState() =>
      _CompanionAvatarStudioPageState();
}

class _CompanionAvatarStudioPageState extends State<CompanionAvatarStudioPage> {
  Uint8List? _preview;
  bool _uploading = false;

  Future<void> _pick() async {
    if (_uploading) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _preview = bytes;
      _uploading = true;
    });
    try {
      final name = picked.name.trim().isEmpty ? 'avatar.jpg' : picked.name;
      final url = await CompanionService().uploadAvatarBytes(
        bytes,
        filename: name,
      );
      if (!mounted) return;
      Navigator.pop(context, url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _clear() {
    if (_uploading) return;
    Navigator.pop(context, '');
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('更换头像'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            children: [
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: preview == null
                      ? CompanionAvatar(
                          emoji: widget.emoji,
                          avatarUrl: widget.avatarUrl,
                          size: 220,
                          borderRadius: BorderRadius.circular(28),
                        )
                      : Image.memory(
                          preview,
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _uploading ? '正在上传，完成后会回到资料页' : '选一张照片，会直接换成新头像',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MoeTokens.hintText,
                ),
              ),
              const Spacer(),
              _StudioButton(
                label: _uploading ? '上传中…' : '从相册选择',
                filled: !_uploading,
                onTap: _pick,
              ),
              const SizedBox(height: 10),
              _StudioButton(
                label: '清除头像',
                filled: false,
                onTap: _clear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioButton extends StatelessWidget {
  const _StudioButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? MoeTokens.primary : MoeTokens.softChipBg,
          foregroundColor: filled ? Colors.white : MoeTokens.titleText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
