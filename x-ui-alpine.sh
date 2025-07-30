#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

# check root
[[ $EUID -ne 0 ]] && LOGE "严重错误: ${plain} 请以 root 权限运行此脚本 \n" && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "系统OS检查失败, 请联系作者!" >&2
    exit 1
fi

echo "您的系统类型为: $release"

os_version=""
os_version=$(grep "^VERSION_ID" /etc/os-release | cut -d '=' -f2 | tr -d '"' | tr -d '.')

if [[ "${release}" == "alpine" ]]; then
    echo "您的系统类型为Alpine Linux"
else
    echo -e "${red}该脚本不支持您的操作系统${plain}\n"
    exit 1
fi

# Declare Variables
log_folder="${XUI_LOG_FOLDER:=/var/log}"
iplimit_log_path="${log_folder}/3xipl.log"
iplimit_banned_log_path="${log_folder}/3xipl-banned.log"

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default $2]: " temp
        if [[ "${temp}" == "" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ "${temp}" == "y" || "${temp}" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "重启面板, 注意: 重启面板也会重启xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车键返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/install_alpine.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "此功能将强制重新安装最新版本, 数据不会丢失是否继续?" "y"
    if [[ $? != 0 ]]; then
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/install_alpine.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新完成, 面板已自动重启"
        before_show_menu
    fi
}

update_menu() {
    echo -e "${yellow}更新主菜单${plain}"
    confirm "此功能将更新菜单以适应最新更改." "y"
    if [[ $? != 0 ]]; then
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi

    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/x-ui-alpine.sh
    chmod +x /usr/bin/x-ui

    if [[ $? == 0 ]]; then
        echo -e "${green}主菜单更新成功.${plain}"
        before_show_menu
    else
        echo -e "${red}主菜单更新失败.${plain}"
        return 1
    fi
}

legacy_version() {
    echo "输入版本信息 (例如 2.4.8):"
    read tag_version

    if [ -z "$tag_version" ]; then
        echo "版本信息不能为空, 退出."
        exit 1
    fi
    # Use the entered panel version in the download link
    install_command="bash <(curl -Ls "https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/v$tag_version/install_alpine.sh") v$tag_version"

    echo "下载安装x-ui版本: $tag_version..."
    eval $install_command
}

# Function to handle the deletion of the script file
delete_script() {
    rm "$0" # Remove the script file itself
    exit 1
}

uninstall() {
    confirm "您确定要卸载面板吗?xray也会被卸载!" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
      rc-update del x-ui
      rc-service x-ui stop
      rm /usr/local/x-ui/ -rf
      rm /etc/init.d/x-ui
      rm /etc/x-ui/ -rf
	  if [[ -e /app/bin/ ]]; then
	    pgrep -f x-ui | xargs -r kill -9
        rm /app -rf
	  fi
    echo ""
    echo -e "卸载成功.\n"
    echo "如果需要再次安装此面板, 可以使用以下命令:"
    echo -e "${green}bash <(curl -Ls https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/install_alpine.sh)${plain}"
    echo ""
    # Trap the SIGTERM signal
    trap delete_script SIGTERM
    delete_script
}

reset_user() {
    confirm "您确定要重置面板用户名和密码吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    read -rp "请设置登录用户名 [默认用户名系统随机生成]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "请设置登录密码 [默认密码系统随机生成]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    /usr/local/x-ui/x-ui setting -remove_secret >/dev/null 2>&1
    echo -e "面板登录用户名已重置为: ${green} ${config_account} ${plain}"
    echo -e "面板登录密码已重置为: ${green} ${config_password} ${plain}"
    echo -e "${yellow} 面板登录秘密令牌已禁用 ${plain}"
    echo -e "${green} 请使用新的登录用户名和密码访问 X-UI 面板请记住它们! ${plain}"
    confirm_restart
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

reset_webbasepath() {
    echo -e "${yellow}重置面板路径${plain}"

    read -rp "您确定要重置面板路径吗? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${yellow}操作已取消.${plain}"
        return
    fi

    config_webBasePath=$(gen_random_string 10)

    # Apply the new web base path setting
    /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}" >/dev/null 2>&1
    
    echo -e "面板路径已重置为: ${green}${config_webBasePath}${plain}"
    echo -e "${green}请访问新面板径.${plain}"
    restart
}

reset_config() {
    confirm "您确定要重置所有面板设置吗?账户数据不会丢失, 用户名和密码不会改变" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "所有面板设置已重置为默认值."
    restart
}

check_config() {
    local info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "获取当前设置错误, 请检查日志"
        show_menu
        return
    fi
    LOGI "${info}"

    local existing_webBasePath=$(echo "$info" | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(echo "$info" | grep -Eo 'port: .+' | awk '{print $2}')
    local existing_cert=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'cert: .+' | awk '{print $2}')
    local server_ip=$(curl -s https://api.ipify.org)

    if [[ -n "$existing_cert" ]]; then
        local domain=$(basename "$(dirname "$existing_cert")")

        if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "${green}访问面板URL: https://${domain}:${existing_port}${existing_webBasePath}${plain}"
        else
            echo -e "${green}访问面板URL: https://${server_ip}:${existing_port}${existing_webBasePath}${plain}"
        fi
    else
        echo -e "${green}访问面板URL: http://${server_ip}:${existing_port}${existing_webBasePath}${plain}"
    fi
}

set_port() {
    echo && echo -n -e "输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "已取消"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "端口已设置, 请立即重启面板, 并使用新的端口 ${green}${port}${plain} 访问面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "面板正在运行, 无需再次启动, 如需重启请选择重启"
    else
        rc-service x-ui start
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui启动成功"
        else
            LOGE "面板启动失败, 可能是因为启动时间超过两秒, 请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "面板已停止, 无需再次停止!"
    else
        rc-service x-ui stop
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui和xray已成功停止"
        else
            LOGE "面板停止失败, 可能是因为停止时间超过两秒, 请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    rc-service x-ui stop
	sleep 2
	rc-service x-ui start
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui和xray重启成功"
    else
        LOGE "面板重启失败, 可能是因为启动时间超过两秒, 请稍后查看日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    rc-service x-ui status
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    rc-update add x-ui default
    if [[ $? == 0 ]]; then
        LOGI "x-ui成功设置为开机自动启动"
    else
        LOGE "x-ui无法设置自动启动"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    rc-update del x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui自动启动已成功取消"
    else
        LOGE "x-ui无法取消自动启动"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu

}

show_banlog() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

bbr_menu() {
    echo -e "${green}\t1.${plain} 开启BBR"
    echo -e "${green}\t2.${plain} 关闭BBR"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请输入选项: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        enable_bbr
        bbr_menu
        ;;
    2)
        disable_bbr
        bbr_menu
        ;;
    *) 
        echo -e "${red}选项无效请选择有效数字${plain}\n"
        bbr_menu
        ;;
    esac
}

disable_bbr() {
	current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [ "$current_cc" = "cubic" ] || [ "$current_cc" != "bbr" ]; then
      echo "BBR 当前未启用, 无需禁用"
    else
      echo "禁用 BBR 拥塞控制算法..."
      # 设置 TCP 拥塞控制算法为 cubic 或其他默认算法
      sysctl -w net.ipv4.tcp_congestion_control=cubic
      # 卸载 tcp_bbr 模块
      modprobe -r tcp_bbr
      # 从 sysctl 配置文件中删除 BBR 设置
      sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
	  sed -i '/net.ipv4.tcp_congestion_control= bbr/d' /etc/sysctl.conf
	  sed -i '/net.ipv4.tcp_congestion_control =bbr/d' /etc/sysctl.conf
	  sed -i '/net.ipv4.tcp_congestion_control = bbr/d' /etc/sysctl.conf
      # 重新加载 sysctl 配置
      sysctl -p
      echo "BBR 已禁用！"
    fi
}

enable_bbr() {
	current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [ "$current_cc" = "bbr" ]; then
      echo "BBR 已经启用, 无需再次启用"
    else
      echo "启用 BBR 拥塞控制算法..."
      # 设置 TCP 拥塞控制算法为 BBR
      sysctl -w net.ipv4.tcp_congestion_control=bbr
      # 加载 tcp_bbr 模块
      if ! lsmod | grep -q tcp_bbr; then
          modprobe tcp_bbr
      fi
      # 确保设置在重启后生效
      echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
      # 重新加载 sysctl 配置
      sysctl -p
      echo "BBR 已启用！"
	fi
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://raw.githubusercontent.com/StarVM-OpenSource/3x-ui-Apline/refs/heads/main/x-ui-alpine.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "下载脚本失败, 请检查机器是否可以连接Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "升级脚本成功, 请重新运行脚本" 
        before_show_menu
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/init.d/x-ui ]]; then
        return 2
    fi
    temp=$(rc-service x-ui status | grep started | awk '{print $3}' | cut -d ":" -f2)
    if [[ "${temp}" == "started" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    if rc-update show | grep -q "x-ui"; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "面板已安装, 请勿重复安装"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "请先安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "面板状态: ${green}运行中...${plain}"
        show_enable_status
        ;;
    1)
        echo -e "面板状态: ${yellow}未启动${plain}"
        show_enable_status
        ;;
    2)
        echo -e "面板状态: ${red}未安装${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自动启动: ${green}是${plain}"
    else
        echo -e "是否开机自动启动: ${red}否${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray状态: ${green}运行中...${plain}"
    else
        echo -e "xray状态: ${red}未启动${plain}"
    fi
}

firewall_menu() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu

}

open_ports() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu

}

delete_ports() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu

}

update_geo() {
    echo -e "${green}\t1.${plain} Loyalsoldier (geoip.dat, geosite.dat)"
    echo -e "${green}\t2.${plain} chocolate4u (geoip_IR.dat, geosite_IR.dat)"
    echo -e "${green}\t3.${plain} vuong2023 (geoip_VN.dat, geosite_VN.dat)"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请输入选项: " choice

    cd /usr/local/x-ui/bin

    case "$choice" in
    0)
        show_menu
        ;;
    1)
        rc-service x-ui stop
        rm -f geoip.dat geosite.dat
        wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
        wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
        echo -e "${green}Loyalsoldier 数据升级成功!${plain}"
        rc-service x-ui start
        ;;
    2)
        rc-service x-ui stop
        rm -f geoip_IR.dat geosite_IR.dat
        wget -O geoip_IR.dat -N https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat
        wget -O geosite_IR.dat -N https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat
        echo -e "${green}chocolate4u 数据升级成功!${plain}"
        rc-service x-ui start
        ;;
    3)
        rc-service x-ui stop
        rm -f geoip_VN.dat geosite_VN.dat
        wget -O geoip_VN.dat -N https://github.com/vuong2023/vn-v2ray-rules/releases/latest/download/geoip.dat
        wget -O geosite_VN.dat -N https://github.com/vuong2023/vn-v2ray-rules/releases/latest/download/geosite.dat
        echo -e "${green}vuong2023 数据升级成功!${plain}"
        rc-service x-ui start
        ;;
    *)
        echo -e "${red}选项无效请选择一个有效的数字${plain}\n"
        update_geo
        ;;
    esac

    before_show_menu
}

install_acme() {
    # Check if acme.sh is already installed
    if command -v ~/.acme.sh/acme.sh &>/dev/null; then
        LOGI "acme.sh已经安装"
        return 0
    fi

    LOGI "安装中 acme.sh..."
    cd ~ || return 1 # Ensure you can change to the home directory

    curl -s https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "安装acme.sh失败."
        return 1
    else
        LOGI "安装acme.sh成功"
    fi

    return 0
}

ssl_cert_issue_main() {
    echo -e "${green}\t1.${plain} 安装证书"
    echo -e "${green}\t2.${plain} 撤销证书"
    echo -e "${green}\t3.${plain} 强制更新"
    echo -e "${green}\t4.${plain} 显示配置的域名"
    echo -e "${green}\t5.${plain} 设置面板的证书路径"
    echo -e "${green}\t0.${plain} 返回主菜单"

    read -p "请输入选项: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        ssl_cert_issue
        ssl_cert_issue_main
        ;;
    2)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未发现需要撤销的证书"
        else
            echo "域名列表:"
            echo "$domains"
            read -p "请从输入列表中的域名撤销证书: " domain
            if echo "$domains" | grep -qw "$domain"; then
                ~/.acme.sh/acme.sh --revoke -d ${domain}
                LOGI "域名证书已被吊销: $domain"
            else
                echo "输入的域名无效!"
            fi
        fi
        ssl_cert_issue_main
        ;;
    3)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到需要续订的证书"
        else
            echo "域名列表:"
            echo "$domains"
            read -p "请从输入列表中的域名更新SSL证书: " domain
            if echo "$domains" | grep -qw "$domain"; then
                ~/.acme.sh/acme.sh --renew -d ${domain} --force
                LOGI "为域名强制续订证书: $domain"
            else
                echo "输入的域名无效!"
            fi
        fi
        ssl_cert_issue_main
        ;;
    4)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到证书"
        else
            echo "现有域名及其路径: "
            for domain in $domains; do
                local cert_path="/root/cert/${domain}/fullchain.pem"
                local key_path="/root/cert/${domain}/privkey.pem"
                if [[ -f "${cert_path}" && -f "${key_path}" ]]; then
                    echo -e "域名: ${domain}"
                    echo -e "\t证书路径: ${cert_path}"
                    echo -e "\t私钥路径: ${key_path}"
                else
                    echo -e "域名: ${domain} - 证书或密钥丢失"
                fi
            done
        fi
        ssl_cert_issue_main
        ;;
    5)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到证书"
        else
            echo "可用域名列表:"
            echo "$domains"
            read -p "请选择一个域名来设置面板路径: " domain

            if echo "$domains" | grep -qw "$domain"; then
                local webCertFile="/root/cert/${domain}/fullchain.pem"
                local webKeyFile="/root/cert/${domain}/privkey.pem"

                if [[ -f "${webCertFile}" && -f "${webKeyFile}" ]]; then
                    /usr/local/x-ui/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
                    echo "设置域名路径: $domain"
                    echo "  - 证书文件: $webCertFile"
                    echo "  - 私钥文件: $webKeyFile"
                    restart
                else
                    echo "未找到域名的证书或私钥: $domain."
                fi
            else
                echo "输入的域名无效"
            fi
        fi
        ssl_cert_issue_main
        ;;

    *)
        echo -e "${red}选项无效, 请选择一个有效的数字${plain}\n"
        ssl_cert_issue_main
        ;;
    esac
}

ssl_cert_issue() {
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    # check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "acme.sh无法找到, 我们将安装它"
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "安装 acme 失败, 请检查日志"
            exit 1
        fi
    fi
	if [[ "${release}" == "alpine" ]]; then
		apk update && apk add socat
	else
		echo -e "${red}该脚本不支持您的操作系统${plain}\n"
		exit 1
	fi
    if [ $? -ne 0 ]; then
        LOGE "安装socat失败"
        exit 1
    else
        LOGI "安装socat成功"
    fi

    # get the domain here, and we need to verify it
    local domain=""
    read -p "请输入您的域名: " domain
    LOGD "您的域名是: ${domain}"

    # check if there already exists a certificate
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ "${currentCert}" == "${domain}" ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "系统已有此域名的证书。无法再次颁发。当前证书详细信息:"
        LOGI "$certInfo"
        exit 1
    else
        LOGI "您的域名现在已准备好颁发证书..."
    fi

    # create a directory for the certificate
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # get the port number for the standalone server
    local WebPort=80
    read -p "请选择要使用的端口(默认为 80): " WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGE "您输入的${WebPort}端口无效, 将使用默认端口80"
        WebPort=80
    fi
    LOGI "将使用端口: ${WebPort} 颁发证书, 请确保此端口已开放"

    # issue the certificate
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "颁发证书失败, 请检查日志"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGE "颁发证书成功, 正在安装证书……"
    fi

    # install the certificate
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem

    if [ $? -ne 0 ]; then
        LOGE "安装证书失败, 退出"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "证书安装成功, 正在启用自动更新..."
    fi

    # enable auto-renew
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "自动续订失败, 证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
        exit 1
    else
        LOGI "自动续订成功, 证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
    fi

    # Prompt user to set panel paths after successful certificate installation
    read -p "您要为面板设置此证书吗? (y/n): " setPanel
    if [[ "$setPanel" == "y" || "$setPanel" == "Y" ]]; then
        local webCertFile="/root/cert/${domain}/fullchain.pem"
        local webKeyFile="/root/cert/${domain}/privkey.pem"

        if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
            /usr/local/x-ui/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
            LOGI "配置面板域名: $domain"
            LOGI "  - 证书文件: $webCertFile"
            LOGI "  - 私钥文件: $webKeyFile"
            echo -e "${green}访问面板URL: https://${domain}:${existing_port}${existing_webBasePath}${plain}"
            restart
        else
            LOGE "错误: 未找到域的证书或私钥文件: $domain."
        fi
    else
        LOGI "跳过面板路径设置"
    fi
}

ssl_cert_issue_CF() {
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    LOGI "****** 使用说明 ******"
    LOGI "请按照以下步骤完成此过程:"
    LOGI "1. Cloudflare注册的邮箱地址."
    LOGI "2. Cloudflare Global API Key."
    LOGI "3. 域名."
    LOGI "4. 证书颁发后, 系统将提示您为面板设置证书(可选)."
    LOGI "5. 该脚本还支持安装后自动更新 SSL 证书."

    confirm "您是否确认该信息并希望继续? [y/n]" "y"

    if [ $? -eq 0 ]; then
        # Check for acme.sh first
        if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
            echo "acme.sh无法找到, 我们将安装它"
            install_acme
            if [ $? -ne 0 ]; then
                LOGE "安装acme失败, 请检查日志"
                exit 1
            fi
        fi

        CF_Domain=""
        certPath="/root/cert-CF"
        if [ ! -d "$certPath" ]; then
            mkdir -p $certPath
        else
            rm -rf $certPath
            mkdir -p $certPath
        fi

        LOGD "请设置域名:"
        read -p "在此输入您的域名: " CF_Domain
        LOGD "您的域名设置为: ${CF_Domain}"

        # Set up Cloudflare API details
        CF_GlobalKey=""
        CF_AccountEmail=""
        LOGD "请设置API key:"
        read -p "输入您的Global API Key: " CF_GlobalKey
        LOGD "你的Global API Key是: ${CF_GlobalKey}"

        LOGD "请设置注册的邮箱地址:"
        read -p "输入您的邮箱地址: " CF_AccountEmail
        LOGD "你的邮箱地址是: ${CF_AccountEmail}"

        # Set the default CA to Let's Encrypt
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "默认CA, Let's Encrypt失败, 脚本退出..."
            exit 1
        fi

        export CF_Key="${CF_GlobalKey}"
        export CF_Email="${CF_AccountEmail}"

        # Issue the certificate using Cloudflare DNS
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书颁发失败, 脚本退出..."
            exit 1
        else
            LOGI "证书颁发成功, 正在安装..."
        fi

        # Install the certificate
        mkdir -p ${certPath}/${CF_Domain}
        if [ $? -ne 0 ]; then
            LOGE "无法创建目录: ${certPath}/${CF_Domain}"
            exit 1
        fi

        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} \
            --fullchain-file ${certPath}/${CF_Domain}/fullchain.pem \
            --key-file ${certPath}/${CF_Domain}/privkey.pem

        if [ $? -ne 0 ]; then
            LOGE "证书安装失败, 脚本退出..."
            exit 1
        else
            LOGI "证书安装成功, 正在打开自动更新..."
        fi

        # Enable auto-update
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "自动更新设置失败, 脚本退出..."
            exit 1
        else
            LOGI "证书安装完毕, 并开启自动续订, 具体信息如下:"
            ls -lah ${certPath}/${CF_Domain}
            chmod 755 ${certPath}/${CF_Domain}
        fi

        # Prompt user to set panel paths after successful certificate installation
        read -p "是否要为面板设置此证书? (y/n): " setPanel
        if [[ "$setPanel" == "y" || "$setPanel" == "Y" ]]; then
            local webCertFile="${certPath}/${CF_Domain}/fullchain.pem"
            local webKeyFile="${certPath}/${CF_Domain}/privkey.pem"

            if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
                /usr/local/x-ui/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
                LOGI "配置面板域名: $CF_Domain"
                LOGI "  - 证书文件: $webCertFile"
                LOGI "  - 私钥文件: $webKeyFile"
                echo -e "${green}访问面板URL: https://${CF_Domain}:${existing_port}${existing_webBasePath}${plain}"
                restart
            else
                LOGE "错误: 未找到域的证书或私钥文件: $CF_Domain."
            fi
        else
            LOGI "跳过面板路径设置"
        fi
    else
        show_menu
    fi
}

run_speedtest() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

create_iplimit_jails() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

iplimit_remove_conflicts() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

iplimit_main() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

install_iplimit() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

remove_iplimit() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

SSH_port_forwarding() {
        echo -e "${red}此功能未完成, 请关注后续更新...${plain}\n"
        before_show_menu
}

show_usage() {
    echo "x-ui命令行功能: "
    echo "------------------------------------------"
    echo -e "SUBCOMMANDS:"
    echo -e "x-ui              - 主菜单"
    echo -e "x-ui start        - 启动服务"
    echo -e "x-ui stop         - 停止服务"
    echo -e "x-ui restart      - 重启服务"
    echo -e "x-ui status       - 查看服务状态"
    echo -e "x-ui settings     - 查看服务配置"
    echo -e "x-ui enable       - 设置开机启动"
    echo -e "x-ui disable      - 关闭开机启动"
    echo -e "x-ui log          - 查看日志"
    echo -e "x-ui banlog       - 查看Fail2ban日志"
    echo -e "x-ui update       - 升级"
    echo -e "x-ui custom       - 安装指定版本"
    echo -e "x-ui install      - 安装"
    echo -e "x-ui uninstall    - 卸载"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}3X-UI面板管理脚本${plain}
  ${green}0.${plain} 退出菜单
————————————————
  ${green}1.${plain} 安装
  ${green}2.${plain} 更新
  ${green}3.${plain} 更新主菜单
  ${green}4.${plain} 安装指定版本
  ${green}5.${plain} 卸载
————————————————
  ${green}6.${plain} 重置用户名密码
  ${green}7.${plain} 重置面板路径
  ${green}8.${plain} 重置配置数据(用户名密码和面板路径不变)
  ${green}9.${plain} 重置面板端口
  ${green}10.${plain} 查看面板配置
————————————————
  ${green}11.${plain} 启动服务
  ${green}12.${plain} 停止服务
  ${green}13.${plain} 重启服务
  ${green}14.${plain} 查看服务状态
  ${green}15.${plain} 查看日志
————————————————
  ${green}16.${plain} 设置开机启动
  ${green}17.${plain} 关闭开机启动
————————————————
  ${green}18.${plain} ACME证书管理
  ${green}19.${plain} Cloudflare证书管理
  ${green}20.${plain} IP限制管理
  ${green}21.${plain} 防火墙管理
  ${green}22.${plain} SSH端口转发管理
————————————————
  ${green}23.${plain} BBR功能
  ${green}24.${plain} 更新Geo文件
  ${green}25.${plain} 速度测试(Ookla)
"
    show_status
    echo && read -p "请输入选项[0-25]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && update_menu
        ;;
    4)
        check_install && legacy_version
        ;;
    5)
        check_install && uninstall
        ;;
    6)
        check_install && reset_user
        ;;
    7)
        check_install && reset_webbasepath
        ;;
    8)
        check_install && reset_config
        ;;
    9)
        check_install && set_port
        ;;
    10)
        check_install && check_config
        ;;
    11)
        check_install && start
        ;;
    12)
        check_install && stop
        ;;
    13)
        check_install && restart
        ;;
    14)
        check_install && status
        ;;
    15)
        check_install && show_log
        ;;
    16)
        check_install && enable
        ;;
    17)
        check_install && disable
        ;;
    18)
        ssl_cert_issue_main
        ;;
    19)
        ssl_cert_issue_CF
        ;;
    20)
        iplimit_main
        ;;
    21)
        firewall_menu
        ;;
    22)
        SSH_port_forwarding
        ;;
    23)
        bbr_menu
        ;;
    24)
        update_geo
        ;;
    25)
        run_speedtest
        ;;
    *)
        LOGE "请输入正确的数字 [0-25]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "settings")
        check_install 0 && check_config 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "banlog")
        check_install 0 && show_banlog 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "legacy")
        check_install 0 && legacy_version 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
