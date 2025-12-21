import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 带错误处理的网络头像组件
/// 使用Flutter的图片解码API，绕过Android ImageDecoder的限制
class NetworkAvatarImage extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final IconData placeholderIcon;
  final Color? placeholderColor;

  const NetworkAvatarImage({
    super.key,
    this.imageUrl,
    this.radius = 50,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
    this.placeholderColor,
  });

  @override
  State<NetworkAvatarImage> createState() => _NetworkAvatarImageState();
}

class _NetworkAvatarImageState extends State<NetworkAvatarImage> {
  bool _hasError = false;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(NetworkAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasError = false;
      _imageBytes = null;
      _isLoading = false;
      _retryCount = 0;
      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        _loadImage();
      }
    }
  }

  Future<void> _loadImage({bool isRetry = false}) async {
    if (!isRetry && _isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      Uri uri;
      try {
        uri = Uri.parse(widget.imageUrl!);
      } catch (e) {
        debugPrint('URL解析失败: $e');
        uri = Uri.parse(Uri.encodeFull(widget.imageUrl!));
      }

      debugPrint('🖼️ 开始加载图片: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': uri.scheme == 'https' ? 'https://${uri.host}/' : 'http://${uri.host}/',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('🖼️ 图片响应状态: ${response.statusCode}');
      debugPrint('🖼️ Content-Type: ${response.headers['content-type'] ?? '未知'}');
      debugPrint('🖼️ 响应大小: ${response.bodyBytes.length} bytes');

      if (response.statusCode == 200 && mounted) {
        if (response.bodyBytes.isEmpty) {
          debugPrint('⚠️ 图片数据为空');
          _handleLoadError('图片数据为空');
          return;
        }

        // 验证是否为图片格式
        final isValidImage = _validateImageFormat(response.bodyBytes);
        final contentType = response.headers['content-type'] ?? '';
        final isImageContentType = contentType.startsWith('image/');
        
        debugPrint('🖼️ 图片格式验证: isValidImage=$isValidImage, contentType=$contentType');
        
        if (!isValidImage && !isImageContentType) {
          debugPrint('⚠️ 响应可能不是有效的图片格式');
          debugPrint('⚠️ 前16字节(hex): ${response.bodyBytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          debugPrint('⚠️ 前16字节(ascii): ${String.fromCharCodes(response.bodyBytes.take(16).where((b) => b >= 32 && b <= 126))}');
        }

        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
          _hasError = false;
        });
        
        debugPrint('✅ 图片下载成功: ${response.bodyBytes.length} bytes, 格式: ${_getImageFormat(response.bodyBytes)}');
      } else {
        debugPrint('❌ 图片加载失败: HTTP ${response.statusCode}');
        _handleLoadError('HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 图片加载异常: $e');
      debugPrint('URL: ${widget.imageUrl}');
      debugPrint('堆栈跟踪: $stackTrace');
      _handleLoadError(e.toString());
    }
  }

  /// 验证图片格式（检查文件头）
  bool _validateImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return false;
    
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
    
    // WebP: 需要检查RIFF和WEBP
    if (bytes.length >= 12) {
      try {
        final riff = String.fromCharCodes(bytes.sublist(0, 4));
        final webp = String.fromCharCodes(bytes.sublist(8, 12));
        if (riff == 'RIFF' && webp == 'WEBP') {
          debugPrint('✅ 检测到WebP格式');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ WebP格式检测异常: $e');
      }
    }
    
    // 如果无法识别，也返回true（可能是其他格式，让解码器尝试）
    return true;
  }

  /// 获取图片格式名称
  String _getImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return '未知';
    
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'JPEG';
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'PNG';
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return 'GIF';
    
    if (bytes.length >= 12) {
      try {
        final riff = String.fromCharCodes(bytes.sublist(0, 4));
        final webp = String.fromCharCodes(bytes.sublist(8, 12));
        if (riff == 'RIFF' && webp == 'WEBP') return 'WebP';
      } catch (e) {
        // 忽略错误
      }
    }
    
    return '未知';
  }

  /// 处理加载错误，支持重试
  void _handleLoadError(String error) {
    if (_retryCount < _maxRetries && mounted) {
      _retryCount++;
      debugPrint('🔄 重试加载图片 (${_retryCount}/$_maxRetries): ${widget.imageUrl}');
      Future.delayed(Duration(milliseconds: 500 * _retryCount), () {
        if (mounted && widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
          _loadImage(isRetry: true);
        }
      });
    } else {
      debugPrint('❌ 图片加载最终失败，已重试$_retryCount次');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果URL为空或无效，显示占位图
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        child: Icon(
          widget.placeholderIcon,
          size: widget.radius,
          color: widget.placeholderColor ?? Colors.grey[600],
        ),
      );
    }

    // 检查是否是base64 data URI
    final isDataUri = widget.imageUrl!.startsWith('data:image');
    
    if (isDataUri) {
      return _buildDataUriAvatar();
    }

    // 如果正在加载，显示加载指示器
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        child: Center(
          child: SizedBox(
            width: widget.radius * 0.6,
            height: widget.radius * 0.6,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.placeholderColor ?? Colors.grey[600]!,
              ),
            ),
          ),
        ),
      );
    }

    // 如果图片已加载，使用Flutter的图片解码API
    if (_imageBytes != null && !_hasError) {
      return _buildDecodedImage();
    }

    // 如果加载失败，显示占位图
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? Colors.grey[300],
      child: Icon(
        widget.placeholderIcon,
        size: widget.radius,
        color: widget.placeholderColor ?? Colors.grey[600],
      ),
    );
  }

  /// 构建解码后的图片（使用Flutter的图片解码API）
  Widget _buildDecodedImage() {
    return FutureBuilder<ui.Image?>(
      future: _decodeImage(_imageBytes!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundColor: widget.backgroundColor ?? Colors.grey[300],
            child: Center(
              child: SizedBox(
                width: widget.radius * 0.6,
                height: widget.radius * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.placeholderColor ?? Colors.grey[600]!,
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          debugPrint('❌ Flutter图片解码失败: ${snapshot.error}');
          debugPrint('URL: ${widget.imageUrl}');
          // 如果Flutter解码失败，尝试使用MemoryImage作为备用
          return CircleAvatar(
            radius: widget.radius,
            backgroundColor: widget.backgroundColor ?? Colors.grey[300],
            backgroundImage: MemoryImage(_imageBytes!),
            onBackgroundImageError: (exception, stackTrace) {
              debugPrint('❌ MemoryImage备用方案也失败: $exception');
              if (mounted && !_hasError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _hasError = true;
                      _imageBytes = null;
                    });
                  }
                });
              }
            },
            child: _hasError
                ? Icon(
                    widget.placeholderIcon,
                    size: widget.radius,
                    color: widget.placeholderColor ?? Colors.grey[600],
                  )
                : null,
          );
        }

        final image = snapshot.data!;
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor ?? Colors.grey[300],
          child: ClipOval(
            child: CustomPaint(
              size: Size(widget.radius * 2, widget.radius * 2),
              painter: _CircleImagePainter(image),
            ),
          ),
        );
      },
    );
  }

  /// 使用Flutter的图片解码方法（绕过Android ImageDecoder）
  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      debugPrint('🔄 开始解码图片，大小: ${bytes.length} bytes');
      final codec = await ui.instantiateImageCodec(bytes);
      debugPrint('✅ 图片编解码器创建成功');
      final frame = await codec.getNextFrame();
      debugPrint('✅ 图片帧获取成功，尺寸: ${frame.image.width}x${frame.image.height}');
      return frame.image;
    } catch (e, stackTrace) {
      debugPrint('❌ Flutter图片解码异常: $e');
      debugPrint('❌ 堆栈跟踪: $stackTrace');
      debugPrint('❌ 图片前32字节(hex): ${bytes.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return null;
    }
  }

  Widget _buildDataUriAvatar() {
    try {
      final base64String = widget.imageUrl!.split(',')[1];
      final bytes = base64Decode(base64String);
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        backgroundImage: MemoryImage(bytes),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('base64图片加载失败: $exception');
          if (mounted && !_hasError) {
            setState(() {
              _hasError = true;
            });
          }
        },
        child: _hasError
            ? Icon(
                widget.placeholderIcon,
                size: widget.radius,
                color: widget.placeholderColor ?? Colors.grey[600],
              )
            : null,
      );
    } catch (e) {
      debugPrint('解析base64图片失败: $e');
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        child: Icon(
          widget.placeholderIcon,
          size: widget.radius,
          color: widget.placeholderColor ?? Colors.grey[600],
        ),
      );
    }
  }
}

/// 自定义绘制圆形图片的Painter
class _CircleImagePainter extends CustomPainter {
  final ui.Image image;

  _CircleImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()..addOval(rect);
    canvas.clipPath(path);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircleImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
