#!/usr/bin/env bash
##############################################################
# File Name: Load_Images.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 18:17:14
# Description:
##############################################################

function Load_Images() {
    if [ "$INSTALL_OFFLINE" != "true" ]; then
        return 0
    fi

    # 判断容器管理命令
    case $INSTALL_CR in
    docker)
        cli_command="docker"
        ;;
    containerd)
        cli_command="nerdctl --namespace=k8s.io"
        ;;
    *)
        Red_Echo "不支持的 Container Runtime 类型"
        exit 1
        ;;
    esac

    cd $IMAGES_DIR
    local tar_files=$(ls *.tar)
    for tar_file in ${tar_files[@]}; do
        $cli_command load -i "$tar_file"
    done
}
