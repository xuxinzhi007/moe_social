# Flutter性能优化

## 概述

性能是用户体验的关键。Flutter提供了多种工具和最佳实践来帮助开发者构建高性能应用。

## 性能监控工具

### 1. Flutter DevTools

```bash
# 启动DevTools
flutter pub global activate devtools
devtools

# 或者在IDE中直接打开
```

**功能**：
- Widget树检查
- 性能分析（Performance）
- 内存分析（Memory）
- 网络请求监控（Network）
- 日志查看（Logging）

### 2. Performance Overlay

```dart
MaterialApp(
  showPerformanceOverlay: true,  // 显示性能图层
  home: MyHomePage(),
)
```

**解读**：
- 顶部图表：GPU线程耗时（目标：<16ms）
- 底部图表：UI线程耗时（目标：<16ms）

### 3. Repaint Rainbow

```dart
MaterialApp(
  debugShowRepaintRainbow: true,  // 显示重绘区域
  home: MyHomePage(),
)
```

**作用**：识别不必要的重绘区域

## 常见性能问题

### 1. 不必要的Widget重建

**症状**：页面卡顿、帧率下降

**解决方案**：

#### 使用const构造器
```dart
// ❌ 错误：每次都会创建新实例
Container(
  child: Text('Hello'),
)

// ✅ 正确：使用const
const Container(
  child: const Text('Hello'),
)
```

#### 使用const Widget
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Header(),  // const Widget
        const SizedBox(height: 16),  // const Widget
        Content(),  // 非const，因为依赖状态
      ],
    );
  }
}
```

#### 使用ValueListenableBuilder
```dart
// ❌ 错误：整个页面重建
setState(() {
  _counter++;
});

// ✅ 正确：只重建需要的部分
ValueListenableBuilder<int>(
  valueListenable: _counter,
  builder: (context, value, child) {
    return Text('Count: $value');
  },
)
```

### 2. 列表性能问题

**症状**：长列表滚动卡顿

**解决方案**：

#### 使用ListView.builder
```dart
// ❌ 错误：一次性创建所有子项
ListView(
  children: List.generate(1000, (i) => ListTile(title: Text('Item $i'))),
)

// ✅ 正确：按需创建
ListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)
```

#### 使用itemExtent
```dart
ListView.builder(
  itemCount: 1000,
  itemExtent: 80,  // 固定高度，提高性能
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)
```

#### 使用cacheExtent
```dart
ListView.builder(
  itemCount: 1000,
  cacheExtent: 200,  // 预加载范围
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)
```

### 3. 图片性能问题

**症状**：图片加载慢、内存占用高

**解决方案**：

#### 使用缓存图片
```dart
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheWidth: 200,  // 限制内存缓存大小
  memCacheHeight: 200,
)
```

#### 使用resizeImage
```dart
Image.network(
  'https://example.com/large-image.jpg',
  cacheWidth: 200,  // 调整图片大小
  cacheHeight: 200,
)
```

#### 使用FadeInImage
```dart
FadeInImage.assetNetwork(
  placeholder: 'assets/placeholder.png',
  image: 'https://example.com/image.jpg',
  fit: BoxFit.cover,
)
```

### 4. 动画性能问题

**症状**：动画卡顿、掉帧

**解决方案**：

#### 使用RepaintBoundary
```dart
RepaintBoundary(
  child: AnimatedWidget(),  // 隔离重绘区域
)
```

#### 使用const动画
```dart
const AnimatedContainer(
  duration: Duration(milliseconds: 300),
  child: const Icon(Icons.star),
)
```

#### 避免复杂计算
```dart
// ❌ 错误：在build中计算
@override
Widget build(BuildContext context) {
  final result = heavyCalculation();  // 阻塞UI线程
  return Text(result);
}

// ✅ 正确：异步计算
Future<String> heavyCalculation() async {
  return await compute(expensiveFunction, data);
}
```

## 内存优化

### 1. 及时释放资源

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late StreamSubscription _subscription;
  late AnimationController _controller;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _subscription = stream.listen((data) {});
    _controller = AnimationController(vsync: this);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {});
  }

  @override
  void dispose() {
    _subscription.cancel();  // 取消订阅
    _controller.dispose();  // 释放动画控制器
    _timer.cancel();  // 取消定时器
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

### 2. 使用WeakReference

```dart
class ImageCache {
  final Map<String, WeakReference<Image>> _cache = {};

  void cacheImage(String key, Image image) {
    _cache[key] = WeakReference(image);
  }

  Image? getImage(String key) {
    return _cache[key]?.target;
  }
}
```

### 3. 图片内存管理

```dart
// 限制图片缓存大小
PaintingBinding.instance.imageCache.maximumSize = 100;  // 最多100张
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;  // 50MB
```

## 启动优化

### 1. 延迟初始化

```dart
void main() {
  // 延迟非关键初始化
  runApp(MyApp());
  
  // 在后台初始化
  Future.delayed(Duration.zero, () {
    _initializeServices();
  });
}

Future<void> _initializeServices() async {
  await AnalyticsService.init();
  await CrashlyticsService.init();
}
```

### 2. 使用splash screen

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 初始化必要服务
    await AuthService.init();
    await ApiService.init();
    
    // 跳转到主页面
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
```

### 3. 代码分割

```dart
// 使用deferred加载
import 'package:my_app/heavy_page.dart' deferred as heavy_page;

Future<void> loadHeavyPage() async {
  await heavy_page.loadLibrary();
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => heavy_page.HeavyPage()),
  );
}
```

## 网络优化

### 1. 请求合并

```dart
// ❌ 错误：多个独立请求
Future<void> fetchData() async {
  final user = await ApiService.getUser();
  final posts = await ApiService.getPosts();
  final comments = await ApiService.getComments();
}

// ✅ 正确：并行请求
Future<void> fetchData() async {
  final results = await Future.wait([
    ApiService.getUser(),
    ApiService.getPosts(),
    ApiService.getComments(),
  ]);
  
  final user = results[0];
  final posts = results[1];
  final comments = results[2];
}
```

### 2. 请求缓存

```dart
class CachedApiService {
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  final Duration _cacheDuration = Duration(minutes: 5);

  Future<T> get<T>(String url, {bool forceRefresh = false}) async {
    final cached = _cache[url];
    final cachedTime = _cacheTime[url];
    
    if (!forceRefresh && 
        cached != null && 
        cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheDuration) {
      return cached as T;
    }
    
    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);
    
    _cache[url] = data;
    _cacheTime[url] = DateTime.now();
    
    return data as T;
  }
}
```

### 3. 图片懒加载

```dart
ListView.builder(
  itemCount: images.length,
  itemBuilder: (context, index) {
    return Image.network(
      images[index],
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return CircularProgressIndicator(
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
              : null,
        );
      },
    );
  },
)
```

## 渲染优化

### 1. 使用Opacity和Visibility

```dart
// ❌ 错误：使用Container隐藏
Container(
  color: Colors.transparent,  // 仍然参与渲染
  child: widget,
)

// ✅ 正确：使用Visibility
Visibility(
  visible: _isVisible,
  child: widget,
)

// ✅ 更好：使用Offstage（保留状态）
Offstage(
  offstage: !_isVisible,
  child: widget,
)
```

### 2. 使用Clip行为

```dart
// ❌ 错误：默认clip行为
Container(
  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
  child: Image.network('url'),
)

// ✅ 正确：明确clip行为
ClipRRect(
  borderRadius: BorderRadius.circular(8),
  clipBehavior: Clip.antiAlias,  // 明确指定
  child: Image.network('url'),
)
```

### 3. 避免过度嵌套

```dart
// ❌ 错误：过度嵌套
Container(
  child: Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            child: Text('Title'),
          ),
        ],
      ),
    ),
  ),
)

// ✅ 正确：简化结构
Padding(
  padding: EdgeInsets.all(16),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('Title'),
    ],
  ),
)
```

## 构建优化

### 1. 使用build方法的最佳实践

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ❌ 错误：在build中创建对象
    final controller = TextEditingController();
    
    // ✅ 正确：使用final字段或State
    return Container();
  }
}
```

### 2. 使用Selector替代Consumer

```dart
// ❌ 错误：整个页面重建
Consumer<MyProvider>(
  builder: (context, provider, child) {
    return Text(provider.value);
  },
)

// ✅ 正确：只在值变化时重建
Selector<MyProvider, String>(
  selector: (context, provider) => provider.value,
  builder: (context, value, child) {
    return Text(value);
  },
)
```

### 3. 使用Memoization

```dart
class MyWidget extends StatelessWidget {
  final List<Item> items;
  
  const MyWidget({Key? key, required this.items}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 使用memoization缓存计算结果
    final sortedItems = useMemoized(() {
      return items..sort((a, b) => a.name.compareTo(b.name));
    }, [items]);
    
    return ListView.builder(
      itemCount: sortedItems.length,
      itemBuilder: (context, index) {
        return ListTile(title: Text(sortedItems[index].name));
      },
    );
  }
}
```

## 包大小优化

### 1. 移除未使用的资源

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/  # 只包含必要的资源
```

### 2. 使用代码混淆

```bash
flutter build apk --obfuscate --split-debug-info=symbols
```

### 3. 移除未使用的依赖

```bash
# 分析依赖
flutter pub deps

# 移除未使用的包
flutter pub remove unused_package
```

## 总结

性能优化的关键点：

1. **减少Widget重建**：使用const、ValueListenableBuilder
2. **优化列表**：使用ListView.builder、itemExtent
3. **图片优化**：使用缓存、调整大小
4. **动画优化**：使用RepaintBoundary、const
5. **内存管理**：及时释放资源、使用WeakReference
6. **网络优化**：请求合并、缓存、懒加载
7. **渲染优化**：使用Visibility、Clip行为
8. **构建优化**：避免过度嵌套、使用Selector

通过遵循这些最佳实践，可以显著提升Flutter应用的性能。
