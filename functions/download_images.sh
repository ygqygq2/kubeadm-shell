#!/usr/bin/env bash
##############################################################
# File Name: download_images.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 17:41:15
# Description:
##############################################################

function docker_pull_images () {
    cat > /tmp/kubeadmcfg.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${KUBEVERSION}
imageRepository: ${IMAGE_REPOSITORY}
EOF

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
    
    # 拉取k8s镜像
    kubeadm config images list --config /tmp/kubeadmcfg.yaml | awk '{print "'$cli_command' pull " $0}' | sh
    # 导出镜像
    kubeadm config images list --config /tmp/kubeadmcfg.yaml | awk -F':|/' '{print "'$cli_command' save -o '$images_dir'/" $(NF-1) ".tar " $0}' | sh

    # 拉取额外的docker images
    cat $SH_DIR/extra_images.txt | awk '{print "'$cli_command' pull " $0}' | sh
    # 导出镜像
    cat $SH_DIR/extra_images.txt | awk -F':|/' '{print "'$cli_command' save -o '$images_dir'/" $(NF-1) ".tar " $0}' | sh
}
