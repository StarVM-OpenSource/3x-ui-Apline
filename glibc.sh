#!/bin/sh

set -e

echo "正在准备 glibc 安装修复环境..."

# 1. 删除 /etc/nsswitch.conf（防止冲突）
rm -f /etc/nsswitch.conf

# 2. 下载 sgerrand 的公钥
curl -Lo /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub

# 3. 下载指定版本的 glibc 包
GLIBC_VER="2.34-r0"
curl -Lo glibc-${GLIBC_VER}.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-${GLIBC_VER}.apk

# 4. 安装 glibc，允许覆盖
apk add --allow-untrusted --force-overwrite glibc-${GLIBC_VER}.apk

echo "glibc ${GLIBC_VER} 安装完成 "