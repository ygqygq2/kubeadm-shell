#!/usr/bin/env bash
##############################################################
# File Name: load_images.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 18:17:14
# Description:
##############################################################

function load_images () {
    # 判断容器管理命令
    case $INSTALL_CR in
        docker)
            cli_command="docker"
        ;;
        containerd)
            cli_command="nerdctl --namespace=k8s.io"
        ;;
        *)
            red_echo "不支持的 Container Runtime 类型"
            exit 1                                                                                                                                                                          
    esac

    cd $images_dir
    ls *.tar | awk '{print "'$cli_command' load -i " $0}' | sh
}
