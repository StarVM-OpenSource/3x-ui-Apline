#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}严重错误: ${plain} 请以 root 权限运行此脚本 \n " && exit 1

install_base() {
	apk add --no-cache --update ca-certificates tzdata fail2ban bash
	rm -f /etc/fail2ban/jail.d/alpine-ssh.conf
	cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
	sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local
	sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local
	sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local server_ip=$(curl -s https://api.ipify.org)

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -p "您是否需要自定义面板端口? (如果不需要自定义, 系统将随机生成端口) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -p "请输入面板自定义端口: " config_port
                echo -e "${yellow}您的面板端口是: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}生成的随机端口: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "这是全新安装, 出于安全考虑, 会生成随机登录信息:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "${green}端口: ${config_port}${plain}"
            echo -e "${green}面板路径: ${config_webBasePath}${plain}"
            echo -e "${green}访问面板URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}如果你忘记了登录信息, 你可以使用命令“x-ui settings”${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}面板路径缺失或太短, 正在生成一个新的...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}新的面板路径: ${config_webBasePath}${plain}"
            echo -e "${green}访问面板URL: http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}检测到默认用户名和密码, 需要安全更新...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "生成新的随机登录用户名和密码:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}如果你忘记了登录信息, 你可以使用命令“x-ui settings”${plain}"
        else
            echo -e "${green}用户名, 密码和面板路径已正确设置. 退出...${plain}"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
	cd /usr/local
    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/StarVM-OpenSource/3x-ui-Apline/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}获取x-ui版本失败, 可能是GitHub API限制或网络连接失败, 请检查您的网络连接后重试...${plain}"
            exit 1
        fi
        echo -e "获取x-ui最新版本: ${tag_version}, 开始安装..."
        wget --no-check-certificate -O /usr/local/x-ui-linux-alpine.tar.gz https://github.com/StarVM-OpenSource/3x-ui-Apline/releases/download/${tag_version}/x-ui-linux-alpine.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui 失败, 请确保你的服务器可以访问 GitHub ${plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.4.8"
        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}请使用较新的版本(至少 v2.4.8), 退出安装...${plain}"
            exit 1
        fi

        url="https://github.com/StarVM-OpenSource/3x-ui-Apline/releases/download/${tag_version}/x-ui-linux-alpine.tar.gz"
        echo -e "开始安装x-ui $1"
        wget --no-check-certificate -O /usr/local/x-ui-linux-alpine.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载x-ui $1 失败, 请检查版本是否存在 ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
      echo -e "卸载旧版本..."
      rc-update del x-ui
      rc-service x-ui stop
      fail2ban-client -x stop
      rm /usr/local/x-ui/ -rf
      rm /etc/init.d/x-ui
	  if [[ -e /app/bin/ ]]; then
	    pgrep -f x-ui | xargs -r kill -9
            rm /app -rf
	  fi
    fi

    tar zxvf x-ui-linux-alpine.tar.gz
    rm x-ui-linux-alpine.tar.gz -f
    mv x-ui/app/* x-ui
    rm x-ui/app -rf
    rm x-ui/DockerEntrypoint.sh
    chmod +x x-ui/x-ui x-ui/bin/xray-linux-amd64
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/x-ui-alpine.sh
    chmod +x /usr/bin/x-ui
    wget --no-check-certificate -O /etc/init.d/x-ui https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/x-ui.rc
    chmod +x /etc/init.d/x-ui
    config_after_install
    export XRAY_VMESS_AEAD_FORCED="false"
    fail2ban-client -x start
    rc-update add x-ui default
    rc-service x-ui start
    echo -e "${green}x-ui ${tag_version}${plain} 安装完成, 运行中..."
    echo -e ""
    echo -e "x-ui子命令菜单:"
    echo -e "----------------------------------------------"
    echo -e "x-ui              - 主菜单"
    echo -e "x-ui start        - 运行服务"
    echo -e "x-ui stop         - 停止服务"
    echo -e "x-ui restart      - 重启服务"
    echo -e "x-ui status       - 查看服务状态"
    echo -e "x-ui settings     - 查看服务配置"
    echo -e "x-ui enable       - 打开服务开机自动启动"
    echo -e "x-ui disable      - 关闭服务开机自动启动"
    echo -e "x-ui log          - 查看日志"
    echo -e "x-ui banlog       - 查看Fail2ban日志"
    echo -e "x-ui update       - 升级"
    echo -e "x-ui legacy       - 安装旧版本"
    echo -e "x-ui install      - 安装"
    echo -e "x-ui uninstall    - 卸载"
    echo -e "----------------------------------------------"
}

echo -e "${green}运行中...${plain}"
install_base
install_x-ui $1
