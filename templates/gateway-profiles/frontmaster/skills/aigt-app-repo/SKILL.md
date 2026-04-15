---
name: aigt-app-repo
description: |
  Development guide for lzxlai's aigt-app-repo — a Melos-managed Flutter monorepo with Git submodules, integrating Tencent IM SDK (TUIKit). Covers project structure, shared package responsibilities (aigt_env, aigt_l10n, aigt_state, aigt_design, lzxlai_open_api), i18n rules, code generation workflows, and strict coding conventions.
  Use when: working in aigt-app-repo, developing AIGT-APP/TUIKit_Flutter/kelivo/digital_human modules, adding shared packages, managing Melos workspace, integrating Tencent IM, handling Flutter monorepo patterns.
license: Proprietary
metadata:
  version: "1.0.0"
  category: mobile
  sources:
    - lzxlai Internal AGENTS.md
    - aigt-app-repo project conventions
---

# aigt-app-repo — lzxlai Flutter 单仓多包开发指南

面向 lzxlai 公司移动端业务的 Flutter 项目。本 skill 提供开发时必须遵守的结构约定、工作流和边界规则。

## 触发条件

当用户在 `aigt-app-repo` 仓库或任何子模块/子包中执行开发任务时自动激活。关键词：`aigt-app-repo`、`aigt`、`TUIKit_Flutter`、`kelivo`、`AIGT-APP`、`digital_human`、`aigt_env`、`aigt_l10n`、`aigt_state`、`aigt_design`、`lzxlai_open_api`。

## 项目概览

### 架构

这是一个由 **Melos** 管理的 **Flutter 单仓多包** 项目，集成 **腾讯 IM SDK (TUIKit)**。通过 Git Submodule 管理外部子仓。

```
aigt-app-repo/
├── lib/main.dart              # 根应用入口，路由到不同业务入口
├── modules/                   # 业务子模块（Git submodule 或本地包）
│   ├── AIGT-APP/              # 原 GT 应用（package:chat_demo）
│   ├── TUIKit_Flutter/        # 腾讯 IM UI 套件（含 chat_app、atomic-x 等）
│   ├── kelivo/                # AI 助手（package:Kelivo）
│   └── digital_human/         # 数字人模块
├── packages/                  # 共享基础包
│   ├── aigt_env/              # 环境变量管理
│   ├── aigt_l10n/             # 国际化（跨模块通用文案）
│   ├── aigt_state/            # 全局状态管理
│   ├── aigt_design/           # 主题与设计令牌
│   └── lzxlai_open_api/       # OpenAPI 接口客户端
└── tool/                      # 项目工具脚本
```

### 启动流程

- 根包 `lib/main.dart`（包名 `aigt`）为启动入口
- 通过 `aigt_env.ensureEnvLoaded()` 加载 `.env`
- 初始化 `lzxlai_open_api` 基础地址
- 默认启动 `tuikit_chat_app`，当 `APP_ENTRYPOINT=AIGT` 时走 AIGT 入口
- **平台约束：默认以 iOS/Android 为主；Windows/macOS 桌面端不用管**

## 开发工作流

### 初始化

```bash
dart run tool/init_submodules.dart   # 拉取子模块（首次）
dart run tool/bootstrap.dart         # 安装工作区依赖 + 激活 Melos
flutter pub get
```

### 运行与构建

```bash
flutter run                          # 运行
flutter build apk                    # 构建 APK
flutter build ipa                    # 构建 iOS
flutter analyze                      # 静态检查
dart format <files-or-dirs>          # 格式化
```

### 代码生成

```bash
# 国际化
cd packages/aigt_l10n && flutter gen-l10n

# OpenAPI 接口生成
cd packages/lzxlai_open_api && dart run tool_openapi_generate.dart

# 资源生成（build_runner）
dart run build_runner build --delete-conflicting-outputs
```

### 测试

```bash
flutter test test/<file_name>_test.dart
flutter test test/<file_name>_test.dart --plain-name "<test description>"
dart test test/<file_name>_test.dart              # 纯 Dart 包
```

## 代码规范

### 文件与命名

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件名 | `snake_case.dart` | `chat_service.dart` |
| 类型名 | `PascalCase` | `ChatMessage` |
| 变量/函数/参数 | `lowerCamelCase` | `sendMessage()` |
| 私有成员 | 前缀 `_` | `_internalState` |
| 单文件上限 | **800 行**，超过必须按职责拆分 | |

### 导入规则

- 跨包/跨模块引用使用 `package:` 导入
- **禁止重命名已有包标识**：
  - `package:chat_demo/...`（AIGT-APP）
  - `package:tuikit_chat_app/...`（TUIKit chat_app）
- 同包内近邻文件可按目录使用相对路径
- 禁止无关的大规模 import 排序/改写噪音

### 类型与 API 设计

- 公开 API 与不直观局部变量优先显式类型
- 非必要不使用 `dynamic`（插件边界除外）
- 不使用不明确语义的 `Map` 作为核心业务模型；先定义数据类
- 字符串状态值/类型值优先封装为 `enum`
- 默认使用 `final`，可编译期常量优先 `const`
- 空安全处理优先明确判空与保护分支，避免强行断言

### 错误处理与日志

- **禁止静默吞错**，避免空 `catch`
- 在网络、存储、认证边界使用可辨识的错误类型/结果
- 新增代码需补充必要中文注释（解释业务意图、边界条件、关键分支）
- 关键流程使用 `debugPrint` 输出中文日志，格式：`[功能标识] 具体信息`
  - 例：`[登录流程] IM 登录成功，userId=xxx`

## 模块化约束

### 共享包职责（必须遵守）

| 包 | 职责 | 新增功能去向 |
|----|------|-------------|
| `aigt_env` | 环境变量管理与解析 | 新增环境变量统一收敛到此 |
| `aigt_l10n` | 跨模块通用国际化文案 | 通用文案必须放此，非旧 ARB |
| `aigt_state` | 跨模块全局状态能力 | 新增全局状态统一放此 |
| `aigt_design` | 全局主题与设计令牌 | 新主题设计统一接入 |
| `lzxlai_open_api` | 接口客户端与调用封装 | 新接口优先接入此 |

### 国际化（严格规则）

1. **跨模块通用文案**：必须放 `packages/aigt_l10n`
2. **新语言翻译**：统一在 `packages/aigt_l10n` 新增，不在旧 ARB 体系继续新增
3. **modules/ 历史国际化**：仅做兼容，不继续扩写新文案
4. **新增用户可见文案必须国际化，禁止硬编码**
5. 修改 ARB 后必须在对应包内执行 `flutter gen-l10n`
6. **禁止手改 `app_localizations*.dart` 等生成文件**

### TUIKit 错误码

- 涉及 TIM 错误码判断时，必须使用：
  ```dart
  import 'package:tuikit_atomic_x/base_component/constants/tim_error_code.dart';
  ```
- **禁止硬编码数字错误码**（如 `6014`、`70001`），必须使用枚举语义化分支
- 新增错误码映射优先补充到 constants 目录

### 网络与配置

- 新接口优先接入 `lzxlai_open_api`，统一维护接口调用约定
- 遵循 `.env` / `.env.dev` / `.env.pro` 配置（`BASE_URL` 及服务分地址）
- 非任务明确要求，不改变 `OFFLINE_DEMO_MODE` 语义

### 资源管理

- 新增图片/图标等静态资源，统一接入 `flutter_gen_runner`
- 引用优先使用生成代码常量，不直接手写字符串路径

### 原生配置

- 原生配置统一维护在根目录 `android/`、`ios/`
- **禁止在 `modules/*` 子模块中新增或分散维护原生配置**

## 交付前验证

有代码变更时，必须完成：
1. 对改动文件执行 `dart format`
2. 在相关范围执行 `flutter analyze` 或 `dart analyze`
3. 运行相关测试，至少覆盖改动影响路径

若受环境限制无法全量验证，需在交付说明中明确未执行项、原因、风险。

## Git 子模块卫生

- `modules/AIGT-APP` 与 `modules/kelivo` 是 Git 子模块
- 修改子模块代码：**先在子模块仓库提交，再回根仓更新子模块指针**
- 未明确要求时，不重命名包标识，不改入口契约

## 禁止事项

- **禁止** 手改生成产物（`*.g.dart`、`app_localizations*.dart`、`.dart_tool/**`）
- **禁止** 在 UI 中硬编码用户可见文案
- **禁止** 把页面 UI、网络调用、状态编排、数据模型堆叠在同一文件
- **禁止** 静默吞错误或空 `catch`
- **禁止** 大规模 import 排序/改写噪音提交
- **禁止** 在子模块中分散维护原生配置
- **禁止** 使用不明确语义的 `Map` 作为核心业务数据模型
- **禁止** 在旧 ARB 体系继续新增翻译文案
