import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';

class GachaBall {
  double x; // 0.0 - 1.0 (相对位置)
  double y; // 0.0 - 1.0
  double vx; // 速度 X
  double vy; // 速度 Y
  Color color;
  double rotation;
  double rotateSpeed;
  double size;
  
  GachaBall({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.color,
    this.rotation = 0,
    this.rotateSpeed = 0,
    this.size = 36,
  });
}

class GachaMachineDisplay extends StatefulWidget {
  final bool isPlaying;
  final List<GachaBall> balls;
  final Function(List<GachaBall>) onPhysicsUpdate;

  const GachaMachineDisplay({
    super.key,
    required this.isPlaying,
    required this.balls,
    required this.onPhysicsUpdate,
  });

  @override
  State<GachaMachineDisplay> createState() => _GachaMachineDisplayState();
}

class _GachaMachineDisplayState extends State<GachaMachineDisplay> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final Random _random = Random();
  double _lastTime = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    // 计算时间增量，避免不同设备速度不一致
    // 限制最大 dt 防止跳帧导致物理穿墙
    double currentTime = elapsed.inMilliseconds.toDouble();
    if (_lastTime == 0) _lastTime = currentTime;
    
    // 简单的 dt 计算，理想情况下是 16.6ms
    // 这里我们简化处理，依然按固定步长更新，但通过 Ticker 驱动
    _updatePhysics();
    
    // 触发重绘
    setState(() {});
    _lastTime = currentTime;
  }

  void _updatePhysics() {
    // 这里直接修改传入的 balls 列表
    // 实际项目中可能需要更严谨的状态管理，但在 Widget 内部这样做性能最好
    
    for (var ball in widget.balls) {
      if (widget.isPlaying) {
        // --- 改进后的搅动模式 (乱飞/洗球效果) ---
        
        // 1. 模拟空气阻力
        ball.vx *= 0.99;
        ball.vy *= 0.99;

        // 2. 强力湍流 (随机乱飞)
        ball.vx += (_random.nextDouble() - 0.5) * 0.012;
        ball.vy += (_random.nextDouble() - 0.5) * 0.012;

        // 3. 动态升力场 (模拟底部强风扇)
        // 只有在下半部分才受到强烈的向上推力，上半部分受重力回落
        if (ball.y > 0.4) {
           // 越到底部力越大
           double lift = 0.004 + 0.004 * (ball.y - 0.4); 
           // 加上正弦波动，模拟气流不稳定
           double turbulence = sin(DateTime.now().millisecondsSinceEpoch / 150 + ball.x * 10);
           ball.vy -= lift * (1.0 + 0.3 * turbulence);
        } else {
           // 上部区域受到重力，让球掉下来形成循环
           ball.vy += 0.0015; 
        }

        // 4. 旋转
         ball.rotation += ball.vx * 15;

         // 更新位置
         ball.x += ball.vx;
         ball.y += ball.vy;

         // 5. 边界限制与反弹
        double ballRatio = 0.18; 
        
        if (ball.x < 0) { ball.x = 0; ball.vx = -ball.vx * 0.8; } 
        else if (ball.x > 1.0 - ballRatio) { ball.x = 1.0 - ballRatio; ball.vx = -ball.vx * 0.8; }
        
        if (ball.y < 0) { ball.y = 0; ball.vy = -ball.vy * 0.8; } 
        else if (ball.y > 1.0 - ballRatio) { ball.y = 1.0 - ballRatio; ball.vy = -ball.vy * 0.8; }

      } else {
        // --- 沉降模式 ---
        ball.vy += 0.002;
        ball.vx *= 0.98;
        ball.x += ball.vx;
        ball.y += ball.vy;
        ball.rotation += ball.vx * 5;

        double ballRatio = 0.18; 
        if (ball.y > 1.0 - ballRatio) {
          ball.y = 1.0 - ballRatio;
          ball.vy = -ball.vy * 0.5; 
          ball.vx *= 0.9;
        }
        if (ball.x < 0) { ball.x = 0; ball.vx = -ball.vx * 0.5; }
        if (ball.x > 1.0 - ballRatio) { ball.x = 1.0 - ballRatio; ball.vx = -ball.vx * 0.5; }
      }
    }
    
    // 回调通知父组件（如果需要同步数据，虽然这里是引用传递）
    // widget.onPhysicsUpdate(widget.balls);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GachaBallsPainter(balls: widget.balls),
      child: Container(),
    );
  }
}

class GachaBallsPainter extends CustomPainter {
  final List<GachaBall> balls;

  GachaBallsPainter({required this.balls});

  @override
  void paint(Canvas canvas, Size size) {
    for (var ball in balls) {
      final paint = Paint()
        ..color = ball.color
        ..style = PaintingStyle.fill;
        
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      // 计算实际位置
      // ball.x 是 0-1，对应 canvas 宽度
      // ball.size 是逻辑像素大小
      final double x = ball.x * size.width;
      final double y = ball.y * size.height;
      final double radius = ball.size / 2;

      // 保存画布状态
      canvas.save();
      
      // 移动到球心并旋转
      canvas.translate(x + radius, y + radius);
      canvas.rotate(ball.rotation);
      canvas.translate(-(x + radius), -(y + radius));

      // 绘制球体
      final center = Offset(x + radius, y + radius);
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(center, radius, borderPaint);

      // 绘制高光 (模拟 Positioned 里的内部 Container)
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      // 高光稍微偏一点
      canvas.drawCircle(center, radius * 0.6, highlightPaint);
      
      // 恢复画布状态
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GachaBallsPainter oldDelegate) {
    return true; // 总是重绘，因为是动画
  }
}
