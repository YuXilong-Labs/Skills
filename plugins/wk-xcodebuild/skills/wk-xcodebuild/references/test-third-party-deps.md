# 测试三方依赖预检（Texture / MMKV）

跑 Tests 时，某些三方库若未做兼容处理会让测试**永久卡死**或**崩溃**，直接拖垮通过率。
本 Skill 在 `test` / `build-for-testing` / `test-without-building`（含 `swift test`）动作前，
读 `Podfile.lock` 做**只读检测**，命中即把告警置顶到摘要（agent 第一眼可见），**不修改用户工程**。

关闭预检：`WK_XCB_NO_TESTDEPS=1`。

---

## 1. Texture（AsyncDisplayKit）< 3.2.0 — 主线程自锁

### 现象

测试启动后主线程永久卡死（`SIGSTOP` 样本）：

```
* thread #1, queue = 'com.apple.main-thread'
  frame #4:  UIKitCore`-[_UIApplicationConfigurationLoader _loadInitializationContext]   ← dispatch_once 等待
  frame #7:  UIKitCore`+[UIScreen initialize]
  ...
  frame #16: UIKitCore`-[UIView initWithFrame:]
* frame #17: AsyncDisplayKit`__ASInitializeFrameworkMainThread_block_invoke (ASInternalHelpers.mm:73)
```

### 根因

3.1.0 的 `ASInitializeFrameworkMainThread()` 在 `__attribute__((constructor))`（dylib 加载、主线程）
里创建 `UIView` 以读取 UIKit 图层默认值（`allowsGroupOpacity` / `allowsEdgeAntialiasing`）。
建 UIView 触发 `+[UIScreen initialize]` → `_loadInitializationContext` 的 `dispatch_once`，
而该 once 要等 app 初始化上下文就绪（也在主线程）。构造函数阶段主线程被自己阻塞 → **自锁**。

### 修复（PR #2032，3.2.0 起合入）

把初始化拆成两条路径，关键是**把碰 UIKit 的代码移出 constructor**：

```objc
// constructor：只做通知 + signpost，不碰 UIKit，无死锁风险
__attribute__((constructor)) static void ASLoadFrameworkInitializerOnConstructor(void) {
    ASInitializeFrameworkMainThreadOnConstructor();   // ASNotifyInitialized() + signpost observers
}
// destructor：把建 UIView 读图层默认值挪到进程退出时，安全
__attribute__((destructor)) static void ASLoadFrameworkInitializerOnDestructor(void) {
    ASInitializeFrameworkMainThreadOnDestructor();    // UIView initWithFrame: 读 allowsGroupOpacity 等
}
```

> 3.2.0 未发布到公共 CocoaPods 仓库，默认 `pod install` 仍装 3.1.0（不含此 PR），故需自行处理。

### 推荐修复路径（按优先级）

#### ① cocoapods-publish 集中替换（首选）

在私有打包插件 `cocoapods-publish` 的 `Pod::Installer#resolve_dependencies` 里，
拿到 `analysis_result.specifications` 后拦截 `Texture` spec，把其 `source`/`version`
替换为含 PR #2032 的版本（私有源的 3.2.0，或 backport 了该 PR 的 3.1.0 git tag）。

- **优点**：一次改，所有走该插件 `pod install` 的工程自动生效；同时覆盖 build 与 test；
  spec 级替换在重装后依然成立（不像 `post_install` 给 Pod 源码打的补丁会被重装冲掉）。
- 范式可参考 `cocoapods-publish` 已有的 `check_http_source`（按 spec 名改写 `source`）。

#### ② Podfile post_install fallback（无插件时）

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |t|
    next unless t.name == 'Texture'
    t.build_configurations.each do |c|
      c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      c.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'AS_INITIALIZE_FRAMEWORK_MANUALLY=1'
    end
  end
end
```

`AS_INITIALIZE_FRAMEWORK_MANUALLY=1` 关掉 load 时的自动初始化构造函数，从根上避免主线程在
dylib 加载阶段建 UIView。代价：需在 app/测试启动后的安全时机**手动**调用一次
`ASInitializeFrameworkMainThread()`（OC：`#import <AsyncDisplayKit/ASAvailability.h>` 后调用），
否则图层默认值不会从 UIKit 读取（多数场景影响很小）。

> 注意：`post_install` 只改 Texture 的**编译宏**，不打源码补丁，重装安全；但需配套手动 init。
> 若能走 ①，优先 ①。

---

## 2. MMKV — 未初始化即崩溃

### 现象

测试用例首次访问 MMKV 时 crash，导致用例失败。

### 根因

MMKV 必须先 `MMKV.initialize()`（指定根目录）才能使用；测试进程若没有走过 app 的正常启动
初始化路径，首次访问就会崩。

### 修复

确保**先于任何 MMKV 访问**完成初始化，二选一：

- **app 启动**：`main.mm` 或 `AppDelegate` 里 `MMKV.initializeMMKV(...)`（若测试挂在 app host 上，
  这条即可覆盖）。
- **测试 bootstrap**：测试 bundle 的 principal class、`+load`，或 `XCTestObservation`
  的 `testBundleWillStart:` 里初始化，保证逻辑测试/无 host 场景也先初始化。

```objc
// 例：测试 bundle 启动引导，先于所有用例
@interface MMKVTestBootstrap : NSObject <XCTestObservation> @end
@implementation MMKVTestBootstrap
+ (void)load {
    [[XCTestObservationCenter sharedTestObservationCenter] addTestObserver:[self new]];
}
- (void)testBundleWillStart:(XCTestBundle *)bundle {
    [MMKV initializeMMKV:NSTemporaryDirectory()];   // 测试用临时目录即可
}
@end
```

> MMKV 是运行时初始化要求，**无法**在打包/`pod install` 阶段解决，必须落在工程的启动引导里。

---

## 预检触发与输出

- 触发动作：`test` / `build-for-testing` / `test-without-building` / `swift test`。
- 检测源：从 `-workspace`/`-project` 所在目录与当前目录向上回溯（≤4 级）找到的 `Podfile.lock`。
- 命中输出：告警先写 stderr（运行前即提示），再置顶到 stdout 摘要（agent 在结果里也能看到）。
- Texture ≥3.2.0 视为已修复，只给一行 `[ok]` 确认；MMKV 只要存在即提示（无法判断是否已初始化）。
- 非 CocoaPods 工程 / 找不到 `Podfile.lock` → 静默放行。
