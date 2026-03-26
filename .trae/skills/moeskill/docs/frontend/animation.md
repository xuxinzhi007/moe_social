# Flutter动画与过渡效果

## 概述

动画是提升用户体验的重要元素。Flutter提供了强大的动画支持，从简单的隐式动画到复杂的自定义动画都能轻松实现。

## 动画类型

### 1. 隐式动画（Implicit Animation）

自动处理动画过渡，只需改变属性值。

#### AnimatedContainer
```dart
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: _isExpanded ? 200 : 100,
  height: _isExpanded ? 200 : 100,
  color: _isExpanded ? Colors.blue : Colors.red,
  child: Center(child: Text('Tap me')),
)
```

#### AnimatedOpacity
```dart
AnimatedOpacity(
  duration: Duration(milliseconds: 500),
  opacity: _isVisible ? 1.0 : 0.0,
  child: MyWidget(),
)
```

#### AnimatedPositioned
```dart
Stack(
  children: [
    AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      left: _isMoved ? 100 : 0,
      top: _isMoved ? 100 : 0,
      child: Container(width: 50, height: 50, color: Colors.blue),
    ),
  ],
)
```

#### AnimatedDefaultTextStyle
```dart
AnimatedDefaultTextStyle(
  duration: Duration(milliseconds: 300),
  style: _isLarge 
    ? TextStyle(fontSize: 24, color: Colors.blue)
    : TextStyle(fontSize: 16, color: Colors.black),
  child: Text('Animated Text'),
)
```

### 2. 显式动画（Explicit Animation）

需要手动控制动画控制器。

#### AnimationController
```dart
class _MyAnimationState extends State<MyAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0, end: 300).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: _animation.value,
          height: _animation.value,
          color: Colors.blue,
        );
      },
    );
  }
}
```

#### FadeTransition
```dart
FadeTransition(
  opacity: _controller,
  child: MyWidget(),
)
```

#### ScaleTransition
```dart
ScaleTransition(
  scale: _controller,
  child: MyWidget(),
)
```

#### RotationTransition
```dart
RotationTransition(
  turns: _controller,
  child: MyWidget(),
)
```

#### SlideTransition
```dart
SlideTransition(
  position: Tween<Offset>(
    begin: Offset(-1, 0),
    end: Offset(0, 0),
  ).animate(_controller),
  child: MyWidget(),
)
```

### 3. Hero动画

页面间共享元素的过渡动画。

```dart
// 页面A
Hero(
  tag: 'image-hero',
  child: Image.asset('photo.jpg', width: 100),
)

// 页面B
Hero(
  tag: 'image-hero',  // 相同的tag
  child: Image.asset('photo.jpg', width: 300),
)
```

**注意事项**：
- 确保tag在页面间唯一
- 多个FAB需要设置不同的heroTag
- 避免在ListView中使用相同的tag

### 4. 交错动画（Staggered Animation）

多个动画按顺序执行。

```dart
class StaggeredAnimation extends StatefulWidget {
  @override
  _StaggeredAnimationState createState() => _StaggeredAnimationState();
}

class _StaggeredAnimationState extends State<StaggeredAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _width;
  late Animation<double> _height;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _width = Tween<double>(begin: 0, end: 200).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.7, curve: Curves.easeInOut),
      ),
    );

    _height = Tween<double>(begin: 0, end: 200).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: _width.value,
            height: _height.value,
            color: Colors.blue,
          ),
        );
      },
    );
  }
}
```

## 动画曲线（Curves）

```dart
// 线性
Curves.linear

// 加速
Curves.easeIn
Curves.easeInQuad
Curves.easeInCubic

// 减速
Curves.easeOut
Curves.easeOutQuad
Curves.easeOutCubic

// 先加速后减速
Curves.easeInOut
Curves.easeInOutQuad

// 弹性效果
Curves.elasticIn
Curves.elasticOut
Curves.elasticInOut

// 回弹效果
Curves.bounceIn
Curves.bounceOut
Curves.bounceInOut

// 自定义曲线
class CustomCurve extends Curve {
  @override
  double transform(double t) {
    return t * t;  // 二次方曲线
  }
}
```

## 页面过渡动画

### 自定义页面路由

```dart
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

// 使用
Navigator.push(
  context,
  FadePageRoute(child: SecondPage()),
);
```

### 滑动过渡

```dart
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SlidePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(1.0, 0.0);
            var end = Offset.zero;
            var tween = Tween(begin: begin, end: end);
            var curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );

            return SlideTransition(
              position: tween.animate(curvedAnimation),
              child: child,
            );
          },
        );
}
```

## 列表动画

### AnimatedList

```dart
AnimatedList(
  key: _listKey,
  initialItemCount: _items.length,
  itemBuilder: (context, index, animation) {
    return _buildItem(_items[index], animation);
  },
)

Widget _buildItem(String item, Animation<double> animation) {
  return SizeTransition(
    sizeFactor: animation,
    child: ListTile(title: Text(item)),
  );
}

// 添加项目
void _addItem() {
  final index = _items.length;
  _items.add('Item $index');
  _listKey.currentState?.insertItem(index);
}

// 删除项目
void _removeItem(int index) {
  final removedItem = _items.removeAt(index);
  _listKey.currentState?.removeItem(
    index,
    (context, animation) => _buildItem(removedItem, animation),
  );
}
```

## 动画最佳实践

### 1. 使用const减少重建

```dart
const AnimatedContainer(
  duration: Duration(milliseconds: 300),
  child: const Icon(Icons.star),
)
```

### 2. 合理设置动画时长

```dart
// 快速反馈：100-300ms
Duration(milliseconds: 200)

// 标准过渡：300-500ms
Duration(milliseconds: 400)

// 复杂动画：500-1000ms
Duration(milliseconds: 800)
```

### 3. 使用RepaintBoundary优化性能

```dart
RepaintBoundary(
  child: AnimatedWidget(),
)
```

### 4. 及时释放资源

```dart
@override
void dispose() {
  _controller.dispose();  // 必须释放
  super.dispose();
}
```

### 5. 使用TickerProviderStateMixin

```dart
// 单个动画
with SingleTickerProviderStateMixin

// 多个动画
with TickerProviderStateMixin
```

## 项目实战案例

### 按钮点击动画

```dart
class AnimatedButton extends StatefulWidget {
  @override
  _AnimatedButtonState createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Press Me', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 加载动画

```dart
class LoadingAnimation extends StatefulWidget {
  @override
  _LoadingAnimationState createState() => _LoadingAnimationState();
}

class _LoadingAnimationState extends State<LoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh, size: 40, color: Colors.blue),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## 调试动画

### 1. 慢速动画

```dart
// 在MaterialApp中开启
debugShowCheckedModeBanner: true,

// 使用timeDilation
timeDilation = 5.0;  // 动画速度放慢5倍
```

### 2. 使用Flutter Inspector

- 查看动画状态
- 检查动画值
- 分析性能

### 3. 打印动画值

```dart
_controller.addListener(() {
  debugPrint('Animation value: ${_controller.value}');
});
```

## 总结

动画的关键点：

1. **选择合适的动画类型**：隐式vs显式
2. **优化性能**：使用const、RepaintBoundary
3. **合理设置时长**：100-1000ms之间
4. **及时释放资源**：dispose中释放controller
5. **使用合适的曲线**：根据场景选择

通过合理使用动画，可以显著提升应用的用户体验。
