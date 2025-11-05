#!/bin/bash
# ===========================================
# 文件名: common.sh
# 作用: 通用公共函数库，供各个模块调用
# 作者: liudelantu
# ===========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置参数 - 从环境变量获取，由 install.sh 设置
BASE_DIR="${BASE_DIR:-$(pwd)}"
DOCKER_COMPOSE_FILE="${BASE_DIR}/docker-compose.yml"
MYSQL_ROOT_PASSWORD="root123"

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

# 检查端口
check_port() {
    local port=$1
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        print_warning "端口 ${port} 已被占用"
        return 1
    fi
    return 0
}

# 初始化 docker-compose.yml
init_docker_compose() {
    if [ ! -d "$BASE_DIR" ]; then
        print_error "工作目录 ${BASE_DIR} 不存在"
        exit 1
    fi
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        cat > $DOCKER_COMPOSE_FILE <<EOF
# Docker Compose 配置文件
# 工作目录: ${BASE_DIR}

services:
EOF
        print_success "已创建 docker-compose.yml"
    fi
}

# 检查服务是否存在
check_service_exists() {
    local service_name=$1
    [ -f "$DOCKER_COMPOSE_FILE" ] && grep -q "^  ${service_name}:" "$DOCKER_COMPOSE_FILE"
}

# 追加服务到 docker-compose.yml
append_service() {
    local service_name=$1
    local service_content=$2
    
    if check_service_exists "$service_name"; then
        print_warning "${service_name} 服务已存在，跳过添加"
        return 1
    fi
    
    echo "$service_content" >> $DOCKER_COMPOSE_FILE
    print_success "${service_name} 服务已添加到 docker-compose.yml"
    return 0
}

# 启动服务
start_service() {
    local service_name=$1
    local wait_time=${2:-10}
    
    print_info "启动 ${service_name} 容器..."
    cd "$BASE_DIR" || exit 1
    docker compose up -d "$service_name"
    
    print_info "等待 ${service_name} 启动（约${wait_time}秒）..."
    sleep "$wait_time"
    
    if docker ps --filter "name=${service_name}" --filter "status=running" | grep -q "${service_name}"; then
        print_success "${service_name} 启动成功！"
        return 0
    else
        print_error "${service_name} 启动失败"
        docker logs "$service_name" --tail=50
        return 1
    fi
}

# 显示连接信息
show_connection_info() {
    local service_name=$1
    local port=$2
    local user=$3
    local password=$4
    local dir=$5
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}${service_name} 连接信息：${NC}"
    echo -e "  主机: 127.0.0.1"
    echo -e "  端口: ${port}"
    echo -e "  用户: ${user}"
    echo -e "  密码: ${password}"
    echo -e "${YELLOW}数据目录：${NC}"
    echo -e "  ${dir}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
}