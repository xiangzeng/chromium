#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Linux.sh"

# 显示 Logo
curl -s https://raw.githubusercontent.com/ziqing888/logo.sh/main/logo.sh | bash
sleep 3

# 显示函数
show() {
    echo -e "\033[1;34m$1\033[0m"
}

# 检查是否以 root 用户身份运行脚本
if [ "$EUID" -ne 0 ]; then
    show "请使用 sudo 或以 root 用户身份运行此脚本。"
    exit
fi

# 1. 安装 Docker
install_docker() {
    show "正在安装 Docker..."
    
    # 更新系统
    sudo apt update -y && sudo apt upgrade -y
    
    # 移除旧版本
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y $pkg
    done

    # 安装必要的包
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # 添加 Docker 的源
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 再次更新并安装 Docker
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 检查 Docker 版本
    docker --version
    show "Docker 安装完成。"
}

# 2. 检查时区
check_timezone() {
    show "正在检查时区..."
    relative_path=$(realpath --relative-to=/usr/share/zoneinfo /etc/localtime)
    show "当前系统时区的相对路径为: $relative_path"
}

# 3. 安装并配置 Chromium 容器
setup_chromium() {
    # 创建 chromium 目录并进入
    mkdir -p $HOME/chromium
    cd $HOME/chromium
    show "已进入 chromium 目录"

    # 获取用户输入
    read -p "请输入 CUSTOM_USER: " CUSTOM_USER
    read -sp "请输入 PASSWORD: " PASSWORD
    echo

    # 创建 docker-compose.yaml 文件
    cat <<EOF > docker-compose.yaml
---
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined #optional
    environment:
      - CUSTOM_USER=$CUSTOM_USER
      - PASSWORD=$PASSWORD
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - CHROME_CLI=https://x.com/ferdie_jhovie #optional
    volumes:
      - /root/chromium/config:/config
    ports:
      - 3010:3000   #Change 3010 to your favorite port if needed
      - 3011:3001   #Change 3011 to your favorite port if needed
    shm_size: "1gb"
    restart: unless-stopped
EOF

    show "docker-compose.yaml 文件已创建，内容已导入。"

    # 启动 Docker Compose
    docker compose up -d
    show "Docker Compose 已启动，Chromium 容器正在运行。"
}

# 4. 停止并删除 Chromium 容器
stop_and_remove_chromium() {
    show "正在停止并删除 Chromium 容器..."
    docker compose down
    show "Chromium 容器已停止并删除。"
}

# 主菜单
main_menu() {
    while true; do
        clear  # 清屏以只显示 logo 和菜单
        # 显示 Logo
        curl -s https://raw.githubusercontent.com/sdohuajia/Hyperlane/refs/heads/main/logo.sh | bash
        sleep 1  # 显示 Logo 之后稍作停留
        
        # 显示主菜单
        show "请选择操作："
        echo "1) 安装 Docker"
        echo "2) 检查时区"
        echo "3) 安装并配置 Chromium 容器"
        echo "4) 停止并删除 Chromium 容器"
        echo "5) 退出"
        read -p "请输入选择 (1-5): " choice
        
        case $choice in
            1) install_docker ;;
            2) check_timezone ;;
            3) setup_chromium ;;
            4) stop_and_remove_chromium ;;
            5) exit 0 ;;
            *) show "无效的选择，请重新输入。" ;;
        esac
    done
}

# 运行主菜单
main_menu
