import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../auth_service.dart';
import '../widgets/avatar_image.dart';
import '../utils/error_handler.dart';

class CloudGalleryPage extends StatefulWidget {
  const CloudGalleryPage({Key? key, this.onImageSelected, this.isSelectMode = false}) : super(key: key);
  
  final Function(String)? onImageSelected;
  final bool isSelectMode;

  @override
  State<CloudGalleryPage> createState() => _CloudGalleryPageState();
}

class _CloudGalleryPageState extends State<CloudGalleryPage> {
  List<dynamic> _images = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _pageSize = 10;
  int _total = 0;
  bool _hasMore = true;
  
  @override
  void initState() {
    super.initState();
    _loadImages();
  }
  
  Future<void> _loadImages() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await ApiService.get('/api/images?page=$_currentPage&page_size=$_pageSize');
      if (result['success'] == true) {
        final images = result['data'] as List;
        setState(() {
          _images.addAll(images);
          _total = result['total'] as int;
          _hasMore = _images.length < _total;
          _currentPage++;
        });
      } else {
        ErrorHandler.showError(context, result['message'] ?? '加载图片失败');
      }
    } catch (e) {
      ErrorHandler.showError(context, '加载图片失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteImage(String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await ApiService.delete('/api/images/$filename');
      setState(() {
        _images.removeWhere((image) => image['filename'] == filename);
        _total--;
      });
      ErrorHandler.showSuccess(context, '删除成功');
    } catch (e) {
      ErrorHandler.showError(context, '删除失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectMode ? '选择图片' : '云端图库'),
        actions: [
          if (!widget.isSelectMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _images = [];
                  _currentPage = 1;
                  _hasMore = true;
                });
                _loadImages();
              },
            ),
        ],
      ),
      body: _isLoading && _images.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _images.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          onTap: _loadImages,
                          child: Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Text('加载更多'),
                            ),
                          ),
                        );
                }
                
                final image = _images[index];
                final imageUrl = image['url'] as String;
                final filename = image['filename'] as String;
                
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onImageSelected != null) {
                          widget.onImageSelected!(imageUrl);
                          Navigator.pop(context);
                        }
                      },
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    if (!widget.isSelectMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteImage(filename),
                          iconSize: 18,
                        ),
                      ),
                    if (widget.isSelectMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}