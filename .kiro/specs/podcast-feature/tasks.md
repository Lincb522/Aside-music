# 实现计划：播客功能

## 概述

基于设计文档，将播客功能拆分为增量式编码任务。每个任务构建在前一个任务之上，确保代码始终可集成。

## 任务

- [ ] 1. 创建播客数据模型
  - [x] 1.1 在 `Sources/AsideMusic/Models/` 下创建 `RadioModels.swift`，定义 RadioStation、DJUser、RadioProgram、RadioCategory 模型及所有 API 响应包装类型（DJPersonalizeResponse、DJCategoryResponse、DJRecommendResponse、DJDetailResponse、DJProgramResponse、DJCategoryHotResponse）
    - 所有模型实现 Codable 协议
    - RadioStation 和 RadioCategory 实现 Hashable 协议
    - RadioProgram 包含 durationText 计算属性
    - RadioStation 包含 coverUrl 计算属性
    - _Requirements: 5.1, 5.2, 5.3_
  - [ ] 1.2 编写 RadioStation、RadioProgram、RadioCategory 的往返属性测试
    - **Property 1: 电台模型往返一致性**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**
  - [ ] 1.3 编写 RadioProgram.durationText 的属性测试
    - **Property 5: 节目时长格式化正确性**
    - **Validates: Requirements 5.2**

- [ ] 2. 扩展 APIService 添加播客 API 方法
  - [x] 2.1 在 `Sources/AsideMusic/Network/APIService.swift` 中添加播客相关 API 方法
    - fetchDJPersonalizeRecommend(limit:) → AnyPublisher<[RadioStation], Error>
    - fetchDJCategories() → AnyPublisher<[RadioCategory], Error>
    - fetchDJRecommend() → AnyPublisher<[RadioStation], Error>
    - fetchDJDetail(id:) → AnyPublisher<RadioStation, Error>
    - fetchDJPrograms(radioId:limit:offset:) → AnyPublisher<[RadioProgram], Error>
    - fetchDJCategoryHot(cateId:limit:offset:) → AnyPublisher<[RadioStation], Error>
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [ ] 3. 实现 PodcastViewModel
  - [x] 3.1 在 `Sources/AsideMusic/ViewModels/` 下创建 `PodcastViewModel.swift`
    - 实现 fetchData() 方法，并行加载个性推荐、分类列表、精选推荐
    - 实现 refreshData() 方法用于下拉刷新
    - 管理 isLoading、errorMessage 状态
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [ ] 3.2 编写个性推荐电台数量约束的属性测试
    - **Property 2: 个性推荐电台数量约束**
    - **Validates: Requirements 1.1**

- [x] 4. 实现 PodcastView 播客主页面
  - [x] 4.1 在 `Sources/AsideMusic/Views/` 下创建 `PodcastView.swift`
    - 使用 NavigationStack 管理导航
    - 实现标题栏、分类入口（横向滚动）、推荐电台区域（横向滚动卡片）、精选电台区域
    - 使用 AsideBackground、AsideLoadingView、CachedAsyncImage、AsideBouncingButtonStyle 等现有组件
    - 支持下拉刷新
    - 定义 PodcastDestination 导航枚举
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 7.1, 8.1, 8.2, 8.3, 8.4_
  - [x] 4.2 修改 `Sources/AsideMusic/Views/ContentView.swift`，将播客 tab 的占位文本替换为 PodcastView()
    - _Requirements: 1.1_

- [x] 5. Checkpoint - 确保播客主页面可正常编译和展示
  - 确保所有代码编译通过，如有问题请询问用户。

- [ ] 6. 实现 CategoryRadioViewModel 和 CategoryRadioView
  - [x] 6.1 在 `Sources/AsideMusic/ViewModels/` 下创建 `CategoryRadioViewModel.swift`
    - 实现 fetchRadios() 和 loadMore() 分页加载逻辑
    - 去重处理（过滤已存在的电台 ID）
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [x] 6.2 在 `Sources/AsideMusic/Views/` 下创建 `CategoryRadioView.swift`
    - 展示分类名称标题
    - LazyVStack 展示电台列表，支持滚动到底部自动加载
    - 空状态提示
    - 点击电台导航到 RadioDetailView
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 8.1, 8.2, 8.3, 8.4_
  - [ ] 6.3 编写分页加载列表增长的属性测试
    - **Property 3: 分页加载列表增长**
    - **Validates: Requirements 2.2**

- [ ] 7. 实现 RadioDetailViewModel 和 RadioDetailView
  - [x] 7.1 在 `Sources/AsideMusic/ViewModels/` 下创建 `RadioDetailViewModel.swift`
    - 实现 fetchDetail() 加载电台详情
    - 实现 fetchPrograms() 和 loadMorePrograms() 分页加载节目
    - 错误处理和状态管理
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 7.2 在 `Sources/AsideMusic/Views/` 下创建 `RadioDetailView.swift`
    - 电台封面和基本信息展示（名称、主播、节目数）
    - 节目列表（LazyVStack，支持分页）
    - 点击节目触发播放（通过 PlayerManager）
    - 错误状态展示
    - 使用 AsideBackButton 返回导航
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 8.1, 8.2, 8.3, 8.4_
  - [ ] 7.3 编写播放队列完整性的属性测试
    - **Property 4: 播放队列完整性**
    - **Validates: Requirements 4.3**

- [x] 8. 连接导航并集成所有页面
  - [x] 8.1 在 PodcastView 中添加 navigationDestination，连接 CategoryRadioView 和 RadioDetailView
    - 确保从分类页也能导航到电台详情页
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 9. 最终 Checkpoint - 确保所有功能正常工作
  - 确保所有代码编译通过，所有测试通过，如有问题请询问用户。

## 备注

- 所有任务均为必需，包括属性测试
- 每个任务引用了具体的需求编号以确保可追溯性
- Checkpoint 任务用于增量验证
- 属性测试验证通用正确性属性，单元测试验证具体示例和边界情况
