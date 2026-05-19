#!/usr/bin/env python3
"""在 ProfileView.swift 中所有缺少 ListeningStatsView 入口的 StorageManageView 前面插入"""

path = 'Sources/Monologue/Views/ProfileView.swift'
with open(path, 'r') as f:
    lines = f.readlines()

result = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # 检测 StorageManageView 入口
    if 'NavigationLink(destination: StorageManageView' in line or ('destination: StorageManageView' in line and 'NavigationLink' in line):
        # 往回看 20 行内是否已有 ListeningStatsView
        lookback = ''.join(lines[max(0, i-20):i])
        if 'ListeningStatsView' not in lookback:
            # 需要插入。检测缩进
            indent = len(line) - len(line.lstrip())
            ind = ' ' * indent
            
            # 检测上面用的是什么组件风格
            context = ''.join(lines[max(0, i-30):i])
            
            if 'MangaProfileActionRow' in context:
                insert = f'''
{ind}MangaProfileActionDivider()

{ind}NavigationLink(destination: ListeningStatsView()) {{
{ind}    MangaProfileActionRow(
{ind}        icon: .sparkle,
{ind}        title: String(localized: "听歌统计"),
{ind}        value: "STATS",
{ind}        tint: MangaStyle.decoBlue
{ind}    )
{ind}}}
{ind}.buttonStyle(.plain)

'''
            elif 'MujiProfileLedgerRow' in context:
                insert = f'''
{ind}MujiProfileDivider()

{ind}NavigationLink(destination: ListeningStatsView()) {{
{ind}    MujiProfileLedgerRow(
{ind}        icon: .sparkle,
{ind}        title: String(localized: "听歌统计"),
{ind}        value: "STATS"
{ind}    )
{ind}}}
{ind}.buttonStyle(.plain)

'''
            elif 'NeumorphicProfileShortcutTile' in context:
                insert = f'''
{ind}NavigationLink(destination: ListeningStatsView()) {{
{ind}    NeumorphicProfileShortcutTile(
{ind}        icon: .sparkle,
{ind}        title: String(localized: "听歌统计"),
{ind}        value: "STATS",
{ind}        tint: NeumorphicStyle.accent
{ind}    )
{ind}}}
{ind}.buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

'''
            elif 'ProfileMenuRow' in context:
                insert = f'''
{ind}NavigationLink(destination: ListeningStatsView()) {{
{ind}    ProfileMenuRow(
{ind}        icon: .sparkle,
{ind}        title: String(localized: "听歌统计")
{ind}    )
{ind}}}
{ind}.buttonStyle(CapsulePressStyle())

'''
            elif 'liquidGlassProfilePortalTile' in context:
                insert = f'''
{ind}NavigationLink(destination: ListeningStatsView()) {{
{ind}    liquidGlassProfilePortalTile(
{ind}        icon: .sparkle,
{ind}        title: String(localized: "听歌统计"),
{ind}        value: "STATS",
{ind}        tint: LiquidGlassStyle.violet
{ind}    )
{ind}}}
{ind}.buttonStyle(.plain)

'''
            else:
                # 通用 fallback
                insert = f'''
{ind}NavigationLink(destination: ListeningStatsView()) {{
{ind}    ProfileMenuRow(
{ind}        icon: .sparkle,
{ind}        title: String(localized: "听歌统计")
{ind}    )
{ind}}}
{ind}.buttonStyle(.plain)

'''
            result.append(insert)
    
    result.append(line)
    i += 1

with open(path, 'w') as f:
    f.writelines(result)

# 验证
with open(path, 'r') as f:
    content = f.read()
count = content.count('ListeningStatsView')
print(f'Done. ListeningStatsView appears {count} times in file.')
