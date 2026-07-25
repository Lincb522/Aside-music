# NCMDemo - ncm API Swift SDK 示例应用

一个 macOS SwiftUI 示例应用，演示 NeteaseCloudMusicAPI Swift SDK 的核心功能。

## 功能

- **设置** - 配置后端服务地址（代理模式）或直连ncm，设置 Cookie，测试连接
- **搜索** - 搜索歌曲，点击查看歌词
- **歌单** - 浏览热门歌单，查看歌单内歌曲
- **排行榜** - 查看所有排行榜

## 运行

```bash
cd Example/NCMDemo
swift run
```

## 两种模式

1. **直连模式** - 留空服务地址，SDK 自行加密请求ncm
2. **后端代理模式** - 填入部署的 Node 后端地址（如 `http://localhost:3000`），请求走后端
