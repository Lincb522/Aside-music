# AsideMusic

iOS 音乐播放器应用，采用 iOS 26 风格液态玻璃设计。

## 依赖

- [LiquidGlassEffect](https://github.com/Lincb522/LiquidGlassEffect) - 液态玻璃效果库

## 构建

```bash
# 生成 Xcode 项目
xcodegen generate

# 构建 IPA
./build_ipa.sh
```

## 配置

在 `.env` 文件中配置 API 地址：

```
API_BASE_URL=your_api_url
```
