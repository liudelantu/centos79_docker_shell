#!/bin/bash
# ===========================================
# 文件名: modules/gitlab.sh
# 作用: GitLab 安装模块（通用）
# 作者: liudelantu
# ===========================================

# 获取脚本目录并加载公共函数库
CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SCRIPT_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"
source "${PARENT_SCRIPT_DIR}/common.sh"

# GitLab 配置
GITLAB_DIR="${BASE_DIR}/gitlab"
GITLAB_HTTP_PORT=8080
GITLAB_HTTPS_PORT=8443
GITLAB_SSH_PORT=2222
SERVICE_NAME="gitlab"

# 安装函数
install_gitlab() {
    print_header "安装 GitLab"
    
    print_info "工作目录: ${BASE_DIR}"
    print_info "数据目录: ${GITLAB_DIR}"
    
    # 检查端口
    print_info "检查端口占用情况..."
    for port in $GITLAB_HTTP_PORT $GITLAB_HTTPS_PORT $GITLAB_SSH_PORT; do
        if ! check_port $port; then
            read -p "端口 ${port} 已被占用，是否继续？(y/n): " confirm
            [[ ! $confirm =~ ^[Yy]$ ]] && return 1
        fi
    done
    
    # 创建目录
    print_info "创建目录结构..."
    mkdir -p "$GITLAB_DIR"/{config,logs,data}
    
    # 初始化 docker-compose.yml
    init_docker_compose
    
    # 追加服务配置
    SERVICE_CONFIG="
  ${SERVICE_NAME}:
    image: gitlab/gitlab-ce:latest
    container_name: ${SERVICE_NAME}
    restart: always
    hostname: gitlab.example.com
    ports:
      - \"${GITLAB_HTTP_PORT}:80\"
      - \"${GITLAB_HTTPS_PORT}:443\"
      - \"${GITLAB_SSH_PORT}:22\"
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.example.com:${GITLAB_HTTP_PORT}'
        gitlab_rails['gitlab_shell_ssh_port'] = ${GITLAB_SSH_PORT}
    volumes:
      - ${GITLAB_DIR}/config:/etc/gitlab
      - ${GITLAB_DIR}/logs:/var/log/gitlab
      - ${GITLAB_DIR}/data:/var/opt/gitlab
    shm_size: '256m'"
    
    append_service "$SERVICE_NAME" "$SERVICE_CONFIG"
    
    # 启动服务（GitLab 需要更长时间）
    print_warning "GitLab 首次启动需要 3-5 分钟，请耐心等待..."
    start_service "$SERVICE_NAME" 180
    
    # 显示连接信息
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}GitLab 访问信息：${NC}"
    echo -e "  HTTP:  http://127.0.0.1:${GITLAB_HTTP_PORT}"
    echo -e "  HTTPS: https://127.0.0.1:${GITLAB_HTTPS_PORT}"
    echo -e "  SSH:   ssh://git@127.0.0.1:${GITLAB_SSH_PORT}"
    echo -e "${YELLOW}初始密码获取：${NC}"
    echo -e "  docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password"
    echo -e "${YELLOW}数据目录：${NC}"
    echo -e "  ${GITLAB_DIR}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
}

# 卸载函数
uninstall_gitlab() {
    print_header "卸载 GitLab"
    
    # 检查容器是否存在
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
        print_warning "GitLab 容器不存在"
        return 1
    fi
    
    print_warning "即将卸载 GitLab"
    print_info "容器名称: ${SERVICE_NAME}"
    print_info "数据目录: ${GITLAB_DIR}"
    echo ""
    print_error "警告：卸载 GitLab 将删除所有仓库、用户、项目数据！"
    echo ""
    
    read -p "确认要停止并删除容器吗？(y/n): " confirm_stop
    if [[ $confirm_stop =~ ^[Yy]$ ]]; then
        print_info "停止并删除容器（可能需要一些时间）..."
        docker stop "$SERVICE_NAME" 2>/dev/null
        docker rm "$SERVICE_NAME" 2>/dev/null
        print_success "容器已删除"
    else
        print_info "取消操作"
        return 0
    fi
    
    echo ""
    read -p "是否删除数据目录（包含所有 Git 仓库和配置）？(y/n): " confirm_data
    if [[ $confirm_data =~ ^[Yy]$ ]]; then
        print_warning "正在删除数据目录（可能需要较长时间）..."
        rm -rf "$GITLAB_DIR"
        print_success "数据目录已删除"
    else
        print_info "数据目录已保留: ${GITLAB_DIR}"
    fi
    
    echo ""
    read -p "是否从 docker-compose.yml 中删除配置？(y/n): " confirm_config
    if [[ $confirm_config =~ ^[Yy]$ ]]; then
        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
            print_info "删除配置..."
            sed -i "/^  ${SERVICE_NAME}:/,/^  [a-z]/{ /^  ${SERVICE_NAME}:/d; /^  [a-z]/!d; }" "$DOCKER_COMPOSE_FILE"
            print_success "配置已删除"
        fi
    else
        print_info "配置已保留"
    fi
    
    print_success "GitLab 卸载完成"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  GitLab 管理${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "请选择操作："
    echo "  1) 安装 GitLab"
    echo "  2) 卸载 GitLab"
    echo "  0) 返回"
    echo ""
}

# 主程序
main() {
    show_menu
    read -p "请输入选项 [0-2]: " choice
    
    case $choice in
        1)
            install_gitlab
            ;;
        2)
            uninstall_gitlab
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