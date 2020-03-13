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
mode: "ipvs"
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
$(for i in ${NAMES[@]}; do echo "    - \"${i}\"";done)
$(for i in ${HOSTS[@]}; do echo "    - \"${i}\"";done)
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

        if [ $i -eq 0 ]; then
            cat >> /tmp/${HOST}/kubeadmcfg.yaml << EOF
etcd:
  local:
    serverCertSANs:
      - "${NAME}"
      - "${HOST}"
    peerCertSANs:
      - "${NAME}"
      - "${HOST}"
    extraArgs:
      initial-cluster: "${NAME}=https://${HOST}:2380"
      initial-cluster-state: new
      name: ${NAME}
      listen-peer-urls: https://${HOST}:2380
      listen-client-urls: "https://127.0.0.1:2379,https://${HOST}:2379"
      advertise-client-urls: https://${HOST}:2379
      initial-advertise-peer-urls: https://${HOST}:2380
EOF
        elif [ $i -eq 1 ]; then
            cat >> /tmp/${HOST}/kubeadmcfg.yaml << EOF
etcd:
  local:
    serverCertSANs:
      - "${NAME}"
      - "${HOST}"
    peerCertSANs:
      - "${NAME}"
      - "${HOST}"
    extraArgs:
      initial-cluster: "${NAMES[0]}=https://${HOSTS[0]}:2380,${NAME}=https://${HOST}:2380"
      initial-cluster-state: existing
      name: ${NAME}
      listen-peer-urls: https://${HOST}:2380
      listen-client-urls: "https://127.0.0.1:2379,https://${HOST}:2379"
      advertise-client-urls: https://${HOST}:2379
      initial-advertise-peer-urls: https://${HOST}:2380
EOF
        else
            cat >> /tmp/${HOST}/kubeadmcfg.yaml << EOF
etcd:
  local:
    serverCertSANs:
      - "${NAME}"
      - "${HOST}"
    peerCertSANs:
      - "${NAME}"
      - "${HOST}"
    extraArgs:
      initial-cluster: "${NAMES[0]}=https://${HOSTS[0]}:2380,${NAMES[1]}=https://${HOSTS[1]}:2380,${NAME}=https://${HOST}:2380"
      initial-cluster-state: existing
      name: ${NAME}
      listen-peer-urls: https://${HOST}:2380
      listen-client-urls: "https://127.0.0.1:2379,https://${HOST}:2379"
      advertise-client-urls: https://${HOST}:2379
      initial-advertise-peer-urls: https://${HOST}:2380
EOF
        fi
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
            kubeadm init --config /etc/kubernetes/kubeadmcfg.yaml
            return_error_exit "kubeadm init"
            sleep 60
            [ ! -d $HOME/.kube ] && mkdir -p $HOME/.kube
            ln -sf /etc/kubernetes/admin.conf $HOME/.kube/config
              # chown $(id -u):$(id -g) $HOME/.kube/config

            # 将相关证书文件传至其他master节点
            for ((i=$((${#HOSTS[@]}-1)); i>0; i--)); do
                $ssh_command root@${HOSTS[$i]} "mkdir -p /etc/kubernetes/pki/etcd"
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/ca.crt root@${HOSTS[$i]}:/etc/kubernetes/pki/ca.crt
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/ca.key root@${HOSTS[$i]}:/etc/kubernetes/pki/ca.key
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/sa.key root@${HOSTS[$i]}:/etc/kubernetes/pki/sa.key
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/sa.pub root@${HOSTS[$i]}:/etc/kubernetes/pki/sa.pub
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/front-proxy-ca.crt root@${HOSTS[$i]}:/etc/kubernetes/pki/front-proxy-ca.crt
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/front-proxy-ca.key root@${HOSTS[$i]}:/etc/kubernetes/pki/front-proxy-ca.key
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/etcd/ca.crt root@${HOSTS[$i]}:/etc/kubernetes/pki/etcd/ca.crt
                rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/etcd/ca.key root@${HOSTS[$i]}:/etc/kubernetes/pki/etcd/ca.key
                rsync -avz -e "${ssh_command}" /etc/kubernetes/admin.conf root@${HOSTS[$i]}:/etc/kubernetes/admin.conf
            done
        else
            yellow_echo "以下操作失败后可手动在相应节点执行"
            green_echo "节点 $HOST"
            # 配置kubelet
            echo "kubeadm init phase certs all --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase certs all --config /etc/kubernetes/kubeadmcfg.yaml"
            sleep 2
            echo "kubeadm init phase kubelet-start --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase kubelet-start --config /etc/kubernetes/kubeadmcfg.yaml"
            sleep 2
            echo "kubeadm init phase kubeconfig kubelet --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase kubeconfig kubelet --config /etc/kubernetes/kubeadmcfg.yaml"
            sleep 2
            $ssh_command root@${HOST} "systemctl restart kubelet"

            # 添加etcd到集群中
            echo "kubeadm init phase etcd local --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase etcd local --config /etc/kubernetes/kubeadmcfg.yaml"
            if [ $i -eq 1 ]; then
                echo "kubectl exec -n kube-system etcd-${NAMES[0]} -- \
                etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt \
                --cert-file /etc/kubernetes/pki/etcd/peer.crt \
                --key-file /etc/kubernetes/pki/etcd/peer.key \
                --endpoints=https://${HOSTS[0]}:2379 \
                member add ${NAMES[1]} https://${HOSTS[1]}:2380"
                kubectl exec -n kube-system etcd-${NAMES[0]} -- \
                etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt \
                --cert-file /etc/kubernetes/pki/etcd/peer.crt \
                --key-file /etc/kubernetes/pki/etcd/peer.key \
                --endpoints=https://${HOSTS[0]}:2379 \
                member add ${NAMES[1]} https://${HOSTS[1]}:2380
            else
                echo "kubectl exec -n kube-system etcd-${NAMES[0]} -- \
                etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt \
                --cert-file /etc/kubernetes/pki/etcd/peer.crt \
                --key-file /etc/kubernetes/pki/etcd/peer.key \
                --endpoints=https://${HOSTS[0]}:2379 \
                member add ${NAMES[2]} https://${HOSTS[2]}:2380"
                kubectl exec -n kube-system etcd-${NAMES[0]} -- \
                etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt \
                --cert-file /etc/kubernetes/pki/etcd/peer.crt \
                --key-file /etc/kubernetes/pki/etcd/peer.key \
                --endpoints=https://${HOSTS[0]}:2379 \
                member add ${NAMES[2]} https://${HOSTS[2]}:2380
            fi
            return_echo "Etcd add member ${HOST}"

            sleep 2
            echo "kubeadm init phase kubeconfig all --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase kubeconfig all --config /etc/kubernetes/kubeadmcfg.yaml"
            sleep 2
            echo "kubeadm init phase control-plane all --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase control-plane all --config /etc/kubernetes/kubeadmcfg.yaml"
            sleep 2
            echo "kubeadm init phase mark-control-plane --config /etc/kubernetes/kubeadmcfg.yaml"
            $ssh_command root@${HOST} "kubeadm init phase mark-control-plane --config /etc/kubernetes/kubeadmcfg.yaml"
        fi

    done
    echo '安装k8s done! '>>${install_log}
}
