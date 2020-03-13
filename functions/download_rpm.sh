#!/usr/bin/env bash
##############################################################
# File Name: download_rpm.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 16:26:53
# Description:
##############################################################

function download_rpm () {
    # 使用阿里云镜像源
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

    # 创建本地仓库包
    yum install --downloadonly --downloaddir=$packages_dir \
        createrepo

    # 实用工具
    yum install --downloadonly --downloaddir=$packages_dir \
        yum-utils \
        curl \
        wget \
        ipvsadm \
        hdparm

    # docker 依赖包
    yum install --downloadonly --downloaddir=$packages_dir \
        device-mapper-persistent-data \
        lvm2

    # 添加阿里云Docker源
    yum -y install yum-utils
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

    # docker ce
    yum install --downloadonly --downloaddir=$packages_dir \
        docker-ce-$DOCKERVERSION \
        docker-ce-cli-$DOCKERVERSION \
        containerd.io
    curl https://mirrors.aliyun.com/docker-ce/linux/centos/gpg -o $gpg_dir/Docker.gpg
    yum -y install docker-ce-$DOCKERVERSION
    systemctl start docker

    # 时间同步
    yum install --downloadonly --downloaddir=$packages_dir \
        chrony \
        ntpdate

    # 配置K8S的yum源
    cat > /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

    # kubeadm kubectl kubelet
    yum install --downloadonly --downloaddir=$packages_dir \
        kubernetes-cni${KUBERNETES_CNI_VERSION:+-$KUBERNETES_CNI_VERSION} \
        kubelet-${KUBEVERSION/v/} \
        kubeadm-${KUBEVERSION/v/} \
        kubectl-${KUBEVERSION/v/}
    curl http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg -o $gpg_dir/Aliyun-kubernetes-yum-key.gpg
    curl http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg -o $gpg_dir/Aliyun-kubernetes-rpm-package-key.gpg
    # 拉取镜像时需要kubeadm
    yum -y install kubernetes-cni${KUBERNETES_CNI_VERSION:+-$KUBERNETES_CNI_VERSION} \
        kubelet-${KUBEVERSION/v/} \
        kubeadm-${KUBEVERSION/v/} \
        kubectl-${KUBEVERSION/v/}
}
