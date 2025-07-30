#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}错误：请以 root 权限运行脚本${plain}" && exit 1

install_base() {
    echo -e "${green}安装基础依赖（curl、bash、tar等）...${plain}"
    apk add --no-cache --update ca-certificates tzdata bash curl tar gzip
    # 下面这部分是 Fail2ban 相关配置，删除或注释掉即可
    # apk add --no-cache fail2ban
    # rm -f /etc/fail2ban/jail.d/alpine-ssh.conf
    # cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    # sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local
    # sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban.jail.local || true
    # sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf
}

install_glibc() {
    echo -e "${yellow}开始强制安装glibc兼容层...${plain}"

    # 导入签名公钥（重复导入无影响）
    curl -fsSL -o /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub || {
        echo -e "${red}下载公钥失败，安装中止${plain}"
        exit 1
    }

    # 下载glibc安装包
    glibc_url="https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk"
    curl -fsSL -o /tmp/glibc.apk "$glibc_url" || {
        echo -e "${red}下载glibc包失败，安装中止${plain}"
        exit 1
    }

    # 强制覆盖安装glibc包
    apk add --allow-untrusted --force-overwrite /tmp/glibc.apk || {
        echo -e "${red}安装glibc失败，安装中止${plain}"
        rm -f /tmp/glibc.apk
        exit 1
    }

    rm -f /tmp/glibc.apk
    echo -e "${green}glibc 强制安装完成${plain}"

    # 设置环境变量
    export LD_LIBRARY_PATH=/lib:/usr/glibc-compat/lib:$LD_LIBRARY_PATH
}

gen_random_string() {
    local length="$1"
    LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1
}

config_after_install() {
    local existing_username existing_password existing_webBasePath existing_port server_ip
    existing_username=$(/usr/glibc-compat/lib/ld-linux-x86-64.so.2 --library-path /usr/glibc-com
pat/lib /usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'username: .+' | awk '{print $2}') || true
    existing_password=$(/usr/glibc-compat/lib/ld-linux-x86-64.so.2 --library-path /usr/glibc-com
pat/lib /usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'password: .+' | awk '{print $2}') || true
    existing_webBasePath=$(/usr/glibc-compat/lib/ld-linux-x86-64.so.2 --library-path /usr/glibc-com
pat/lib /usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'webBasePath: .+' | awk '{print $2}') || true
    existing_port=$(/usr/glibc-compat/lib/ld-linux-x86-64.so.2 --library-path /usr/glibc-com
pat/lib /usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'port: .+' | awk '{print $2}') || true
    server_ip=$(curl -s https://api.ipify.org || echo "服务器IP获取失败")

    if [[ -z "$existing_username" || "$existing_username" == "admin" ]]; then
        existing_username=$(gen_random_string 10)
        existing_password=$(gen_random_string 10)
        existing_webBasePath=$(gen_random_string 15)
        existing_port=$(shuf -i 1024-62000 -n 1)

        /usr/glibc-compat/lib/ld-linux-x86-64.so.2 --library-path /usr/glibc-com
pat/lib /usr/local/x-ui/x-ui setting -username "$existing_username" -password "$existing_password" -port "$existing_port" -webBasePath "$existing_webBasePath"
    fi

    echo -e "${green}x-ui 面板安装完成，安全登录信息如下：${plain}"
    echo -e "###############################################"
    echo -e "用户名: ${green}${existing_username}${plain}"
    echo -e "密码: ${green}${existing_password}${plain}"
    echo -e "端口: ${green}${existing_port}${plain}"
    echo -e "面板路径: ${green}${existing_webBasePath}${plain}"
    echo -e "访问面板URL: ${green}http://${server_ip}:${existing_port}/${existing_webBasePath}${plain}"
    echo -e "###############################################"
}

install_x_ui() {
    echo -e "${green}开始安装x-ui...${plain}"

    # 卸载旧版本
    if [[ -d /usr/local/x-ui ]]; then
        echo -e "${yellow}检测到旧版本，正在卸载...${plain}"
        rc-update del x-ui
        rc-service x-ui stop
        pgrep -f x-ui | xargs -r kill -9
        rm -rf /usr/local/x-ui
        rm -f /etc/init.d/x-ui
    fi

    cd /usr/local || exit 1

    tag_version=$(curl -Ls "https://api.github.com/repos/StarVM-OpenSource/3x-ui-Apline/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$tag_version" ]]; then
        echo -e "${red}获取x-ui最新版本失败${plain}"
        exit 1
    fi

    echo -e "最新版本：${tag_version}，开始下载安装包..."
    wget --no-check-certificate -O x-ui-linux-alpine.tar.gz "https://github.com/StarVM-OpenSource/3x-ui-Apline/releases/download/${tag_version}/x-ui-linux-amd64.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请检查网络${plain}"
        exit 1
    fi

    tar zxvf x-ui-linux-alpine.tar.gz
    rm -f x-ui-linux-alpine.tar.gz

    chmod +x /usr/local/x-ui/x-ui /usr/local/x-ui/bin/xray-linux-amd64

    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/x-ui-alpine.sh
    chmod +x /usr/bin/x-ui
    wget --no-check-certificate -O /etc/init.d/x-ui https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/x-ui.rc
    chmod +x /etc/init.d/x-ui

    rc-update add x-ui default
    rc-service x-ui start

    /usr/glibc-compat/lib/ld-linux-x86-64.so.2 --library-path /usr/glibc-com
pat/lib /usr/local/x-ui/x-ui migrate

    config_after_install
}

# 主流程
install_base
install_glibc
install_x_ui
