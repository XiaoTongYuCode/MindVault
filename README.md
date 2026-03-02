## Myrisle / 私屿

Myrisle（中文名「私屿」）是一款专注于**本地私密情绪日记**的 iOS 应用。  
你可以用它记录每天的想法与感受，应用会通过本地 AI 情感分析（基于 OpenRouter LLM 或本地模型）自动识别情绪倾向，并用可视化图表帮助你理解自己的情绪变化。

> 记录即疗愈，用 AI 读懂你的情绪，让每一篇日记都有温度。

---

### 特性一览

- **本地私密存储**
  - 所有日记数据保存在设备本地的 Core Data 中，不依赖服务端。
  - 支持离线使用，不需要账号注册。

- **AI 情绪分析**
  - 为每篇日记生成情感分数（-1 ~ 1）、情绪标签、Emoji 和简短总结。
  - 默认使用 OpenRouter 远程模型，也预留本地模型（如 Qwen）接入能力。

- **情绪趋势图表**
  - 基于 Swift Charts 展示最近 7 / 30 天的情绪曲线。
  - 查看积极 / 中性 / 消极情绪的分布和统计。

- **优雅的写作体验**
  - 沉浸式的全屏日记编辑器，支持标题 + 正文。
  - 毛玻璃卡片、紫色渐变主题、细腻微交互。

- **多语言与主题**
  - 内置语言管理（当前主要为简体中文，可扩展）。
  - 支持主题管理，适配暗色模式。

---

### 运行项目

**环境要求**

- macOS（建议 14+）
- Xcode 15+（Swift 5.9+）
- iOS 17+ 模拟器或真机
- 有效的 Apple 开发者账号（真机调试或发布时需要）

**本地运行步骤**

0. 克隆代码到本地：
   ```bash
   git clone <your-repo-url>
   cd MindVault
   ```
1. 下载并安置模型文件 (**重要**)

   方式 1. 夸克网盘链接：https://pan.quark.cn/s/83f57790b109

   方式 2. 前往 https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/tree/main

   下载 qwen2.5-1.5b-instruct-q4_k_m.gguf 文件

   下载后放置在 SelfAi 文件夹下，即如下路径：
   ```
   MindVault/SelfAi/qwen2.5-1.5b-instruct-q4_k_m.gguf
   ```

2. 准备配置文件：
   ```bash
   # 从示例复制配置文件
   cp Config.xcconfig.example Config.xcconfig
   # 然后在 Xcode 或编辑器中填入你的 OPENROUTER_API_KEY 等配置
   ```
3. 使用 Xcode 打开 `MindVault/MindVault.xcodeproj`。
4. 选择 Target `Myrisle`，确认 Bundle Identifier、Team、签名配置正确。
5. 选择一个模拟器或真机设备，点击 Run 运行。

> 如果你只想体验纯本地写日记功能，可以暂时不配置 OpenRouter Key，此时情感分析可能不可用或退化为本地逻辑。

---

### 目录结构（简要）

```text
MindVault/
  MindVault/
    MyrisleApp.swift          # 应用入口，处理 Splash / Onboarding / 主内容切换
    ContentView.swift         # 主内容视图（首页 / 日记列表 / 情感曲线等）
    Models/
      DiaryEntry.swift        # 日记数据模型
    Store/
      DiaryStore.swift        # 日记数据读写与业务逻辑
    SelfAi/
      LlamaModel.swift
      OpenRouterService.swift # 调用 OpenRouter LLM 进行情感分析
    Components/               # 公共 UI 组件，如卡片、图表、动画等
    Helpers/                  # 语言、主题、动画、情绪展示等辅助工具
    Views/                    # Splash、Onboarding 以及主要业务页面
    Theme/                    # 主题与配色
    Utils/                    # 通用工具函数
  发布指南.md                 # iOS 打包 / 上架 App Store 指南
  privacy-policy.html         # 隐私政策页面
  README.md                   # 当前文档
```

---

### 配置 OpenRouter（情感分析）

应用通过 `OpenRouterService` 调用 OpenRouter API 对日记内容进行情感分析。  
要启用该功能，你需要：

1. 在 OpenRouter 注册并获取 API Key。
2. 在 `Config.xcconfig` 中填入：
   ```text
   OPENROUTER_API_KEY=sk-xxxxxx
   ```
3. 确保该文件**不会提交到 Git**（项目已在 `.gitignore` 中忽略）。

---

### 打包与发布

如果你需要将应用发布到 App Store 或 TestFlight，可参考根目录下的 `发布指南.md`，其中包含：

- Apple Developer 账号准备
- Xcode 签名与打包（Archive）
- 通过 App Store Connect 上传构建并提交审核
- 使用 TestFlight 进行内部 / 外部测试

---

### 版权与协议

本项目目前为个人 / 内部项目（未明确开源协议）。  
如需二次开发、商用或发布，请与作者沟通。

