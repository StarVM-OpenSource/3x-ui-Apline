#!/bin/bash
rm -f /etc/nsswitch.conf

# 添加密钥
curl -Lo /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub

# 下载 glibc 安装包（注意：一定要用具体版本链接）
curl -Lo glibc.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.34-r0/glibc-2.34-r0.apk

# 安装
apk add glibc.apk
