# 无用文件检测模式

> 本文件为 scan-clean-code Skill 的无用文件检测参考文档。
> 主流程见 [../SKILL.md](../SKILL.md)。

## 1. 文件盘点

### 1.1 源文件分类

| 类型 | 扩展名 | 说明 |
|------|--------|------|
| ObjC 头文件 | `.h` | 可能被 import/include |
| ObjC 实现文件 | `.m` / `.mm` | 应在 .pbxproj Compile Sources 中 |
| Swift 文件 | `.swift` | 应在 .pbxproj Compile Sources 中 |
| C/C++ 文件 | `.c` / `.cpp` / `.cc` | 应在编译源中 |

### 1.2 资源文件分类

| 类型 | 扩展名 / 目录 | 说明 |
|------|---------------|------|
| 图片资源 | `.xcassets` 内的 imageset | 需检查代码和 xib/storyboard 引用 |
| Storyboard | `.storyboard` | 需检查代码中的实例化引用 |
| Xib | `.xib` | 需检查代码中的 loadNibNamed 等 |
| Plist 配置 | `.plist` | 需检查 NSBundle 读取引用 |
| JSON / XML 数据 | `.json` / `.xml` | 需检查 NSBundle 读取引用 |
| 字体文件 | `.ttf` / `.otf` | 需检查 Info.plist 注册和代码引用 |
| 音视频 | `.mp3` / `.mp4` / `.wav` 等 | 需检查 NSBundle 读取引用 |

---

## 2. 源文件引用检查

### 2.1 ObjC 头文件

```bash
# import 引用
#import\s*["<].*FileName\.h[">]
#include\s*["<].*FileName\.h[">]
@import\s+ModuleName;    # 模块级 import

# PCH 文件中的引用
# 检查 .pch 文件
```

判定规则：
- 如果 `.h` 文件无任何 import 引用 → 孤立头文件
- 如果对应的 `.m` 文件也不存在 → 高置信度可清理
- 如果 `.h` 在 umbrella header 中被引用（框架场景）→ 需谨慎确认

### 2.2 ObjC 实现文件

```bash
# .m 文件通常不被 import，通过 .pbxproj 判断
# 搜索 .pbxproj 中的文件引用
FileName\.m
```

判定规则：
- 如果 `.m` 不在 `.pbxproj` 的 `PBXSourcesBuildPhase` 中 → 未参与编译
- 如果对应的 `.h` 也无引用 → 高置信度可清理

### 2.3 Swift 文件

```bash
# Swift 文件通过 .pbxproj 判断编译参与
# Swift 不需要 import 单个文件（同 module 自动可见）
FileName.swift
```

判定规则：
- 如果 `.swift` 不在 `.pbxproj` 的 `PBXSourcesBuildPhase` 中 → 未参与编译
- 如果文件内定义的所有类型/函数都无外部引用 → 可清理

### 2.4 .pbxproj 交叉检查

```bash
# 提取 .pbxproj 中的编译源列表
PBXSourcesBuildPhase
# 文件引用
PBXFileReference.*"FileName\.(m|mm|swift|c|cpp)"
# Build Phase 中的文件
PBXBuildFile.*fileRef.*FileName
```

**⚠️ .pbxproj 是二进制 plist 或 XML 格式，使用 Grep 搜索文本表示即可。**

---

## 3. 资源文件引用检查

### 3.1 xcassets 图片

```bash
# 代码中的引用（图片名不含扩展名和 @2x/@3x 后缀）
UIImage\s*(named|imageNamed):\s*@?"imageName"
\[UIImage\s+imageNamed:\s*@"imageName"\]
UIImage\(named:\s*"imageName"\)
Image\("imageName"\)                      # SwiftUI
#imageLiteral\(resourceName:\s*"imageName"\)

# xib/storyboard 中的引用
image="imageName"
image name="imageName"

# xcassets Contents.json 中提取所有 imageset 名称
# 每个 .imageset 目录名即为图片名
```

### 3.2 Storyboard

```bash
# 代码实例化
UIStoryboard\(name:\s*"StoryboardName"
\[UIStoryboard\s+storyboardWithName:\s*@"StoryboardName"
instantiateViewController.*withIdentifier

# Info.plist 中的 Main storyboard
UIMainStoryboardFile
```

### 3.3 Xib

```bash
# 代码加载
loadNibNamed:\s*@?"XibName"
UINib\(nibName:\s*"XibName"
\[\[NSBundle.*\]\s+loadNibNamed:\s*@"XibName"
Bundle\.main\.loadNibNamed\("XibName"

# 在 storyboard 中作为 cell 的 xib
nibName="XibName"
```

### 3.4 Plist / JSON / XML 数据文件

```bash
# NSBundle 路径获取
pathForResource:\s*@?"FileName"\s+ofType:\s*@?"plist"
url\(forResource:\s*"FileName",\s*withExtension:\s*"json"\)
\[\[NSBundle\s+mainBundle\]\s+pathForResource:\s*@"FileName"
Bundle\.main\.path\(forResource:\s*"FileName"
```

### 3.5 字体文件

```bash
# Info.plist 中注册
UIAppFonts
# 代码引用
UIFont\(name:\s*"FontName"
\[UIFont\s+fontWithName:\s*@"FontName"
```

---

## 4. 特殊情况处理

### 4.1 CocoaPods / SPM / Carthage 文件

排除路径中的第三方依赖文件：
- `Pods/` — CocoaPods
- `.build/` — SPM
- `Carthage/` — Carthage
- `Vendor/` / `ThirdParty/` — 手动引入的第三方库

### 4.2 代码生成文件

以下文件可能由工具自动生成，不应轻易删除：
- `*.generated.swift` / `*.generated.m`
- `R.generated.swift`（R.swift）
- `*.pb.swift` / `*.pbobjc.m`（Protobuf）
- `*.graphql.swift`（Apollo）
- CoreData 的 `*+CoreDataProperties.swift`

标记为"需谨慎确认"并注明"可能为代码生成文件"。

### 4.3 Build Configuration 文件

以下文件不参与运行时但影响构建，不应删除：
- `.xcconfig` 文件
- `Podfile` / `Package.swift` / `Cartfile`
- `*.entitlements`
- `Info.plist`

### 4.4 跨 Target 文件

一个文件可能属于多个 Target（如主 App、Extension、Widget）：
- 需检查所有 Target 的 `PBXSourcesBuildPhase`
- 仅当所有 Target 都不引用时才标记为可清理

---

## 5. 输出字段

每个无用文件项应包含：

| 字段 | 说明 |
|------|------|
| 文件路径 | 相对于 project_root 的路径 |
| 文件类型 | source / header / resource / config |
| 大小 | 文件大小（KB） |
| 分类 | 可清理（高/中置信度） / 需谨慎确认 |
| 原因 | 判定依据（无 import、不在编译源中等） |
| 最后修改 | git log 中的最后修改日期（如可获取） |
| 关联文件 | .h/.m 配对文件、xib 对应的 controller 等 |
