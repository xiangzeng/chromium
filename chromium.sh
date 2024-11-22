#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Linux.sh"

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装..."
    
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
else
    echo "Docker 已安装，版本为: $(docker --version)"
fi

# 获取相对路径
relative_path=$(realpath --relative-to=/usr/share/zoneinfo /etc/localtime)
echo "相对路径为: $relative_path"

# 创建 chromium 目录并进入
mkdir -p $HOME/chromium
cd $HOME/chromium
echo "已进入 chromium 目录"

# 获取命令行参数
CUSTOM_USER=$1
PASSWORD=$2

# 如果命令行参数未提供，则请求用户输入
if [ -z "$CUSTOM_USER" ]; then
    read -p "请输入 CUSTOM_USER: " CUSTOM_USER
fi

if [ -z "$PASSWORD" ]; then
    read -sp "请输入 PASSWORD: " PASSWORD
    echo
fi
echo

# 读取Chrome启动参数（如果存在）
if [ -f "$HOME/chromium/config/extensions/chrome_args.txt" ]; then
    CHROME_ARGS=$(cat "$HOME/chromium/config/extensions/chrome_args.txt")
else
    CHROME_ARGS=""
fi
CHROME_ARG="$HOME/chromium/config/extensions/chrome_args.txt"
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
      - CHROME_CLI=https://x.com/qklxsqf #optional
      - CHROME_ARGS=$CHROME_ARGS
    volumes:
      - $HOME/chromium/config:/config
    ports:
      - 80:3000
      - 3011:3001
    shm_size: "1gb"
    restart: unless-stopped
EOF

echo "docker-compose.yaml 文件已创建，内容已导入。"

# 启动 Docker Compose
docker compose up -d
echo "Docker Compose 已启动。"

echo "部署完成，请打开浏览器操作。"
