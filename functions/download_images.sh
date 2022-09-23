#!/usr/bin/env bash
##############################################################
# File Name: download_images.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 17:41:15
# Description:
##############################################################

function Docker_Pull_Images() {
    cat >/tmp/kubeadmcfg.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
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
        Red_Echo "不支持的 Container Runtime 类型"
        exit 1
        ;;
    esac

    local images=$(kubeadm config images list --config /tmp/kubeadmcfg.yaml; cat $SH_DIR/extra_images.txt)
    for image in $images; do
        image_file="$(echo $image| awk -F':|/' '{print $(NF-1)}').tar"
        # 拉取k8s镜像
        $cli_command pull $image
        # 导出镜像
        $cli_command save -o $image_file $image
    done
}
