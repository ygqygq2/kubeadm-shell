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
cd `dirname $0`
SH_DIR=`pwd`
ME=$0
PARAMETERS=$*
packages_dir=$SH_DIR/packages
images_dir=$SH_DIR/images
gpg_dir=$packages_dir/gpg

# 定义日志
install_log=/root/install_log.txt

. $SH_DIR/config.sh
. $SH_DIR/functions/base.sh
. $SH_DIR/functions/load_images.sh
. $SH_DIR/functions/system.sh
. $SH_DIR/functions/setup_ssl.sh
. $SH_DIR/functions/setup_slb.sh
. $SH_DIR/functions/k8s_master.sh
. $SH_DIR/functions/k8s_node.sh


function do_all() {
    if [ "$HOSTNAME" = "${NAMES[0]}" ]; then
        # 免交互生成ssh key
        [ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''
        chmod 0600 ~/.ssh/id_rsa
        for h in ${HOSTS[@]}; do
            # 判断能否免密登录
            ssh ${ssh_parameters} -o PreferredAuthentications=publickey ${h} "pwd" > /dev/null
            if [ $? -ne 0 ]; then
                ssh-copy-id ${ssh_parameters} -p ${ssh_port} -i ~/.ssh/id_rsa -f root@${h}
                return_error_exit "${h} 添加ssh免密认证"
            fi
        done
    fi

    # 第一台master节点
    if [[ "$INSTALL_CLUSTER" != "false" && "$HOSTNAME" = "${NAMES[0]}" ]]; then
        check_running=$(ps aux|grep "/bin/bash $SH_DIR/$(basename $ME)"|grep -v grep)
        if [ -z "$check_running" ]; then  # 为空表示非远程执行脚本
            for ((i=$((${#HOSTS[@]}-1)); i>=0; i--)); do
                $ssh_command root@${HOSTS[$i]} "yum -y install rsync"
                $ssh_command root@${HOSTS[$i]} "mkdir -p $SH_DIR"
                # 将脚本分发至master节点
                rsync -avz -e "${ssh_command}" /etc/hosts root@${HOSTS[$i]}:/etc/hosts
                rsync -avz -e "${ssh_command}" $SH_DIR/ root@${HOSTS[$i]}:$SH_DIR/
                $ssh_command root@${HOSTS[$i]} "/bin/bash $SH_DIR/$(basename $ME)"
            done
        else
            # 准备yum源
            if [ "$INSTALL_OFFLINE" != "true" ]; then
                ready_yum
                setup_time_service
            else
                ready_local_yum
            fi
            # 系统检查
            check_system
            # 系统优化
            system_opt
            # 安装docker-ce等
            init_k8s
            # 导入离线images
            load_images
            # 生成证书
            if [ "$GENERATE_CA" != "false" ]; then
                # 安装证书工具
                install_cfssl
                # 生成ca证书
                generate_cert
            fi

            set_slb

            # 安装Kubernetes
            install_k8s
        fi
    else  # 其它节点
        # 准备yum源
        if [ "$INSTALL_OFFLINE" != "true" ]; then
            ready_yum
            setup_time_service
        else
            ready_local_yum
        fi
        # 系统检查
        check_system
        # 系统优化
        system_opt
        # 安装docker-ce等
        init_k8s
        # 导入离线images
        load_images
        # 安装k8s，master节点设置lvs
        if [ "$INSTALL_CLUSTER" != "false" ]; then
            set_slb
        else
            # 注册Kubernetes节点
            add_node
        fi
    fi
}


do_all
# 执行完毕的时间
green_echo "$HOSTNAME 本次安装花时:$SECONDS 秒"
echo '完成安装 '>>${install_log}

