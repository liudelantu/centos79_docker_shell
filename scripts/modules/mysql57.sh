#!/bin/bash
# ===========================================
# 文件名: modules/mysql57.sh
# 作用: MySQL 5.7 安装模块（通用）
# 作者: liudelantu
# ===========================================

# 获取脚本目录并加载公共函数库
CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SCRIPT_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"
source "${PARENT_SCRIPT_DIR}/common.sh"

# MySQL 5.7 配置
MYSQL57_DIR="${BASE_DIR}/mysql57"
MYSQL57_PORT=3307
SERVICE_NAME="mysql57"

# 安装函数
install_mysql57() {
    print_header "安装 MySQL 5.7"
    
    print_info "工作目录: ${BASE_DIR}"
    print_info "数据目录: ${MYSQL57_DIR}"
    
    # 检查端口
    if ! check_port $MYSQL57_PORT; then
        read -p "端口 ${MYSQL57_PORT} 已被占用，是否继续？(y/n): " confirm
        [[ ! $confirm =~ ^[Yy]$ ]] && return 1
    fi
    
    # 创建目录
    print_info "创建目录结构..."
    mkdir -p "$MYSQL57_DIR"/{data,conf,logs}
    
    # 生成配置文件
    if [ ! -f "$MYSQL57_DIR/conf/my.cnf" ]; then
        print_info "生成配置文件..."
        cat > "$MYSQL57_DIR/conf/my.cnf" <<EOF
[mysqld]
port=3306
bind-address=0.0.0.0
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
max_connections=200
max_allowed_packet=64M

[client]
default-character-set=utf8mb4
EOF
        print_success "配置文件已生成"
    else
        print_info "配置文件已存在，跳过生成"
    fi
    
    # 初始化 docker-compose.yml
    init_docker_compose
    
    # 追加服务配置
    SERVICE_CONFIG="
  ${SERVICE_NAME}:
    image: mysql:5.7
    container_name: ${SERVICE_NAME}
    restart: always
    ports:
      - \"${MYSQL57_PORT}:3306\"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      TZ: Asia/Shanghai
    volumes:
      - ${MYSQL57_DIR}/data:/var/lib/mysql
      - ${MYSQL57_DIR}/conf:/etc/mysql/conf.d
      - ${MYSQL57_DIR}/logs:/logs
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci"
    
    append_service "$SERVICE_NAME" "$SERVICE_CONFIG"
    
    # 启动服务
    start_service "$SERVICE_NAME" 10
    
    # 显示连接信息
    show_connection_info "$SERVICE_NAME" "$MYSQL57_PORT" "root" "$MYSQL_ROOT_PASSWORD" "$MYSQL57_DIR"
    
    echo ""
    print_info "连接命令: mysql -h 127.0.0.1 -P ${MYSQL57_PORT} -u root -p${MYSQL_ROOT_PASSWORD}"
}

# 卸载函数
uninstall_mysql57() {
    print_header "卸载 MySQL 5.7"
    
    # 检查容器是否存在
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
        print_warning "MySQL 5.7 容器不存在"
        return 1
    fi
    
    print_warning "即将卸载 MySQL 5.7"
    print_info "容器名称: ${SERVICE_NAME}"
    print_info "数据目录: ${MYSQL57_DIR}"
    echo ""
    
    read -p "确认要停止并删除容器吗？(y/n): " confirm_stop
    if [[ $confirm_stop =~ ^[Yy]$ ]]; then
        print_info "停止并删除容器..."
        docker stop "$SERVICE_NAME" 2>/dev/null
        docker rm "$SERVICE_NAME" 2>/dev/null
        print_success "容器已删除"
    else
        print_info "取消操作"
        return 0
    fi
    
    echo ""
    read -p "是否删除数据目录（包含所有数据库）？(y/n): " confirm_data
    if [[ $confirm_data =~ ^[Yy]$ ]]; then
        print_warning "正在删除数据目录..."
        rm -rf "$MYSQL57_DIR"
        print_success "数据目录已删除"
    else
        print_info "数据目录已保留: ${MYSQL57_DIR}"
    fi
    
    echo ""
    read -p "是否从 docker-compose.yml 中删除配置？(y/n): " confirm_config
    if [[ $confirm_config =~ ^[Yy]$ ]]; then
        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
            print_info "删除配置..."
            # 删除服务配置（从服务名到下一个服务或文件结尾）
            sed -i "/^  ${SERVICE_NAME}:/,/^  [a-z]/{ /^  ${SERVICE_NAME}:/d; /^  [a-z]/!d; }" "$DOCKER_COMPOSE_FILE"
            print_success "配置已删除"
        fi
    else
        print_info "配置已保留"
    fi
    
    print_success "MySQL 5.7 卸载完成"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  MySQL 5.7 管理${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "请选择操作："
    echo "  1) 安装 MySQL 5.7"
    echo "  2) 卸载 MySQL 5.7"
    echo "  0) 返回"
    echo ""
}

# 主程序
main() {
    show_menu
    read -p "请输入选项 [0-2]: " choice
    
    case $choice in
        1)
            install_mysql57
            ;;
        2)
            uninstall_mysql57
            ;;
        0)
            print_info "返回主菜单"
            ;;
        *)
            print_error "无效选项"
            ;;
    esac
}

main