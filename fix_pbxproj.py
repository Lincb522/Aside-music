import re

with open('AsideMusic.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Replace XCRemoteSwiftPackageReference with XCLocalSwiftPackageReference in section headers and comments
content = content.replace('XCRemoteSwiftPackageReference', 'XCLocalSwiftPackageReference')

# LiquidGlass
content = re.sub(
    r'repositoryURL = "https://github\.com/[^"]*LiquidGlass\.git";\s*requirement = \{.*?\};',
    r'relativePath = "LiquidGlass-main";',
    content,
    flags=re.DOTALL
)

# NeteaseCloudMusicAPI
content = re.sub(
    r'repositoryURL = "https://github\.com/[^"]*NeteaseCloudMusicAPI-Swift\.git";\s*requirement = \{.*?\};',
    r'relativePath = "NeteaseCloudMusicAPI-Swift";',
    content,
    flags=re.DOTALL
)

# MusicKit -> QQMusicKit
content = re.sub(
    r'repositoryURL = "https://github\.com/[^"]*MusicKit\.git";\s*requirement = \{.*?\};',
    r'relativePath = "QQMusicKit";',
    content,
    flags=re.DOTALL
)

# FFmpegSwiftSDK
content = re.sub(
    r'repositoryURL = "https://github\.com/[^"]*FFmpegSwiftSDK\.git";\s*requirement = \{.*?\};',
    r'relativePath = "ffmpeg-swift";',
    content,
    flags=re.DOTALL
)

with open('AsideMusic.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
