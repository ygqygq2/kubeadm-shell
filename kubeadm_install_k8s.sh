#!/usr/bin/env bash
##############################################################
# File Name: kubeadm_install_k8s.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: http://ygqygq2.blog.51cto.com
# Created Time : 2018-10-22 22:57:11
# Description:
# 1. Kubeadm安装Kubernetes（3台master）
# 2. 需要在节点提前手动设置hostname
# 3. 脚本初始化时添加ssh key登录其它节点，可能需要用户按提示输入ssh密码
# 4. 安装集群在第一台master节点上执行此脚本；添加节点在节点上执行此脚本。
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
[ ! -d $PACKAGES_DIR ] && mkdir $PACKAGES_DIR

. $SH_DIR/config.sh
. $SH_DIR/functions/base.sh
. $SH_DIR/functions/init.sh
. $SH_DIR/functions/install.sh
. $SH_DIR/functions/load_images.sh
. $SH_DIR/functions/system.sh
. $SH_DIR/functions/setup_ssl.sh
. $SH_DIR/functions/setup_slb.sh
. $SH_DIR/functions/k8s_master.sh
. $SH_DIR/functions/k8s_node.sh

Get_Dist_Name
Kill_PM

function Do_All() {
    if [ "$HOSTNAME" = "${NAMES[0]}" ]; then
        # 免交互生成ssh key
        [ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''
        chmod 0600 ~/.ssh/id_rsa
        for h in ${HOSTS[@]}; do
            # 判断能否免密登录
            ssh ${ssh_parameters} -o PreferredAuthentications=publickey ${h} \
                "ssh ${ssh_parameters} -o PreferredAuthentications=publickey ${h} 'pwd'" >/dev/null
            if [ $? -ne 0 ]; then
                ssh-copy-id ${ssh_parameters} -p ${ssh_port} -i ~/.ssh/id_rsa -f root@${h}
                Return_Error_Exit "${h} 添加ssh免密认证"
            fi
        done
    fi

    [ ! -d $SH_DIR/ ] && exit 1
    [ ! -d $PACKAGES_DIR/ ] && exit 1
    # 第一台master节点
    if [[ "$INSTALL_CLUSTER" != "false" && "$HOSTNAME" = "${NAMES[0]}" ]]; then
        check_running=$(ps aux | grep "/bin/bash $SH_DIR/$(basename $ME)" | grep -v grep)
        if [ -z "$check_running" ]; then # 为空表示非远程执行脚本
            for ((i = $((${#HOSTS[@]} - 1)); i >= 0; i--)); do
                $ssh_command root@${HOSTS[$i]} "$PM install -y rsync"
                $ssh_command root@${HOSTS[$i]} "mkdir -p $SH_DIR"
                # 将脚本分发至master节点
                rsync -avz -e "${ssh_command}" /etc/hosts root@${HOSTS[$i]}:/etc/hosts
                rsync -avz -e "${ssh_command}" $SH_DIR/ root@${HOSTS[$i]}:$SH_DIR/
                $ssh_command root@${HOSTS[$i]} "/bin/bash $SH_DIR/$(basename $ME)"
	        # github 下载安装包慢，同步下安装包	
                rsync -avz -e "${ssh_command}" root@${HOSTS[$i]}:${PACKAGES_DIR}/ ${PACKAGES_DIR}/
            done
        else
            # 准备yum源
            if [ "$INSTALL_OFFLINE" != "true" ]; then
                Init_Install
            else
                Offline_Init_Install
            fi
            # 系统优化
            System_Opt
            # 安装docker-ce等
            Install
            Init_K8s
            # 导入离线images
            Load_Images
            # 生成证书
            if [ "$GENERATE_CA" != "false" ]; then
                # 安装证书工具
                Install_Cfssl
                # 生成ca证书
                Generate_Cert
            fi

            Set_Slb

            # 安装Kubernetes
            Install_K8s
        fi
    else # 其它节点
        # 准备yum源
        if [ "$INSTALL_OFFLINE" != "true" ]; then
            Init_Install
        else
            Offline_Init_Install
        fi
        # 系统优化
        System_Opt
        # 安装docker-ce等
        Install
        Init_K8s
        # 导入离线images
        Load_Images
        # 安装k8s，master节点设置lvs
        if [ "$INSTALL_CLUSTER" != "false" ]; then
            Set_Slb
        else
            # 注册Kubernetes节点
            Add_Node
        fi
    fi
}

Do_All
# 执行完毕的时间
Green_Echo "$HOSTNAME 本次安装花时:$SECONDS 秒"
echo '完成安装 ' >>${install_log}
