# Song Content 数据字典

| 表 | 作用 | 关键约束 |
|---|---|---|
| `songs` | 统一歌曲实体 | 主键为内部 ID；保存身份状态和当前发布指针 |
| `platform_song_mappings` | 平台歌曲映射 | `platform + platform_song_id` 唯一 |
| `content_sources` | 可核验来源 | 保存标题、发布方、抓取时间、等级、摘要和哈希 |
| `song_content_versions` | 不可覆盖的内容版本 | 状态为草稿、待审核、已发布、下线或驳回 |
| `song_content_publications` | 每首歌、语言的当前发布指针 | 发布和回滚在事务中切换 |
| `content_version_sources` | 内容字段与来源关联 | 保存来源支撑的字段列表 |
| `generation_jobs` | 持久化生成任务 | 活跃任务幂等键唯一；保存租约、错误、Token 和费用 |
| `generation_job_sources` | 任务证据关联 | 任务和来源多对多 |
| `song_content_whitelist` | 首次生成白名单 | 非白名单歌曲不调用 AI |
| `song_content_config_versions` | 内容生成与客户端配置版本 | 草稿、验证、发布和归档版本不可覆盖 |
| `song_content_config_publication` | 当前公开配置指针 | 单例发布指针 |
| `ai_provider_credentials` | 兼容的服务端加密凭据 | AES-256-GCM；不明文回显 |
| `song_content_roles` | Agent 管理角色 | 编辑、审核、管理员 |
| `song_content_role_permissions` | 角色权限 | 内容、任务、来源、配置、权限和审计分权 |
| `song_content_admin_assignments` | 外部管理员与角色关联 | 复用 token-admin 管理身份 |
| `song_content_audit_logs` | 操作审计 | 保存操作者、请求、前后差异和元数据 |
| `announcements` | 通用公告及投放规则 | 草稿/发布/下线；展示版本递增；支持时间、版本、平台和地区范围 |

App AI 的现行配置继续使用 token-admin 的 `data.json.aiProviderConfig`。Agent 管理直接读写该对象，歌曲内容 Worker 通过只读配置提供器复用相同协议、API 地址、模型、自定义请求头和密钥。
