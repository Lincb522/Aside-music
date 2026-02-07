# 需求文档

## 简介

为 AsideMusic iOS 应用实现完整的播客/电台功能页面，替换当前播客 tab 中的占位文本。该功能将提供电台推荐、分类浏览、电台详情、节目列表播放等核心能力，与现有的音乐播放体验保持一致的设计风格。

## 术语表

- **Podcast_View**: 播客主页面视图，作为底部 tab 栏的播客入口展示
- **Radio_Station**: 电台实体，包含电台名称、封面、主播信息、节目数量等属性
- **Radio_Program**: 电台节目实体，包含节目名称、时长、播放量等属性
- **Radio_Category**: 电台分类实体，用于对电台进行类型划分
- **Podcast_ViewModel**: 播客页面的视图模型，负责数据获取和状态管理
- **API_Service**: 网络请求服务层，负责与后端 API 通信
- **Player_Manager**: 全局播放管理器，负责音频播放控制
- **Radio_Detail_View**: 电台详情页面，展示电台信息和节目列表
- **Category_Radio_View**: 分类电台列表页面，展示某分类下的热门电台

## 需求

### 需求 1：播客主页面展示

**用户故事：** 作为用户，我希望在播客 tab 看到推荐电台和分类入口，以便快速发现感兴趣的电台内容。

#### 验收标准

1. WHEN 用户切换到播客 tab，THE Podcast_View SHALL 展示个性推荐电台列表（最多6个）
2. WHEN 用户切换到播客 tab，THE Podcast_View SHALL 展示电台分类入口列表
3. WHEN 用户切换到播客 tab，THE Podcast_View SHALL 展示精选电台推荐列表
4. WHEN 播客页面数据正在加载，THE Podcast_View SHALL 展示 AsideLoadingView 加载状态
5. WHEN 用户下拉播客页面，THE Podcast_View SHALL 刷新所有推荐数据

### 需求 2：电台分类浏览

**用户故事：** 作为用户，我希望按分类浏览电台，以便找到特定类型的电台内容。

#### 验收标准

1. WHEN 用户点击某个电台分类，THE Podcast_View SHALL 导航到 Category_Radio_View 展示该分类下的热门电台列表
2. WHEN Category_Radio_View 加载电台列表，THE Category_Radio_View SHALL 支持分页加载更多电台
3. WHEN 用户滚动到 Category_Radio_View 列表底部，THE Category_Radio_View SHALL 自动加载下一页电台数据
4. IF 分类下没有电台数据，THEN THE Category_Radio_View SHALL 展示空状态提示

### 需求 3：电台详情展示

**用户故事：** 作为用户，我希望查看电台的详细信息和节目列表，以便选择感兴趣的节目收听。

#### 验收标准

1. WHEN 用户点击某个电台，THE Podcast_View SHALL 导航到 Radio_Detail_View 展示电台详情
2. WHEN Radio_Detail_View 加载完成，THE Radio_Detail_View SHALL 展示电台名称、封面、主播名称和节目数量
3. WHEN Radio_Detail_View 加载完成，THE Radio_Detail_View SHALL 展示该电台的节目列表
4. WHEN 用户滚动到节目列表底部，THE Radio_Detail_View SHALL 自动加载更多节目
5. IF 电台详情加载失败，THEN THE Radio_Detail_View SHALL 展示错误提示信息

### 需求 4：电台节目播放

**用户故事：** 作为用户，我希望播放电台节目，以便收听播客内容。

#### 验收标准

1. WHEN 用户点击某个电台节目，THE Player_Manager SHALL 开始播放该节目音频
2. WHEN 电台节目正在播放，THE Player_Manager SHALL 在迷你播放器中展示当前节目信息
3. WHEN 用户点击节目列表中的某个节目，THE Player_Manager SHALL 将该电台的节目列表设置为当前播放队列

### 需求 5：播客数据模型

**用户故事：** 作为开发者，我希望有清晰的播客数据模型定义，以便正确解析后端 API 返回的数据。

#### 验收标准

1. THE Radio_Station 模型 SHALL 包含 id、name、picUrl、dj（主播信息）、programCount 字段并实现 Codable 协议
2. THE Radio_Program 模型 SHALL 包含 id、name、duration、listenerCount、coverUrl、mainSong 字段并实现 Codable 协议
3. THE Radio_Category 模型 SHALL 包含 id 和 name 字段并实现 Codable 协议
4. WHEN API 返回电台数据，THE API_Service SHALL 将 JSON 响应解码为对应的 Codable 模型对象
5. FOR ALL 有效的 Radio_Station JSON 数据，解码后再编码再解码 SHALL 产生等价的对象（往返一致性）

### 需求 6：播客网络请求

**用户故事：** 作为开发者，我希望有统一的播客 API 请求方法，以便在视图模型中方便地获取数据。

#### 验收标准

1. THE API_Service SHALL 提供获取个性推荐电台的方法（调用 /dj/personalize/recommend 接口）
2. THE API_Service SHALL 提供获取电台分类列表的方法（调用 /dj/catelist 接口）
3. THE API_Service SHALL 提供获取精选电台推荐的方法（调用 /dj/recommend 接口）
4. THE API_Service SHALL 提供获取电台详情的方法（调用 /dj/detail 接口，参数：id）
5. THE API_Service SHALL 提供获取电台节目列表的方法（调用 /dj/program 接口，参数：radioId、limit、offset）
6. THE API_Service SHALL 提供获取分类热门电台的方法（调用 /dj/radio/hot 接口，参数：cateId、limit、offset）
7. WHEN 网络请求失败，THE API_Service SHALL 通过 Combine 的 Error 类型传递错误信息

### 需求 7：播客页面导航

**用户故事：** 作为用户，我希望在播客相关页面之间流畅导航，以便获得一致的浏览体验。

#### 验收标准

1. THE Podcast_View SHALL 使用 NavigationStack 管理页面导航
2. WHEN 用户从电台详情页返回，THE Podcast_View SHALL 恢复之前的滚动位置和数据状态
3. WHEN 用户在 Category_Radio_View 点击某个电台，THE Category_Radio_View SHALL 导航到 Radio_Detail_View

### 需求 8：播客页面视觉设计

**用户故事：** 作为用户，我希望播客页面与应用整体风格一致，以便获得统一的视觉体验。

#### 验收标准

1. THE Podcast_View SHALL 使用 AsideBackground 作为背景并支持深色和浅色模式自适应
2. THE Podcast_View SHALL 使用现有设计系统中的颜色（asideTextPrimary、asideCardBackground 等）
3. THE Podcast_View SHALL 使用 .rounded 设计风格的字体
4. THE Podcast_View SHALL 使用 AsideBouncingButtonStyle 作为可交互元素的按钮样式
