#!/bin/bash
# ===========================================
# 文件名: install.sh
# 作用: 通用安装脚本，可在任意目录使用
# 作者: liudelantu
# 用法: cd /your_dir && ./scripts/install.sh
# ===========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 动态获取路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"  # scripts 的父目录
MODULES_DIR="${SCRIPT_DIR}/modules"

# 导出变量供子脚本使用
export BASE_DIR
export SCRIPT_DIR

# 工具函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查模块脚本是否存在
check_module() {
    local module=$1
    if [ ! -f "${MODULES_DIR}/${module}" ]; then
        print_error "模块脚本 ${module} 不存在"
        print_error "路径: ${MODULES_DIR}/${module}"
        return 1
    fi
    return 0
}

# 执行模块安装
run_module() {
    local module=$1
    if check_module "${module}"; then
        print_info "开始执行 ${module}..."
        bash "${MODULES_DIR}/${module}"
        if [ $? -eq 0 ]; then
            print_success "${module} 执行完成"
            return 0
        else
            print_error "${module} 执行失败"
            return 1
        fi
    fi
    return 1
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
╔════════════════════════════════════════╗
║      Docker 服务安装管理脚本           ║
║           Author: liudelantu           ║
╚════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "请选择要安装的服务："
    echo "  1) MySQL 5.7"
    echo "  2) MySQL 8.0"
    echo "  3) MySQL 5.7 + 8.0"
    echo "  4) GitLab"
    echo "  5) 查看运行状态"
    echo "  0) 退出"
    echo ""
    echo -e "${BLUE}当前工作目录: ${BASE_DIR}${NC}"
    echo -e "${BLUE}脚本目录: ${SCRIPT_DIR}${NC}"
    echo ""
}

# 查看状态
show_status() {
    print_info "Docker 容器运行状态："
    echo ""
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null; then
        echo ""
        print_info "Docker Compose 文件: ${BASE_DIR}/docker-compose.yml"
        if [ -f "${BASE_DIR}/docker-compose.yml" ]; then
            echo -e "\n${YELLOW}已安装的服务：${NC}"
            grep "^  [a-z]" "${BASE_DIR}/docker-compose.yml" | sed 's/:$//' | sed 's/^/  - /'
        fi
    else
        print_error "无法获取容器状态，请检查 Docker 是否运行"
    fi
    echo ""
    read -p "按回车键继续..."
}

# 主程序
main() {
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose 未安装或版本过低"
        exit 1
    fi
    
    # 检查脚本目录结构
    if [ ! -d "${MODULES_DIR}" ]; then
        print_error "模块目录不存在: ${MODULES_DIR}"
        print_info "请确保目录结构完整"
        exit 1
    fi
    
    # 检查 common.sh
    if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
        print_error "公共函数库不存在: ${SCRIPT_DIR}/common.sh"
        exit 1
    fi
    
    print_success "脚本初始化成功"
    print_info "工作目录: ${BASE_DIR}"
    sleep 1
    
    while true; do
        show_menu
        read -p "请输入选项 [0-5]: " choice
        
        case $choice in
            1)
                run_module "mysql57.sh"
                read -p "按回车键继续..."
                ;;
            2)
                run_module "mysql80.sh"
                read -p "按回车键继续..."
                ;;
            3)
                run_module "mysql57.sh"
                echo ""
                run_module "mysql80.sh"
                read -p "按回车键继续..."
                ;;
            4)
                run_module "gitlab.sh"
                read -p "按回车键继续..."
                ;;
            5)
                show_status
                ;;
            0)
                print_info "退出脚本"
                exit 0
                ;;
            *)
                print_error "无效选项"
                sleep 2
                ;;
        esac
    done
}

main