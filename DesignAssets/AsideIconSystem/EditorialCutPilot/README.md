# Aside Editorial Cut Pilot

12 枚高频图标的方向验证稿。它不是完整图标包，也未接入 App。

## 设计方向

- 单色 `currentColor`，次级结构只使用同一墨色的 28% 层级
- 实形与负形切口，不采用整套廉价细描边
- 平直端点为主，曲线只保留给必要语义
- 24×24 网格，至少 2 unit 安全区
- 14–19 pt 的真实使用尺寸优先
- 不包含固定紫色、渐变、阴影或流体背景语言

## 重建与验证

```bash
/usr/bin/python3 build_pilot.py
/usr/bin/python3 /Users/linchengbo/.codex/skills/craft-svg-icon-system/scripts/audit_icon_set.py src --expected-count 12 --viewbox "0 0 24 24" --max-colors 0 --json-out reports/audit-source.json
/usr/bin/python3 /Users/linchengbo/.codex/skills/craft-svg-icon-system/scripts/audit_icon_set.py dist --expected-count 12 --viewbox "0 0 24 24" --max-colors 0 --json-out reports/audit-dist.json
NODE_PATH=/Users/linchengbo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules /Users/linchengbo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node render_contact_sheets.mjs
```
