# WindWalker Neumorphism Style Guide

> 这是 WindWalker 的统一 UI 风格描述文件，用于后续 UI 生成与配色规范统一引用。
> 所有页面必须优先使用 `lib/core/theme/neo_components.dart` 中的共享原语，而不是自行拼装 `BoxDecoration`。

## 风格摘要

- **风格定位**：功能平衡型拟物化（B 方向）
- **覆盖范围**：页面级全面重写（C 方向），浅色与深色作为同一视觉语言的两个版本
- **核心特征**：
  - 柔和的软表面背景
  - 大圆角、统一几何语言
  - 克制的外阴影表达外凸表面
  - 轻微内阴影表达内凹控件
  - 低噪音、低饱和度基础表面
  - 对主操作、任务状态、危险操作保留更强对比
- **整体观感**：安静、统一、细腻、有质感，仍保有工具型 App 的效率感。

## 浅色调色板（foggy grey-blue）

| Token | 色值 | 用途 |
|------|------|------|
| `baseBackground` | `#E9EEF5` | 页面背景（雾感浅灰蓝） |
| `raisedSurface` | `#F1F4F8` | 外凸卡片 / 分组面板 |
| `recessedSurface` | `#E3E8F0` | 内凹输入 / 搜索 / 路径 |
| `highlightColor` | `#FFFFFF` | 外凸高光（左上方向） |
| `shadowColor` | `#A8B5C7` | 阴影（右下方向） |
| `primaryAccent` | `#2A7FFF` | 主操作、强调、品牌蓝 |
| `successTint` | `#DBF5EE` | 成功（青绿）柔和底色 |
| `warningTint` | `#FFF1D6` | 下载中 / 警告（暖琥珀）柔和底色 |
| `errorTint` | `#FDE3E5` | 错误 / 危险（柔红）柔和底色 |

## 深色调色板（graphite / blue-black）

> 深色主题独立设计，不是浅色的简单反相。

| Token | 色值 | 用途 |
|------|------|------|
| `baseBackground` | `#111827` | 底层背景（深蓝黑） |
| `raisedSurface` | `#1A2332` | 外凸卡片（比背景稍亮的石墨面） |
| `recessedSurface` | `#0D1522` | 内凹控件（更深的凹槽） |
| `highlightColor` | `#3A4760` | 轻克制冷色高光 |
| `shadowColor` | `#05080F` | 低透明度柔和阴影 |
| `primaryAccent` | `#5B9CFF` | 主强调色（亮度针对深色对比提升） |
| `successTint` | `#1F3D37` | 成功柔和底色 |
| `warningTint` | `#3D3015` | 下载中 / 警告柔和底色 |
| `errorTint` | `#3D1C20` | 错误柔和底色 |

## 语义颜色映射

状态表达优先用「柔和底色 + 清晰标签文字 + 必要图标」组合，而不是高饱和实体块：

| 语义 | 柔和底色 | 前景强调 |
|------|----------|----------|
| 成功 / 完成 / 在线 / 做种 | `successTint` | 青绿（`AppColors.success`） |
| 下载中 / 等待 / 警告 | `warningTint` | 暖琥珀（`AppColors.warning`） |
| 错误 / 删除 / 失败 | `errorTint` | 柔红（`AppColors.error`） |
| 暂停 / 离线 | 蓝灰中性 | 蓝灰（`AppColors.paused`） |

## 阴影 / 高光配方

**外凸表面（raised）**：双阴影，左上高光 + 右下暗影，营造"凸起"。

```
highlightColor  alpha: 浅色 0.95 / 深色 0.05   offset(-6,-6)  blur 12
shadowColor     alpha: 浅色 0.30 / 深色 0.24   offset(8, 8)   blur 16
```

**内凹控件（recessed）**：双阴影反向分布 + 细边框，营造"凹槽"。

```
shadowColor     alpha: 浅色 0.18 / 深色 0.26   offset(4, 4)   blur 10
highlightColor  alpha: 浅色 0.78 / 深色 0.04   offset(-4,-4)  blur 10
border:         highlightColor alpha 浅色 0.65 / 深色 0.08
```

按压反馈通过**深度变化**（压入感）表达，颜色变化是辅助。

## 圆角与间距规则

| 用途 | 圆角 |
|------|------|
| 外凸卡片 `NeoCard` | 24 |
| 分组面板 `NeoSurface` | 28 |
| 内凹输入 `NeoInputShell` | 18 |
| 徽标 / 进度条 | 999（药丸） |

间距沿用 `AppSpacing`：xs=4, sm=8, md=12, lg=16, xl=20, xxl=24。底部操作区 `NeoActionBar` 用 `fromLTRB(16, 8, 16, 12)` + SafeArea。

## 组件行为说明

| 组件 | 默认 | 悬停 | 按下 | 选中 | 禁用 |
|------|------|------|------|------|------|
| `NeoCard` | 外凸 | — | 压入（onTap 可点） | — | — |
| `NeoInputShell` | 内凹 | — | 聚焦更深入 | — | — |
| `NeoButton.primary` | 品牌蓝实心 | — | — | — | 置灰（onPressed=null） |
| `NeoButton.secondary` | 表面色描边 | — | — | — | 置灰 |
| `NeoProgress` | 圆角轨道 | — | — | — | — |
| `NeoBadge` | 柔和底色 + 前景 | — | — | — | — |
| `NeoSection` | 标题 + 副标题 + 外凸正文 | — | — | — | — |
| `NeoActionBar` | 底部固定 SafeArea 卡片 | — | — | — | — |

## 后续生成 UI 时的 do / don't

**Do：**
- 优先使用 `NeoCard` / `NeoSurface` / `NeoSection` 做外凸分组。
- 输入、搜索、路径用 `NeoInputShell`。
- 状态用 `NeoBadge`（柔和底色 + 清晰文字）。
- 进度用 `NeoProgress`，保证可扫描。
- 底部主操作用 `NeoActionBar` + `NeoButton.primary`。

**Don't：**
- 不要在页面内自行拼装 `BoxDecoration` 的颜色、阴影、渐变。
- 不要让所有表面看起来几乎一样（层次靠明度差与阴影表达）。
- 不要仅靠颜色表达状态（必须配合文字标签 / 图标）。
- 不要用纯高饱和实体块铺满区域表达状态。
- 不要用过亮高光或过于松散的模糊阴影（深色尤其会发糊）。
- 不要牺牲任务 / 状态 / 进度的可读性去换取风格纯度。
