#!/usr/bin/env bash
##############################################################
# @Author      : Chinge Yang
# @Date        : 2022-09-20 15:56:29
# @LastEditTime: 2022-09-23 13:12:40
# @LastEditors : Chinge Yang
# @Description : 下载离线安装包
# @FilePath    : /kubeadm-shell/functions/download_packages.sh
##############################################################

function Download_Packages() {
    if [ "$PM" == "yum" ]; then
        # 因为要使用docker 导出镜像，安装 docker ce
        yum -y install docker-ce-$DOCKERVERSION
        systemctl start docker

        # 拉取镜像时需要kubeadm
        yum -y install kubernetes-cni${KUBERNETES_CNI_VERSION:+-$KUBERNETES_CNI_VERSION} \
            kubelet-${KUBEVERSION/v/} \
            kubeadm-${KUBEVERSION/v/} \
            kubectl-${KUBEVERSION/v/}

        # 时间同步
        local packages="bash \
            chrony \
            createrepo \
            curl \
            device-mapper-persistent-data \
            ethtool \
            hdparm \
            ipvsadm \
            lvm2 \
            ntpdate \
            openssh-clients \
            rsync \
            vim \
            wget \
            yum-utils"
        yum install --downloadonly --downloaddir=$PACKAGES_DIR "$packages"

        # kubeadm kubectl kubelet
        yum install --downloadonly --downloaddir=$PACKAGES_DIR \
            kubernetes-cni${KUBERNETES_CNI_VERSION:+-$KUBERNETES_CNI_VERSION} \
            kubelet-${KUBEVERSION/v/} \
            kubeadm-${KUBEVERSION/v/} \
            kubectl-${KUBEVERSION/v/}
        curl http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg -o $GPG_DIR/Aliyun-kubernetes-yum-key.gpg
        curl http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg -o $GPG_DIR/Aliyun-kubernetes-rpm-package-key.gpg
    elif [ "$PM" == "apt" ]; then
        chown _apt:root $PACKAGES_DIR
        apt -y install dpkg-dev
        local packages="apt-transport-https \
        bash \
        chrony \
        ca-certificates \
        curl \
        ethtool \
        hdparm \
        ipvsadm \
        ntpdate \
        openssh-client \
        rsync \
        software-properties-common \
        vim \
        wget"
        cd $PACKAGES_DIR
        apt download $(apt-rdepends "$packages" | grep -v "^ " | sed 's/debconf-2.0/debconf/g')

        apt -y install kubeadm=${KUBEVERSION/v/}-00

        apt download $(apt-rdepends kubernetes-cni \
            kubelet \
            kubeadm \
            kubectl | grep -v "^ " | sed 's/debconf-2.0/debconf/g')

        apt download kubernetes-cni${KUBERNETES_CNI_VERSION:+=$KUBERNETES_CNI_VERSION"-00"} \
            kubelet=${KUBEVERSION/v/}-00 \
            kubeadm=${KUBEVERSION/v/}-00 \
            kubectl=${KUBEVERSION/v/}-00
    else
        Red_Echo "当前系统不支持离线安装"
        return 1
    fi

    case $INSTALL_CR in
    containerd)
        if [ "$PM" == "yum" ]; then
            yum install --downloadonly --downloaddir=$PACKAGES_DIR \
                containerd.io
            curl https://mirrors.aliyun.com/docker-ce/linux/centos/gpg -o $GPG_DIR/Docker.gpg
        elif [ "$PM" == "apt" ]; then
            apt download $(apt-rdepends containerd.io | grep -v "^ " | sed 's/debconf-2.0/debconf/g')
        fi

        # 下载 cni-plugins
        cd $PACKAGES_DIR
        cni_plugins_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/containernetworking/plugins/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/containernetworking/plugins/releases/download/${cni_plugins_version}/cni-plugins-linux-${ARCH}-${cni_plugins_version}.tgz -O \
            cni-plugins-linux-${ARCH}-latest.tgz || echo '下载 cni-plugins 失败! ' >>${install_log}

        # 下载 nerdctl
        cd $PACKAGES_DIR
        nerdctl_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/containerd/nerdctl/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/containerd/nerdctl/releases/download/${nerdctl_version}/nerdctl-${nerdctl_version/v/}-linux-amd64.tar.gz -O \
            nerdctl-latest-linux-${ARCH}.tar.gz || echo '下载 nerdctl 失败! ' >>${install_log}
        ;;
    docker)
        if [ "$PM" == "yum" ]; then
            yum install --downloadonly --downloaddir=$PACKAGES_DIR \
                docker-ce-$DOCKERVERSION \
                docker-ce-cli-$DOCKERVERSION \
                curl https://mirrors.aliyun.com/docker-ce/linux/centos/gpg -o $GPG_DIR/Docker.gpg
        elif [ "$PM" == "apt" ]; then
            apt download $(apt-rdepends docker-ce=${DOCKERVERSION}-00 docker-ce-cli=${DOCKERVERSION}-00 | grep -v "^ " | sed 's/debconf-2.0/debconf/g')
        fi

        # 下载 cri-dockerd
        cd $PACKAGES_DIR
        if [ ! -f cri-dockerd-latest.amd64.tgz ]; then
            cri_dockerd_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest" |
                grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
            wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${cri_dockerd_version}/cri-dockerd-${cri_dockerd_version/v/}.${ARCH}.tgz -O \
                cri-dockerd-latest.${ARCH}.tgz || echo '下载 cri-dockerd 失败! ' >>${install_log}
        fi
        [ ! -d systemd ] && mkdir systemd
        cd systemd
        wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service -O \
            cri-docker.service
        wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket -O \
            cri-docker.socket
        ;;
    ciro)
        # ref https://kubernetes.io/docs/setup/production-environment/container-runtimes/#tab-cri-cri-o-installation-2
        if [ "$PM" == "yum" ]; then
            yum install --downloadonly --downloaddir=$PACKAGES_DIR \
                cri-o
        elif [ "$PM" == "apt" ]; then
            apt download $(apt-rdepends cri-o cri-o-runc | grep -v "^ " | sed 's/debconf-2.0/debconf/g')
        fi

        # 下载 nerdctl
        cd $PACKAGES_DIR
        if [ ! -f crictl-latest-linux-amd64.tar.gz ]; then
            crictl_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest" |
                grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
            wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-${ARCH}.tar.gz -O \
                crictl-latest-linux-${ARCH}.tar.gz || echo '下载 crictl 失败! ' >>${install_log}
        fi
        ;;
    *)
        Red_Echo "不支持的 Container Runtime 类型"
        exit 1
        ;;
    esac

    # 生成 Ubuntu 软件包信息
    if [ "$PM" == "apt" ]; then
        cd $PACKAGES_DIR
        dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    fi
}
