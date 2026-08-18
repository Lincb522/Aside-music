# Mono 图标语义重复审计

## Pulse Bloom 处理结果

Pulse Bloom 的完整语义已经按“一个业务含义，一个独立轮廓”处理。仅保留两组有意同义项：

- `search` / `magnifyingGlass`：同一搜索动作的两个历史命名。
- `close` / `xmark`：同一关闭动作的两个历史命名。

状态对（如 `home` / `homeFilled`）保持同一母体，但选中态拥有独立信号层；它们不是无差别复用。

本轮拆开的重点重复项：

- `podcast`：改为双节目气泡与播放核心，不再使用麦克风或广播塔。
- `podcast` / `catPodcast`：主 Tab 表达节目内容，分类图标表达播客频道。
- `playNext` / `addToQueue`：分别使用“队列后播放”和“列表加号”轮廓。
- `repeatMode` / `repeatOne`：循环模式与单曲循环拥有不同中心信息。
- `musicNoteList` / `musicNote`：歌曲列表与单音符完全拆分。
- `download` / `playerDownload` / `arrowDownToLine`：通用下载、播放器下载和落线动作分别绘制。
- `play` / `playCircle` / `playCircleFill`：裸播放、圆环播放和实心播放分别绘制。
- `waveform` / `audioWave`：柱形电平与连续音频信号线分别绘制。
- `catMusic` / `musicNote`：音乐分类加入类别信号，不复用普通音符。

## 外观设置专用语义

外观页不再用 `sparkle`、`layers` 或 `playerTheme` 重复表达不同设置。本轮补齐：

- `themeStyle`：全局主题样式。
- `appBrand`：App 品牌图标。
- `interfaceIconSet`：界面图标包。
- `appearanceMode`：自动、浅色与深色外观。
- `systemTabBar`：系统 Tab 栏开关。
- `floatingBarStyle`：悬浮栏样式。
- `liquidGlass`：液态玻璃材质。
- `fluidBackground`：AsideMusic 流体背景。
- `backgroundGlobal`：全局封面背景。
- `backgroundPlaylist`：歌单封面背景。
- `backgroundPlayer`：播放器封面背景。
- `colorEngine`：全局取色引擎。
- `backgroundImage`：主题背景图。
- `gradientStyle`：渐变方式。

所有新增语义均提供独立浅色和深色 SVG，不依赖文字、旋转复用或相同素材别名。

## 现有 Hicon 映射中的重复

当前 Hicon 映射仍有多组不同语义共用同一素材，例如：

- `library` / `headphones`
- `profile` / `profileFilled` / `personEmpty`
- `fm` / `radio` / `catPodcast` / `fmMode`
- `settings` / `equalizer`
- `download` / `playerDownload` / `arrowDownToLine`
- `soundQuality` / `waveform`
- `karaoke` / `catTalkshow` / `microphone`
- `playNext` / `addToQueue`
- `album` / `floatingBall`
- `immersive` / `catEntertain`
- `catDrama` / `mv`

这些属于旧图标库缺少对应素材时的映射复用。Pulse Bloom 不继承这些复用关系。

## 现有 SF Symbols 映射中的重复

SF Symbols 方案中也存在语义复用，主要包括：

- `podcast` / `catTalkshow` / `microphone`
- `fm` / `radio` / `fmMode`
- `soundQuality` / `waveform`
- `info` / `infoCircle` / `logInfo`
- `catElectronic` / `audioWave`
- `catParenting` / `emoji`

这些不会阻止旧图标包继续工作，但后续若要求全局清理，需要分别为每一个旧包补素材，而不是继续改 `MonoIcon` 的语义定义。
