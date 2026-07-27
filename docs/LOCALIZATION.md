# 本地化维护

Mono 的界面本地化统一放在：

- `Sources/Mono/Resources/zh-Hans.lproj/Localizable.strings`
- `Sources/Mono/Resources/en.lproj/Localizable.strings`

## 代码规则

1. 新文案使用稳定的语义键，例如 `download_batch_added_title`，不再用中文原文充当新键。
2. 带运行时数据的文案必须使用占位符和 `L10n.format`：

   ```swift
   L10n.format("download_batch_queue_added_format", selected.count)
   ```

3. 不要写 `String(localized: "已加入 \(count) 首")`。插值完成后整句话会变成运行时键，英文资源无法命中。
4. 品牌名、协议名、日志、正则表达式和业务原始数据不进入本地化资源。
5. 中英文资源必须拥有相同键集合和相同类型、数量的格式占位符。
6. 只有封闭枚举生成已登记的资源键时，才使用 `L10n.dynamic`。

## 静态审计

不需要运行 Xcode 构建：

```sh
/usr/bin/python3 Tools/audit-localization
```

完整列出历史缺失引用：

```sh
/usr/bin/python3 Tools/audit-localization --max-items 0
```

需要把引用警告作为失败处理时：

```sh
/usr/bin/python3 Tools/audit-localization --strict-references
```

检查资源中已无代码引用的高置信废弃键：

```sh
/usr/bin/python3 Tools/audit-localization --strict-unused
```

确认结果后，同时从简体中文和英文资源中清理这些废弃键：

```sh
/usr/bin/python3 Tools/audit-localization --prune-unused
```

继续清理旧代码中“中文原文充当键”的历史债务时：

```sh
/usr/bin/python3 Tools/audit-localization --strict-legacy
```

审计会检查重复键、中英文键差异、格式占位符差异、英文残留中文、语义键缺失、历史原文键、插值键误用和高置信废弃键。废弃键分析会扫描 App、小组件与共享代码中的字符串引用，并保留已识别的动态键前缀；`--prune-unused` 只会删除各语言资源中共同存在且未被引用的键。普通严格模式只阻止新的语义键问题；`--strict-legacy` 用于逐步清理存量原文键。
