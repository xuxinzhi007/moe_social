import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/announcement.dart';
import '../../services/announcement_service.dart';
import '../../utils/error_handler.dart';

class AnnouncementDetailPage extends StatefulWidget {
  final String announcementId;
  final Announcement? initial;

  const AnnouncementDetailPage({
    super.key,
    required this.announcementId,
    this.initial,
  });

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  Announcement? _item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.initial;
    if (_item == null || _item!.content.isEmpty) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final item = await AnnouncementService.getById(widget.announcementId);
      if (!mounted) return;
      setState(() => _item = item);
      if (item == null) {
        ErrorHandler.showError(context, '公告不存在或已下线');
      }
    } catch (e) {
      if (mounted) ErrorHandler.handleException(context, e as Exception);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('公告详情'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading && item == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7F7FD5)))
          : item == null
              ? const Center(child: Text('暂无内容'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
                      ),
                      if (item.publishedAt != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(item.publishedAt!.toLocal()),
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        item.content,
                        style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.6),
                      ),
                    ],
                  ),
                ),
    );
  }
}
