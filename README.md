# centos79_docker_shell
CentOS7.9系统里Docker容器安装任意程序的通用脚本

# 使用方法

```shell
cd 你的工作目录
chmod +x ./scripts/chmod_all.sh
./scripts/chmod_all.sh
./scripts/install.sh
```

```shell
scripts/                    # 通用脚本文件夹（可复制到任意目录）
├── install.sh              # 主安装脚本
├── common.sh               # 公共函数库
└── modules/                # 模块目录
    ├── mysql57.sh          # MySQL 5.7 模块
    ├── mysql80.sh          # MySQL 8.0 模块
    ├── gitlab.sh           # GitLab 模块
    └── xxxxx.sh            # 其他
```



# 我的案例

```shell
/liudelantu/
├── docker-compose.yml          # 自动生成的统一配置文件
├── mysql57/                    # MySQL 5.7 数据目录
│   ├── data/
│   ├── conf/
│   └── logs/
├── mysql80/                    # MySQL 8.0 数据目录
│   ├── data/
│   ├── conf/
│   └── logs/
├── gitlab/                     # GitLab 数据目录
│   ├── config/
│   ├── logs/
│   └── data/
└── scripts/                    # 脚本目录
    ├── install.sh              # 主安装脚本
    ├── common.sh               # 公共函数库
    └── modules/                # 模块目录
        ├── mysql57.sh          # MySQL 5.7 安装模块
        ├── mysql80.sh          # MySQL 8.0 安装模块
        └── gitlab.sh           # GitLab 安装模块
```



感谢阅读~
