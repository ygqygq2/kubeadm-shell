#!/usr/bin/env bash
##############################################################
# @Author      : Chinge Yang
# @Date        : 2022-09-21 16:56:07
# @LastEditTime: 2022-09-21 16:56:14
# @LastEditors : Chinge Yang
# @Description : 一些基础软件安装
# @FilePath    : /kubeadm-shell/functions/install.sh
##############################################################

function Install_Docker() {
    # 安装 docker-ce 并启动
    Blue_Echo "[+] Installing docker-ce... "
    if [ "${PM}" = "apt" ]; then
        $PM -y install docker-ce=${DOCKERVERSION}-00 docker-ce-cli=${DOCKERVERSION}-00
    elif [ "${PM}" = "yum" ]; then
        $PM -y install docker-ce-$DOCKERVERSION docker-ce-cli-$DOCKERVERSION
    else
        Red_Echo "[-] 未知的包管理器, 请检查!"
        exit 1
    fi
    [ -f /etc/docker/daemon.json ] && \mv /etc/docker/daemon.json-$(date +%F-%H-%M)
    [ ! -d /etc/docker ] && mkdir /etc/docker
    cat >/etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ["https://ciluuy3h.mirror.aliyuncs.com"],
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    systemctl enable docker && systemctl restart docker
    docker version | tee /tmp/docker-version.log
    cat /tmp/docker-version.log | grep -w $DOCKERVERSION
    if [ $? -ne 0 ]; then
        Yellow_Echo "docker版本未对应(可手动处理后选择[确认]继续)"
        User_Verify
    fi
    echo '安装docker ce done! ' >>${install_log}

    # kubernetes 1.24 移除对 docker ce 的支持，增加一层 cri-docker
    # 安装 cri-docker 并启动

    cd $PACKAGES_DIR
    if [ ! -f cri-dockerd-latest.${ARCH}.tgz ]; then
        cri_dockerd_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/Mirantis/cri-dockerd/releases/download/${cri_dockerd_version}/cri-dockerd-${cri_dockerd_version/v/}.${ARCH}.tgz -O \
            cri-dockerd-latest.${ARCH}.tgz || echo '下载 cri-dockerd 失败! ' >>${install_log}
    fi
    tar -zxvf $PACKAGES_DIR/cri-dockerd-latest.${ARCH}.tgz -C /tmp/
    \mv /tmp/cri-dockerd/cri-dockerd /usr/local/bin/

    [ ! -d systemd ] && mkdir systemd
    cd systemd
    [ ! -f cri-docker.service ] && wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service -O \
        cri-docker.service echo '下载 cri-docker.service 失败! ' >>${install_log}
    [ ! -f cri-docker.socket ] && wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket -O \
        cri-docker.socket || echo '下载 cri-docker.socket 失败! ' >>${install_log}
    cp * /etc/systemd/system
    sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
    systemctl daemon-reload
    systemctl enable cri-docker.service
    systemctl enable --now cri-docker.socket
    systemctl start cri-docker
    echo '安装cri-dockerd done! ' >>${install_log}
}

function Install_Crictl() {
    # 安装 crictl
    Blue_Echo "[+] Installing crictl... "
    cd $PACKAGES_DIR
    if [ ! -f crictl-latest-linux-${ARCH}.tar.gz ]; then
        crictl_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-${ARCH}.tar.gz -O \
            crictl-latest-linux-${ARCH}.tar.gz || echo '下载 crictl 失败! ' >>${install_log}
    fi
    tar -zxvf $PACKAGES_DIR/crictl-latest-linux-${ARCH}.tar.gz -C /usr/local/bin/
}

function Install_Containerd() {
    # 安装 containerd
    Blue_Echo "[+] Installing containerd... "
    $PM -y install containerd.io
    # 安装 nerdctl
    cd $PACKAGES_DIR
    if [ ! -f nerdctl-latest-linux-${ARCH}.tar.gz ]; then
        nerdctl_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/containerd/nerdctl/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/containerd/nerdctl/releases/download/${nerdctl_version}/nerdctl-${nerdctl_version/v/}-linux-${ARCH}.tar.gz -O \
            nerdctl-latest-linux-${ARCH}.tar.gz || echo '下载 nerdctl 失败! ' >>${install_log}
    fi
    tar -zxvf $PACKAGES_DIR/nerdctl-latest-linux-${ARCH}.tar.gz -C /usr/local/bin/
    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i "s#k8s.gcr.io#${IMAGE_REPOSITORY}#g" /etc/containerd/config.toml
    sed -i '/registry.mirrors/a\ \ \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]\n\ \ \ \ \ \ \ \ \ \ endpoint = ["https://ciluuy3h.mirror.aliyuncs.com", "https://registry-1.docker.io"]' /etc/containerd/config.toml
    sed -i 's#sandbox_image.*#sandbox_image = "ygqygq2/pause:3.8"#' /etc/containerd/config.toml
    #sed -i '/containerd.runtimes.runc.options/a\ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup = true' /etc/containerd/config.toml
    #sed -i "s#https://registry-1.docker.io#https://registry.cn-hangzhou.aliyuncs.com#g" /etc/containerd/config.toml

    cd $PACKAGES_DIR
    if [ ! -f cni-plugins-linux-${ARCH}-latest.tgz ]; then
        cni_plugins_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/containernetworking/plugins/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/containernetworking/plugins/releases/download/${cni_plugins_version}/cni-plugins-linux-${ARCH}-${cni_plugins_version}.tgz -O \
            cni-plugins-linux-${ARCH}-latest.tgz || echo '下载 cni-plugins 失败! ' >>${install_log}
    fi
    tar Cxzvf /opt/cni/bin cni-plugins-linux-${ARCH}-latest.tgz

    systemctl restart containerd
    systemctl enable containerd

    Install_Crictl
    cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF
    echo '安装containerd done! ' >>${install_log}
}

function Install_Crio() {
    # 安装 crio, ref https://kubernetes.io/docs/setup/production-environment/container-runtimes/
    Blue_Echo "[+] Installing crio... "
    cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    if [ "${DISTRO}" = "Ubuntu" ]; then
        $PM -y install cri-o cri-o-runc
        cat >/etc/crio/crio.conf.d/cri-o-runc <<EOF
[crio.runtime.runtimes.runc]
runtime_path = ""
runtime_type = "oci"
runtime_root = "/run/runc"
EOF
    else
        $PM install -y cri-o
        if ! runc -v | grep libseccomp; then
            \mv /usr/bin/runc /usr/bin/runc.bak
        fi
        # runc可能版本过旧，ref: https://github.com/opencontainers/runc/releases/latest
        runc_version=$(wget -qO- -t5 -T10 "https://api.github.com/repos/opencontainers/runc/releases/latest" |
            grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        wget https://github.com/opencontainers/runc/releases/download/$runc_version/runc.amd64 -O /usr/bin/runc
        chmod a+x /usr/bin/runc
    fi

    Install_Crictl
    cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/crio/crio.sock
image-endpoint: unix:///var/run/crio/crio.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF
    sed -i "s#k8s.gcr.io#${IMAGE_REPOSITORY}#g" /etc/crio/crio.conf
    systemctl daemon-reload
    systemctl enable crio --now
    echo '安装crio done! ' >>${install_log}
}

function Install() {
    # 判断安装容器类型
    case $INSTALL_CR in
    docker)
        Install_Docker
        ;;
    containerd)
        Install_Containerd
        ;;
    crio)
        Install_Crio
        ;;
    *)
        Install_Containerd
        ;;
    esac

    # 安装kubelet
    if [ "${PM}" = "apt" ]; then
        $PM -y install kubernetes-cni${KUBERNETES_CNI_VERSION:+=$KUBERNETES_CNI_VERSION"-00"} kubelet=${KUBEVERSION/v/}-00 kubeadm=${KUBEVERSION/v/}-00 kubectl=${KUBEVERSION/v/}-00
    elif [ "${PM}" = "yum" ]; then
        $PM -y install kubernetes-cni${KUBERNETES_CNI_VERSION:+-$KUBERNETES_CNI_VERSION} kubelet-${KUBEVERSION/v/} kubeadm-${KUBEVERSION/v/} kubectl-${KUBEVERSION/v/}
    else
        Red_Echo "[-] 未知的包管理器, 请检查!"
        exit 1
    fi
    systemctl enable kubelet && systemctl start kubelet
    echo '安装kubelet kubeadm kubectl done! ' >>${install_log}
}
