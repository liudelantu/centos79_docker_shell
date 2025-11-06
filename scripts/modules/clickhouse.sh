#!/bin/bash
# ===========================================
# 文件名: modules/clickhouse.sh
# 作用: ClickHouse 安装模块（通用）
# 作者: liudelantu
# ===========================================

# 获取脚本目录并加载公共函数库
CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SCRIPT_DIR="$(dirname "$CURRENT_SCRIPT_DIR")"
source "${PARENT_SCRIPT_DIR}/common.sh"

# ClickHouse 配置
CLICKHOUSE_DIR="${BASE_DIR}/clickhouse"
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_TCP_PORT=9000
CLICKHOUSE_INTERSERVER_PORT=9009
SERVICE_NAME="clickhouse"
CLICKHOUSE_PASSWORD="ClickHouse@123"

# 安装函数
install_clickhouse() {
    print_header "安装 ClickHouse"
    
    print_info "工作目录: ${BASE_DIR}"
    print_info "数据目录: ${CLICKHOUSE_DIR}"
    
    # 检查端口
    for port in $CLICKHOUSE_HTTP_PORT $CLICKHOUSE_TCP_PORT $CLICKHOUSE_INTERSERVER_PORT; do
        if ! check_port $port; then
            read -p "端口 ${port} 已被占用，是否继续？(y/n): " confirm
            [[ ! $confirm =~ ^[Yy]$ ]] && return 1
        fi
    done
    
    # 创建目录
    print_info "创建目录结构..."
    mkdir -p "$CLICKHOUSE_DIR"/{data,logs,config}
    
    # 生成配置文件
    if [ ! -f "$CLICKHOUSE_DIR/config/users.xml" ]; then
        print_info "生成用户配置文件..."
        cat > "$CLICKHOUSE_DIR/config/users.xml" <<'EOF'
<?xml version="1.0"?>
<yandex>
    <users>
        <!-- 默认用户 -->
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
        
        <!-- 管理员用户 -->
        <admin>
            <password>ClickHouse@123</password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </admin>
    </users>
    
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
    </profiles>
    
    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</yandex>
EOF
        print_success "用户配置文件已生成"
    else
        print_info "用户配置文件已存在，跳过生成"
    fi
    
    # 生成服务器配置文件
    if [ ! -f "$CLICKHOUSE_DIR/config/config.xml" ]; then
        print_info "生成服务器配置文件..."
        cat > "$CLICKHOUSE_DIR/config/config.xml" <<'EOF'
<?xml version="1.0"?>
<yandex>
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>
    
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <interserver_http_port>9009</interserver_http_port>
    
    <listen_host>::</listen_host>
    
    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    <mark_cache_size>5368709120</mark_cache_size>
    
    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    
    <users_config>users.xml</users_config>
    
    <default_profile>default</default_profile>
    <default_database>default</default_database>
    
    <timezone>Asia/Shanghai</timezone>
    
    <mlock_executable>false</mlock_executable>
    
    <remote_servers>
        <cluster_1>
            <shard>
                <replica>
                    <host>localhost</host>
                    <port>9000</port>
                </replica>
            </shard>
        </cluster_1>
    </remote_servers>
    
    <zookeeper incl="zookeeper-servers" optional="true" />
    
    <macros incl="macros" optional="true" />
    
    <builtin_dictionaries_reload_interval>3600</builtin_dictionaries_reload_interval>
    
    <max_session_timeout>3600</max_session_timeout>
    <default_session_timeout>60</default_session_timeout>
    
    <query_log>
        <database>system</database>
        <table>query_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>
    
    <query_thread_log>
        <database>system</database>
        <table>query_thread_log</table>
        <partition_by>toYYYYMM(event_date)</partition_by>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_thread_log>
</yandex>
EOF
        print_success "服务器配置文件已生成"
    else
        print_info "服务器配置文件已存在，跳过生成"
    fi
    
    # 初始化 docker-compose.yml
    init_docker_compose
    
    # 追加服务配置
    SERVICE_CONFIG="
  ${SERVICE_NAME}:
    image: clickhouse/clickhouse-server:latest
    container_name: ${SERVICE_NAME}
    restart: always
    ports:
      - \"${CLICKHOUSE_HTTP_PORT}:8123\"
      - \"${CLICKHOUSE_TCP_PORT}:9000\"
      - \"${CLICKHOUSE_INTERSERVER_PORT}:9009\"
    environment:
      CLICKHOUSE_DB: default
      CLICKHOUSE_USER: admin
      CLICKHOUSE_PASSWORD: ${CLICKHOUSE_PASSWORD}
      CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT: 1
      TZ: Asia/Shanghai
    volumes:
      - ${CLICKHOUSE_DIR}/data:/var/lib/clickhouse
      - ${CLICKHOUSE_DIR}/logs:/var/log/clickhouse-server
      - ${CLICKHOUSE_DIR}/config/users.xml:/etc/clickhouse-server/users.xml
      - ${CLICKHOUSE_DIR}/config/config.xml:/etc/clickhouse-server/config.xml
    ulimits:
      nofile:
        soft: 262144
        hard: 262144"
    
    append_service "$SERVICE_NAME" "$SERVICE_CONFIG"
    
    # 启动服务
    print_warning "ClickHouse 首次启动需要 30-60 秒进行初始化..."
    start_service "$SERVICE_NAME" 30
    
    # 显示连接信息
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}ClickHouse 连接信息：${NC}"
    echo -e "  HTTP 端口: ${CLICKHOUSE_HTTP_PORT}"
    echo -e "  TCP 端口:  ${CLICKHOUSE_TCP_PORT}"
    echo -e "  用户名: admin"
    echo -e "  密码: ${CLICKHOUSE_PASSWORD}"
    echo -e "${YELLOW}连接方式：${NC}"
    echo -e "  1. 命令行客户端:"
    echo -e "     clickhouse-client --host 127.0.0.1 --port ${CLICKHOUSE_TCP_PORT} --user admin --password ${CLICKHOUSE_PASSWORD}"
    echo -e "  2. HTTP 接口:"
    echo -e "     curl 'http://127.0.0.1:${CLICKHOUSE_HTTP_PORT}/?user=admin&password=${CLICKHOUSE_PASSWORD}&query=SELECT%20version()'"
    echo -e "  3. JDBC URL:"
    echo -e "     jdbc:clickhouse://127.0.0.1:${CLICKHOUSE_HTTP_PORT}/default?user=admin&password=${CLICKHOUSE_PASSWORD}"
    echo -e "${YELLOW}Web UI：${NC}"
    echo -e "  访问 http://127.0.0.1:${CLICKHOUSE_HTTP_PORT}/play"
    echo -e "${YELLOW}数据目录：${NC}"
    echo -e "  ${CLICKHOUSE_DIR}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    print_info "测试连接: docker exec -it ${SERVICE_NAME} clickhouse-client --user admin --password ${CLICKHOUSE_PASSWORD}"
}

# 卸载函数
uninstall_clickhouse() {
    print_header "卸载 ClickHouse"
    
    # 检查容器是否存在
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${SERVICE_NAME}$"; then
        print_warning "ClickHouse 容器不存在"
        return 1
    fi
    
    print_warning "即将卸载 ClickHouse"
    print_info "容器名称: ${SERVICE_NAME}"
    print_info "数据目录: ${CLICKHOUSE_DIR}"
    echo ""
    print_error "警告：卸载 ClickHouse 将删除所有数据库和表数据！"
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
    read -p "是否删除数据目录（包含所有数据库和表）？(y/n): " confirm_data
    if [[ $confirm_data =~ ^[Yy]$ ]]; then
        print_warning "正在删除数据目录（可能需要一些时间）..."
        rm -rf "$CLICKHOUSE_DIR"
        print_success "数据目录已删除"
    else
        print_info "数据目录已保留: ${CLICKHOUSE_DIR}"
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
    
    print_success "ClickHouse 卸载完成"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  ClickHouse 管理${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "请选择操作："
    echo "  1) 安装 ClickHouse"
    echo "  2) 卸载 ClickHouse"
    echo "  0) 返回"
    echo ""
    echo -e "${BLUE}说明：${NC}"
    echo "  - HTTP 端口: ${CLICKHOUSE_HTTP_PORT}"
    echo "  - TCP 端口: ${CLICKHOUSE_TCP_PORT}"
    echo "  - 默认用户: admin"
    echo "  - 默认密码: ${CLICKHOUSE_PASSWORD}"
    echo ""
}

# 主程序
main() {
    show_menu
    read -p "请输入选项 [0-2]: " choice
    
    case $choice in
        1)
            install_clickhouse
            ;;
        2)
            uninstall_clickhouse
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