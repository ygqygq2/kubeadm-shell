#!/usr/bin/env bash
##############################################################
# File Name: k8s_master.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 15:02:54
# Description:
##############################################################

function install_k8s() {
    # 安装K8S集群
    # 生成kubeadm 配置文件
    for i in "${!HOSTS[@]}"; do
        HOST=${HOSTS[$i]}
        NAME=${NAMES[$i]}
        mkdir -p /tmp/${HOST}
        if [ $INSTALL_SLB != "true" ]; then
            control_plane_port=6443
        else
            control_plane_port=8443
        fi

        cat > /tmp/${HOST}/kubeadmcfg.yaml << EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "${KUBE_PROXY_MODE}"
metricsBindAddress: 0.0.0.0:10249
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${KUBEVERSION}
imageRepository: ${IMAGE_REPOSITORY}
controlPlaneEndpoint: "${k8s_master_vip}:${control_plane_port}"

apiServer:
  extraArgs:
    bind-address: 0.0.0.0
  CertSANs:
$(for m in ${NAMES[@]}; do echo "    - \"${m}\"";done)
$(for m in ${HOSTS[@]}; do echo "    - \"${m}\"";done)
    - "${k8s_master_vip}"
    - "127.0.0.1"
    - "localhost"

controllerManager:
  extraArgs:
    bind-address: 0.0.0.0

scheduler:
  extraArgs:
    address: 0.0.0.0

networking:
  podSubnet: ${podSubnet}

EOF
        echo '生成kubeadm配置 done! '>>${install_log}

        # 同步配置文件
        $ssh_command root@${HOST} "mkdir -p /etc/kubernetes"
        rsync -avz -e "${ssh_command}" /tmp/${HOST}/kubeadmcfg.yaml root@${HOST}:/etc/kubernetes/

        # 设置kubelet启动额外参数
        #echo 'KUBELET_EXTRA_ARGS=""' > /tmp/kubelet
        #rsync -avz -e "${ssh_command}" /tmp/kubelet root@${HOST}:/etc/sysconfig/kubelet 
        
        if [ "$INSTALL_OFFLINE" != "true" ]; then
            # 提前拉取镜像
            $ssh_command root@${HOST} "kubeadm config images pull --config /etc/kubernetes/kubeadmcfg.yaml"
        fi

        # 添加环境变量
        $ssh_command root@${HOST} "! grep KUBECONFIG /root/.bash_profile \
            && echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bash_profile"

        if [ $i -eq 0 ]; then
            # 初始化
            kubeadm init --config /etc/kubernetes/kubeadmcfg.yaml --upload-certs
            return_error_exit "kubeadm init"
            sleep 60
            [ ! -d $HOME/.kube ] && mkdir -p $HOME/.kube
            ln -sf /etc/kubernetes/admin.conf $HOME/.kube/config
            # chown $(id -u):$(id -g) $HOME/.kube/config
        else
            yellow_echo "以下操作失败后可手动在相应节点执行"
            green_echo "节点 $HOST"
            certificate_key=$(kubeadm init phase upload-certs --upload-certs|tail -1)
            join_command=$(kubeadm token create --print-join-command)
            echo "$join_command --control-plane --certificate-key $certificate_key"
            $ssh_command root@${HOST} "$join_command --control-plane --certificate-key $certificate_key"
        fi

    done
    echo '安装k8s done! '>>${install_log}
}
