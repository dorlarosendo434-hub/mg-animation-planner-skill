# MG动画思路策划 Skill

一个面向中文知识短片的Codex Skill：从确认主题、选择画幅和视觉风格，到规划分镜旁白、生成透明垫图与完整场景、自动编号图片，最终输出可直接交给MG动画工具的完整提示词和素材包。

## 它能做什么

- 推荐或确认适合MG动画的科普主题；
- 自动选择或让用户选择画幅与画面风格；
- 将知识机制拆成6—8个清晰片段；
- 混合规划完整场景、透明主体、纯MG元素与首尾帧；
- 生成并校验`图片01.png—图片NN.png`；
- 输出完整提示词、旁白字幕稿和图片编号清单；
- 自动统一完整场景尺寸并打包ZIP。

## 画幅与风格预设

画幅：16:9、9:16、4:3、3:4、1:1。

风格：霓虹几何、荧光笔记、简约高级、复古档案、复古印刷、美式复古、柔粉水彩、现代UI设计、多彩渐变、扁平卡通、可爱卡通、红黑工业。

用户可以让Skill自动适配，也可以点选预设，或自定义配色、字体、材质、人物媒介、参考图和动效语言。

## 最适配的制作工具

本Skill的平台无关素材包尤其适合以下两类工作流：

### Fotor：直接生成与编辑MG动效

[Fotor AI Motion Graphics Generator](https://www.fotor.com/ai-video-generator/motion-graphics/)和[Fotor Video Agent](https://www.fotor.com/video/)适合接收结构化提示词、图片、首尾帧和多媒体素材，继续完成MG动效、字幕、音频和时间线编辑。

### Claude Opus 5类模型：代码型MG工作流

[Claude Opus 5](https://www.anthropic.com/news/claude-opus-5)及同类高能力代码/智能体模型适合把分镜和素材映射转成HTML/CSS/SVG/Canvas、Remotion或其他代码转视频项目。它们负责理解策划、编写和迭代动画代码，并需要搭配实际的预览与渲染环境；本项目不把Claude描述为独立的一键视频渲染器。

其他支持多图参考、长提示词、图层、时间线或代码动画的工具也可以使用同一套交付物。

## 安装

在PowerShell中执行：

```powershell
git clone https://github.com/dorlarosendo434-hub/mg-animation-planner-skill.git `
  "$env:USERPROFILE\.codex\skills\mg-animation-planner"
```

如果目标目录已经存在，请先备份或更新现有目录，不要直接覆盖自己的修改。

## 使用示例

```text
使用 $mg-animation-planner，给我推荐3个适合做竖屏MG科普动画的主题。
```

```text
使用 $mg-animation-planner，把《为什么你刷到的世界越来越像你自己》做成9:16、现代UI设计风格的完整素材包。
```

```text
使用 $mg-animation-planner，自动适配这个主题的画幅和视觉风格，先给我看一张样图。
```

## 自动编号打包

Skill附带`scripts/package_mg_assets.ps1`，可根据JSON清单：

- 校验图片编号连续；
- 保留透明PNG的Alpha；
- 将完整场景统一成目标画幅；
- 输出`图片01.png—图片NN.png`；
- 生成编号清单和ZIP。

## 仓库结构

```text
mg-animation-planner/
├─ SKILL.md
├─ agents/openai.yaml
├─ references/
│  ├─ workflow.md
│  ├─ style-presets.md
│  ├─ asset-production.md
│  ├─ deliverable-template.md
│  └─ tool-compatibility.md
└─ scripts/package_mg_assets.ps1
```

## 许可与第三方说明

本仓库的代码和文档采用[MIT License](LICENSE)。你可以使用、复制、修改、合并、发布和商业使用，但需要保留原版权声明和许可文本。

Fotor、Claude、Anthropic以及其他第三方名称和商标归其各自权利人所有。本项目与这些公司不存在隶属、授权或背书关系。通过第三方平台生成的图片、视频、音乐、字体、模板和其他内容，仍需遵循相应平台条款与素材许可。

