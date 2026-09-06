#!/bin/bash

# Exit on any error
set -e

# Define color codes for pretty output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Logger functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}
log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}
log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Directory and environment checks
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
log_info "切换工作目录至: ${PROJECT_DIR}"
cd "$PROJECT_DIR"

if [ ! -f "package.json" ]; then
  log_error "当前工作目录没有找到 package.json，请确认项目完整度。"
  exit 1
fi

# 2. Build stage
log_info "正在执行本地打包构建 (npm run build)..."
if npm run build; then
  log_success "本地打包编译成功！"
else
  log_error "本地编译构建失败，请检查前端代码是否存在报错。"
  exit 1
fi

# 3. Create backup on remote server
BACKUP_TS=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/www/backup/mono.zijiu522.cn-${BACKUP_TS}"
LIVE_DIR="/www/wwwroot/mono.zijiu522.cn"

log_info "正在连接 new-server 服务器并创建发布备份..."
# Check if live dir exists before copying, if not exist then skip copy
if ssh new-server "mkdir -p /www/backup && if [ -d \"${LIVE_DIR}\" ]; then cp -r \"${LIVE_DIR}\" \"${BACKUP_DIR}\"; fi"; then
  log_success "远程备份成功，备份路径: ${BACKUP_DIR}"
else
  log_warning "远程备份失败或目录不存在，跳过备份步骤，准备直接发布..."
fi

# 4. Synchronize build artifacts
log_info "正在使用 rsync 增量部署同步本地编译物 dist/ 至生产目录..."
# Keep standalone server pages and older hashed assets used by open clients.
if rsync -az "${PROJECT_DIR}/dist/" "new-server:${LIVE_DIR}/"; then
  log_success "全站最新资源部署同步完成！"
else
  log_error "rsync 资源同步发布失败，请检查网络或服务器权限。"
  exit 1
fi

echo -e "\n${GREEN}${BOLD}🎉 恭喜！一键编译发布流程全部圆满完成！${NC}"
echo -e "${BLUE}预览地址:${NC} https://mono.zijiu522.cn"
