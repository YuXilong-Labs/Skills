# 飞书 API 文档模板

> 以下是一个理想的润色后组件文档示例，作为润色目标参照。

---

# BTRouter

> 路由模块 — 提供页面跳转、服务调用和 URL Scheme 处理能力。

基于 URL 的路由框架，支持页面注册与跳转、服务发现与调用、深度链接处理。采用注册制设计，所有路由需在启动时注册。

**API 数量：** 28 | **源文件数：** 12

---

## 快速开始

### 注册路由并跳转页面

```objc
// 注册路由
[BTRouter registerURL:@"bt://user/profile" toHandler:^(NSDictionary *params) {
    NSString *userId = params[@"userId"];
    BTUserProfileVC *vc = [[BTUserProfileVC alloc] initWithUserId:userId];
    [BTRouter pushViewController:vc animated:YES];
}];

// 跳转
[BTRouter openURL:@"bt://user/profile?userId=12345"];
```

### 调用服务

```objc
id<BTUserService> service = [BTRouter serviceForProtocol:@protocol(BTUserService)];
BTUser *user = [service currentUser];
```

---

## API 概览

| 分类 | 类/协议 | 说明 |
|------|---------|------|
| 核心路由 | `BTRouter` | 路由注册、跳转、服务调用 |
| 配置 | `BTRouterConfig` | 路由配置（拦截器、降级策略） |
| 协议 | `BTRoutable` | 页面路由协议 |
| 协议 | `BTServiceProtocol` | 服务注册协议 |

---

## 📦 类 `BTRouter`

```objc
@interface BTRouter : NSObject
```

**路由管理核心类，提供 URL 注册、跳转、服务发现等功能。**

全局单例，线程安全。支持 URL 路由和协议路由两种模式。

📄 `BTRouter/Core/BTRouter.h`

### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `config` | `BTRouterConfig *` | 路由配置（拦截器、降级等） |
| `registeredURLs` | `NSArray<NSString *> *` | 已注册的 URL 列表（只读） |

#### 📌 属性 `config`

```objc
@property(nonatomic, strong) BTRouterConfig *config;
```

路由配置对象，包含全局拦截器、降级策略和日志开关。建议在 `application:didFinishLaunching:` 中配置。

#### 📌 属性 `registeredURLs`

```objc
@property(nonatomic, copy, readonly) NSArray<NSString *> *registeredURLs;
```

当前已注册的所有 URL Pattern 列表，用于调试和日志。

### 方法

#### 🔧 方法 `sharedInstance`

```objc
+ (instancetype)sharedInstance;
```

获取路由管理器共享实例（单例）。

#### 🔧 方法 `registerURL:toHandler:`

```objc
+ (void)registerURL:(NSString *)URLPattern toHandler:(BTRouterHandler)handler;
```

**注册 URL Pattern 与对应处理器。**

**参数：**
- `URLPattern` — URL 匹配模式，支持参数占位符（如 `bt://user/:userId`）
- `handler` — 路由命中时的回调 Block，参数包含 URL 中的查询参数和路径参数

#### 🔧 方法 `openURL:`

```objc
+ (BOOL)openURL:(NSString *)URL;
```

**打开指定 URL，触发已注册的路由处理器。**

**返回值：** URL 是否匹配到已注册的路由（匹配返回 YES，未匹配返回 NO 并触发降级策略）

---

## 📋 协议 `BTRoutable`

```objc
@protocol BTRoutable <NSObject>
```

**页面路由协议，VC 实现此协议以支持 URL 路由。**

📄 `BTRouter/Core/BTRoutable.h`

### 方法

#### 🔧 方法 `routerURL`

```objc
+ (NSString *)routerURL;
```

返回该页面对应的路由 URL Pattern。

#### 🔧 方法 `initWithRouterParams:`

```objc
- (instancetype)initWithRouterParams:(NSDictionary *)params;
```

**通过路由参数初始化页面实例。**

**参数：**
- `params` — 路由参数字典，包含 URL 中的 query 和 path 参数

---

## 枚举类型

### 📦 枚举 `BTRouterOpenMode`

```objc
typedef NS_ENUM(NSInteger, BTRouterOpenMode) {
    BTRouterOpenModePush = 0,
    BTRouterOpenModePresent,
    BTRouterOpenModeCustom,
};
```

**页面打开方式。**

| 成员 | 值 | 说明 |
|------|----|------|
| `BTRouterOpenModePush` | 0 | Push 导航（默认） |
| `BTRouterOpenModePresent` | 1 | Modal 弹出 |
| `BTRouterOpenModeCustom` | 2 | 自定义转场 |

---

*文档自动生成于 2026-03-31 12:00，经 AI 润色优化*
