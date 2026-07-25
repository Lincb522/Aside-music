# mono 网页端设计系统 (Design System)

本文档旨在详尽梳理并定义 **mono** 前端界面的高保真视觉规范、交互状态、设计口径（Design Tokens）以及核心交互组件标准，以保证界面后续迭代的整体美学完整度与体验一致性。

---

## 一、 设计哲学 (Design Philosophy)

**mono** 的界面美学秉承 **温润有机 (Warm & Organic)** 与 **数字物理化 (Digital Skeuomorphism)** 的交叉融合：
1. **温润护眼**：摒弃传统纯白（#FFF）和深灰，底色采用温润舒缓的燕麦奶乳白色体系，文字与视觉元素使用高纯度暖棕色和香槟金色。
2. **磨砂玻璃与弥散发光 (Glassmorphism & Fluid Diffusion)**：强调深度与层级。界面充满厚重的模糊感（30px Backdrop Blur）以及随音乐封面自适应改变色彩的动态弥散发光体。
3. **数字复古像素化 (Lo-Fi Grid & Hi-Fi Fluid)**：极具现代感的流体圆角和玻璃面板，搭配复古感强烈的数字像素化波纹柱（Equalizer），打造跨时代的数字物理交互魅力。

---

## 二、 设计口径 / 设计令牌 (Design Tokens)

### 1. 色彩系统 (Color Palette)

#### 基础层底色
*   **页面背景色 (`--page-bg`)**：`#fffdf8`（极其温润的燕麦乳白纸张底色）
*   **文本首要深暖棕色**：`#31261d`（高对比主文字色，饱满而不刺眼）
*   **文本次要暖棕灰色**：`#746c61` / `rgba(49, 38, 29, 0.65)`（副标题、辅助信息）

#### 动态弥散流体发光色彩（CSS 变量驱动）
由当前播放歌曲封面，通过 HTML5 Canvas 提取核心高纯度主色调，动态注入文档根节点（默认兜底值为落日橙金暖色系）：
*   **发光主色 1 (`--ambient-rgb-1`)**：`255, 184, 108`
*   **发光主色 2 (`--ambient-rgb-2`)**：`248, 183, 15`
*   **发光主色 3 (`--ambient-rgb-3`)**：`255, 218, 123`

#### 功能/状态色
*   **绿色 (Active/正常激活)**：`#86deb0`
*   **橙色 (Playing/过期状态)**：`#ff9f43`

---

### 2. 质感与层级 (Textures & Elevations)

#### 超磨砂玻璃质感 (Ultimate Glassmorphic Panel)
用于迷你播放器浮窗、对话框和特色卡片。其特征是超高饱和度、极致模糊、以及内侧高亮微边框：
*   **背景色**：`rgba(255, 253, 248, 0.24)`
*   **边缘内发光 (Border)**：`1px solid rgba(255, 255, 255, 0.42)`
*   **多层有机物理阴影 (Box Shadow)**：
    ```css
    box-shadow:
      0 24px 56px rgba(154, 116, 52, 0.12),
      0 4px 16px rgba(154, 116, 52, 0.04),
      0 1px 1px 0 rgba(255, 255, 255, 0.72) inset; /* 内阴影高光 */
    ```
*   **背景滤镜 (Backdrop Filter)**：`backdrop-filter: blur(30px) saturate(210%);`

---

### 3. 字体系统 (Typography System)

全站字体采用现代非等宽无衬线字体，字重极其厚重，凸显高端拟物标签感：
*   **主标题 (Title)**：`font-weight: 900`
*   **小标题/次要标签**：`font-weight: 760` / `680`
*   **正文/输入框**：`font-weight: 500`

---

## 三、 核心物理化交互组件规范 (Core UI Components)

### 1. 弥散式全屏背景灯效 (`.dynamic-ambient-backdrop`)
由三颗具有模糊、缩放、自旋转、以及色彩交叉渐变的大型气态发光球体组成。
*   **毛玻璃深度**：大面积虚化。
*   **自适应机制**：播放不同音乐时，Canvas 实时刷新对应的 `--ambient-rgb` 变量，光球会自动以液态流转过渡到新配色。

### 2. 黑胶唱片迷你播放器 (`.mini-player`)
结合了“黑胶唱片浮动球”与“横向极窄控制面板”的拟物浮窗。
*   **唱片球状态**：
    *   **播放状态 (`.is-playing`)**：黑胶唱盘保持以 `9s` 线性匀速无限顺时针旋转，同时唱片球右上角指示灯由绿色（`#86deb0`）切换至播放状态下的呼吸橙色（`#ff9f43`）。
    *   **展开状态 (`.is-expanded`)**：面板向左以弹性曲线展出。
*   **唱盘设计**：使用多重径向与重复径向渐变，逼真还原黑胶唱片的光栅反光、黑胶纹理和音轨段落感：
    ```css
    background:
      radial-gradient(circle at center, rgba(255, 248, 209, 0.95) 0 9%, rgba(111, 75, 22, 0.78) 10% 16%, transparent 17%),
      radial-gradient(circle at 36% 30%, rgba(255, 255, 255, 0.36), transparent 28%),
      repeating-radial-gradient(circle, rgba(76, 56, 32, 0.22) 0 5px, rgba(122, 90, 49, 0.18) 6px 7px, rgba(75, 52, 32, 0.22) 8px 12px);
    ```

---

## 四、 音纹跃动系统规范 (Equalizer & Wave Ripple)

这是 **mono** 最核心的物理化声波视效，横跨整个屏幕底部（全宽铺满），极具沉浸感。

### 1. 格子像素化架构 (Pixel Grid Equalizer)
*   **物理组成**：全站渲染 160 个自适应弹性柱状体（`span`），在宽屏下拉宽，在窄屏手机上无缝缩进，绝不产生物理溢出。
*   **间距策略**：`gap: clamp(2px, 0.35vw, 4px)`。

### 2. 独立不拉伸遮罩技术 (Pixel-Perfect Mask)
由于 CSS 传统的 `transform: scaleY()` 会使子元素图案产生垂直拉伸，因此我们放弃 `scaleY` 动画，直接采用**高度动画 + 独立不缩放渐变遮罩**：
*   **渐变遮罩 (Mask)**：在每个柱体上固定一层以像素高度为单位的遮罩，使它们在跃动时永远锁定在像素网格线中，实现极高清晰度的复古 LED 显示屏观感。
    ```css
    -webkit-mask-image: repeating-linear-gradient(to top, #000 0px, #000 3px, transparent 3px, transparent 4px); /* 3px 实体块, 1px 空白缝隙 */
    ```

### 3. 横向正弦波浪延迟算法 (Traveling Wave Delay Ripple)
所有音纹柱共用一套缓动动画 `soundwaveGridRise`（从最小高度 `3px` 渐变至当前柱体设定的自适应最大峰值高度 `--peak-height`）。通过对 160 个柱体注入等差的时间延迟（Animation Delay Offset），在物理上呈现出流畅自左往右传递的正弦波动效果：
*   **公式算法**：`animation-delay: calc(var(--i) * -0.012s);`
*   **波峰变化级数**：5阶律动设计：
    *   第 1 阶 (`5n + 1`)：`--peak-height: 16px;`
    *   第 2 阶 (`5n + 2`)：`--peak-height: 28px;`
    *   第 3 阶 (`5n + 3`)：`--peak-height: 12px;`
    *   第 4 阶 (`5n + 4`)：`--peak-height: 32px;`
    *   第 5 阶 (`5n + 5`)：`--peak-height: 20px;`

此系统不仅确保了像素点的高保真对齐，更为网页底栏增添了一抹细腻、优雅、随动态封面而波动的音乐视听浪潮。
