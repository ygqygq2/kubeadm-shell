#!/usr/bin/env bash
##############################################################
# File Name: k8s_offline_package.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: http://blog.csdn.net/ygqygq2
# Created Time : 2020-03-12 11:22:39
# Description: 在最小化安装的centos7下生成k8s离线安装包
##############################################################

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to run me."
    exit 1
fi
##############################################################

#获取脚本所存放目录
cd $(dirname $0)
SH_DIR=$(pwd)
ME=$0
PARAMETERS=$*
PACKAGES_DIR=$SH_DIR/packages
IMAGES_DIR=$SH_DIR/images
GPG_DIR=$PACKAGES_DIR/gpg

[ ! -d "$GPG_DIR" ] && mkdir -p "$GPG_DIR"

. $SH_DIR/config.sh
. $SH_DIR/functions/base.sh
. $SH_DIR/functions/init.sh
. $SH_DIR/functions/download_packages.sh
. $SH_DIR/functions/download_images.sh

Get_Dist_Name
Kill_PM
Init_Install
Download_Packages
Docker_Pull_Images

# 执行完毕的时间
Green_Echo "$HOSTNAME 本次执行花时:$SECONDS 秒"
