#!/bin/bash

# AsideMusic 免签 IPA 可视化编译脚本
# 带进度条、颜色输出和详细状态显示

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 图标
CHECKMARK="✓"
CROSS="✗"
ARROW="→"
ROCKET="🚀"
PACKAGE="📦"
CLEAN="🧹"
BUILD="🔨"
SIGN="✍️"
DONE="✅"

# 配置
SCHEME="AsideMusic"
CONFIGURATION="Release"
IPA_NAME="AsideMusic.ipa"

# 计时器
START_TIME=$(date +%s)

# 打印带颜色的标题
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${ROCKET} ${WHITE}AsideMusic 免签 IPA 编译工具${NC}                     ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 打印步骤
print_step() {
    local step=$1
    local total=$2
    local message=$3
    echo -e "${BOLD}${BLUE}[${step}/${total}]${NC} ${PURPLE}${message}${NC}"
}

# 打印成功消息
print_success() {
    echo -e "${GREEN}${CHECKMARK}${NC} $1"
}

# 打印错误消息
print_error() {
    echo -e "${RED}${CROSS}${NC} $1"
}

# 打印警告消息
print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

# 打印信息
print_info() {
    echo -e "${CYAN}${ARROW}${NC} $1"
}

# 进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}["
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "]${NC} ${WHITE}%3d%%${NC}" $percentage
}

# 执行命令并显示进度
execute_with_progress() {
    local cmd=$1
    local log_file=$2
    local description=$3
    
    echo -e "\n${CYAN}执行中...${NC}"
    
    # 在后台执行命令
    eval "$cmd" > "$log_file" 2>&1 &
    local pid=$!
    
    # 显示进度动画
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${CYAN}${spin:$i:1}${NC} ${description}..."
        sleep 0.1
    done
    
    # 等待命令完成
    wait $pid
    local exit_code=$?
    
    printf "\r"
    
    if [ $exit_code -eq 0 ]; then
        print_success "$description 完成"
        return 0
    else
        print_error "$description 失败"
        echo -e "\n${RED}错误日志:${NC}"
        tail -20 "$log_file"
        return $exit_code
    fi
}

# 清理函数
cleanup_on_error() {
    print_error "编译失败,正在清理..."
    rm -f build.log clean.log
    exit 1
}

# 设置错误处理
trap cleanup_on_error ERR

# 主函数
main() {
    print_header
    
    # 强制使用 Xcode 内置工具链，不使用自定义安装的工具链
    unset TOOLCHAINS
    
    # 从 .env 文件加载环境变量
    if [ -f .env ]; then
        print_info "加载 .env 配置..."
        export $(grep -v '^#' .env | grep -v '^\s*$' | xargs)
        print_success "环境变量已加载"
    fi
    
    # 显示环境信息
    echo -e "\n${BOLD}${WHITE}环境信息:${NC}"
    print_info "Xcode: $(xcodebuild -version | head -1)"
    print_info "Swift: $(swift --version | head -1)"
    print_info "配置: $CONFIGURATION (免签)"
    print_info "目标: $SCHEME"
    echo ""
    
    # 步骤 1: 清理
    print_step 1 4 "${CLEAN} 清理构建目录"
    if execute_with_progress "rm -rf build $IPA_NAME Payload" "clean.log" "清理旧文件"; then
        show_progress 1 4
        echo ""
    else
        exit 1
    fi
    
    # 步骤 2: 构建项目 (免签)
    print_step 2 4 "${BUILD} 构建项目 (免签)"
    print_info "这可能需要几分钟,请耐心等待..."
    
    if execute_with_progress \
        "xcodebuild -project AsideMusic.xcodeproj \
            -scheme $SCHEME \
            -configuration $CONFIGURATION \
            -sdk iphoneos \
            -destination 'generic/platform=iOS' \
            -derivedDataPath build \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY='' \
            API_BASE_URL=\"${API_BASE_URL}\" \
            clean build" \
        "build.log" \
        "构建项目"; then
        show_progress 2 4
        echo ""
    else
        print_error "查看完整日志: cat build.log"
        exit 1
    fi
    
    # 步骤 3: 打包 IPA
    print_step 3 4 "${PACKAGE} 打包 IPA"
    
    print_info "创建 Payload 目录..."
    mkdir -p Payload
    
    print_info "查找 .app 文件..."
    APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" | head -n 1)
    
    if [ -z "$APP_PATH" ]; then
        print_error "未找到 .app 文件"
        exit 1
    fi
    
    print_info "复制 .app 到 Payload..."
    cp -r "$APP_PATH" Payload/
    print_success "已复制 .app 到 Payload"
    
    # 使用 ldid 签名 (如果可用)
    ENTITLEMENTS="Sources/AsideMusic/AsideMusic.entitlements"
    if command -v ldid &> /dev/null && [ -f "$ENTITLEMENTS" ]; then
        print_info "使用 ldid 签名..."
        ldid -S"$ENTITLEMENTS" "Payload/$(basename "$APP_PATH")/$(basename "$APP_PATH" .app)"
        print_success "ldid 签名完成"
    else
        print_warning "ldid 未安装或 entitlements 缺失,跳过签名"
        print_info "安装 ldid: brew install ldid"
    fi
    
    print_info "压缩为 IPA..."
    zip -r "$IPA_NAME" Payload > /dev/null 2>&1
    print_success "IPA 打包完成"
    
    show_progress 3 4
    echo ""
    
    # 步骤 4: 验证和清理
    print_step 4 4 "${DONE} 完成和清理"
    
    if [ -f "$IPA_NAME" ]; then
        local file_size=$(du -h "$IPA_NAME" | cut -f1)
        print_success "IPA 文件已生成: $IPA_NAME"
        print_info "文件大小: $file_size"
        
        # 清理临时文件
        rm -rf Payload
        rm -f build.log clean.log
        print_success "临时文件已清理"
        
        show_progress 4 4
        echo -e "\n"
    else
        print_error "IPA 文件未找到"
        exit 1
    fi
    
    # 计算总耗时
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    # 打印成功信息
    echo ""
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${DONE} ${WHITE}免签 IPA 编译成功!${NC}                               ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${WHITE}文件:${NC} ${CYAN}$IPA_NAME${NC}                                    ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${WHITE}大小:${NC} ${CYAN}$file_size${NC}                                         ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${WHITE}耗时:${NC} ${CYAN}${MINUTES}分${SECONDS}秒${NC}                                    ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BOLD}${WHITE}📱 安装方式:${NC}"
    print_info "使用巨魔 (TrollStore) 安装 - 推荐"
    print_info "使用 AltStore/Sideloadly 自签"
    print_info "使用企业签名工具"
    echo ""
}

# 运行主函数
main
