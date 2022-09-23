#!/usr/bin/env bash
##############################################################
# File Name: kubeadm_renew_certs.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: http://blog.csdn.net/ygqygq2
# Created Time : 2020-02-17 10:34:39
# Description: 更新master节点证书
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
cd $(dirname $0)
SH_DIR=$(pwd)
ME=$0
PARAMETERS=$*

. $SH_DIR/config.sh
. $SH_DIR/functions/base.sh
. $SH_DIR/functions/setup_ssl.sh

function Check_Certs_Expire() {
    # 检测域名或者证书过期剩余天数
    local domain=$1
    if [ -f "$domain" ]; then
        END_TIME=$(openssl x509 -noout -dates -in $domain | grep 'After' | awk -F '=' '{print $2}' | awk -F ' +' '{print $1,$2,$4 }')
    else
        END_TIME=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null |
            openssl x509 -noout -dates | grep 'After' | awk -F '=' '{print $2}' | awk -F ' +' '{print $1,$2,$4 }')
    fi
    # 使用openssl获取域名的证书情况，然后获取其中的到期时间
    END_TIME1=$(date +%s -d "$END_TIME")  # 将日期转化为时间戳
    NOW_TIME=$(date +%s -d "$(date +%F)") # 将目前的日期也转化为时间戳

    LEFT_DAYS=$(($(($END_TIME1 - $NOW_TIME)) / (60 * 60 * 24))) # 到期时间减去目前时间再转化为天数

    if [ $LEFT_DAYS -lt "$expire_days" ]; then # 当到期时间小于多少天
        echo "$(date +%F) 证书 [$domain] 还有 [$LEFT_DAYS] 天过期"
        return 0
    else
        echo "$(date +%F) 证书 [$domain] 还有 [$LEFT_DAYS] 天过期"
        return 1
    fi
}

function Conf_Type() {
    result=1
    for cert in ${ca_certs_list[@]}; do
        Check_Certs_Expire $cert
        result=$(($result * $?))
    done
    if [ $result -eq 0 ]; then
        type=0 # 更新CA证书和其它所有证书
        Yellow_Echo "更新CA证书和其它所有证书"
    else
        for cert in ${certs_list[@]}; do
            Check_Certs_Expire $cert
            result=$(($result * $?))
        done
        if [ $result -eq 0 ]; then
            type=1 # 更新除CA所有证书
        else
            type=1
        fi
        Yellow_Echo "更新除CA所有证书"
    fi
}

function Renew_All_Certs() {
    # 续期除CA以外其它证书
    Yellow_Echo "主机名：$HOSTNAME"
    kubeadm certs check-expiration
    kubeadm certs renew all --config /etc/kubernetes/kubeadmcfg.yaml
    rm -f /var/lib/kubelet/pki/*
    systemctl restart kubelet
    rsync -avz /etc/kubernetes/manifests/ /etc/kubernetes/manifests.bak/
    rm -f /etc/kubernetes/manifests/*.yaml
    sleep 30
    rsync -avz /etc/kubernetes/manifests.bak/ /etc/kubernetes/manifests/
}

function Renew_Secret_Ca_Certs() {
    base64_encoded_ca="$(base64 -w0 /etc/kubernetes/pki/ca.crt)"

    for namespace in $(kubectl get ns --no-headers | awk '{print $1}'); do
        for token in $(kubectl get secrets --namespace "$namespace" --field-selector type=kubernetes.io/service-account-token -o name); do
            kubectl get $token --namespace "$namespace" -o yaml |
                /bin/sed "s/\(ca.crt:\).*/\1 ${base64_encoded_ca}/" |
                kubectl apply -f -
        done
    done

    kubectl get cm/cluster-info --namespace kube-public -o yaml |
        /bin/sed "s/\(certificate-authority-data:\).*/\1 ${base64_encoded_ca}/" |
        kubectl apply -f -

    #  /bin/sed -i "s/\(certificate-authority-data:\).*/\1 ${base64_encoded_ca}/" kubelet.conf
    #  /bin/sed -i "s/\(certificate-authority-data:\).*/\1 ${base64_encoded_ca}/" scheduler.conf
}

function Renew_Ca_Certs() {
    Yellow_Echo "主机名：$HOSTNAME"
    # 备份
    mkdir -p /etc/kubernetes/conf.bak
    rsync -avz /etc/kubernetes/pki/ /etc/kubernetes/pki.bak/
    rm -f /etc/kubernetes/pki/{apiserver*,front-proxy-client.*}
    rm -f /etc/kubernetes/pki/etcd/{healthcheck-client.*,peer.*,server.*}
    if [[ "$HOSTNAME" = "${NAMES[0]}" ]]; then
        rm -f /etc/kubernetes/pki/{ca.*,front-proxy-ca.*}
        rm -f /etc/kubernetes/pki/etcd/ca.*
    fi

    # 生成证书
    if [[ "$HOSTNAME" = "${NAMES[0]}" ]]; then
        if [ "$GENERATE_CA" != "false" ]; then
            # 安装证书工具
            Install_Cfssl
            # 生成ca证书
            Generate_Cert
        fi
    fi

    # 生成证书和配置文件
    echo "kubeadm init phase certs all --config /etc/kubernetes/kubeadmcfg.yaml"
    kubeadm init phase certs all --config /etc/kubernetes/kubeadmcfg.yaml

    if [[ "$HOSTNAME" = "${NAMES[0]}" ]]; then
        # 更新 secret 里的 ca 证书
        Renew_Secret_Ca_Certs
    fi

    # 备份删除配置文件
    rsync -avz /etc/kubernetes/{admin.conf,kubelet.conf,controller-manager.conf,scheduler.conf} /etc/kubernetes/conf.bak/
    rm -f /etc/kubernetes/{admin.conf,kubelet.conf,controller-manager.conf,scheduler.conf}
    rm -f /var/lib/kubelet/pki/*
    rsync -avz /etc/kubernetes/manifests/ /etc/kubernetes/manifests.bak/
    rm -rf /etc/kubernetes/manifests/

    sleep 2
    echo "kubeadm init phase kubelet-start --config /etc/kubernetes/kubeadmcfg.yaml"
    kubeadm init phase kubelet-start --config /etc/kubernetes/kubeadmcfg.yaml
    sleep 2
    echo "kubeadm init phase kubeconfig kubelet --config /etc/kubernetes/kubeadmcfg.yaml"
    kubeadm init phase kubeconfig kubelet --config /etc/kubernetes/kubeadmcfg.yaml
    sleep 2
    echo "systemctl restart kubelet"
    systemctl restart kubelet
    sleep 2
    echo "kubeadm init phase kubeconfig all --config /etc/kubernetes/kubeadmcfg.yaml"
    kubeadm init phase kubeconfig all --config /etc/kubernetes/kubeadmcfg.yaml
    sleep 20
    rsync -avz /etc/kubernetes/manifests.bak/ /etc/kubernetes/manifests/
}

function Sync_Certs() {
    # 将相关证书文件传至其他master节点
    for ((i = $((${#HOSTS[@]} - 1)); i > 0; i--)); do
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
}

function Bootstrap_Kubelet() {
    bootstrap_token=$(kubeadm token list | grep bootstrappers | sed -n '1p' | awk '{print $1}')
    if [ -z "$bootstrap_token" ]; then
        bootstrap_token=$(kubeadm token create)
    fi
    cat >/etc/kubernetes/bootstrap-kubelet.conf <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $base64_encoded_ca
    server: https://${k8s_master_vip}:${control_plane_port}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: tls-bootstrap-token-user
  name: tls-bootstrap-token-user@kubernetes
current-context: tls-bootstrap-token-user@kubernetes
kind: Config
preferences: {}
users:
- name: tls-bootstrap-token-user
  user:
    token: $bootstrap_token
EOF

    systemctl restart kubelet
}

function Do_All() {
    cd $SH_DIR
    # 第一台master节点
    if [[ "$HOSTNAME" = "${NAMES[0]}" ]]; then
        check_running=$(ps aux | grep "/bin/bash $SH_DIR/$(basename $ME)" | grep -v grep)
        if [ -z "$check_running" ]; then # 为空表示非远程执行脚本
            Conf_Type
            Yellow_Echo "仍要更新证书？"
            User_Verify
            case $type in
            0)
                Renew_Ca_Certs
                Sync_Certs
                # 解决 kubelet 启动无法认证
                Bootstrap_Kubelet
                ;;
            1)
                Renew_All_Certs
                ;;
            *) ;;
            esac
            for ((i = 1; i <= $((${#HOSTS[@]} - 1)); i++)); do
                # 将脚本分发至master节点
                cd $SH_DIR
                $ssh_command root@${HOSTS[$i]} "mkdir -p $SH_DIR"
                rsync -avz -e "${ssh_command}" $SH_DIR/ root@${HOSTS[$i]}:$SH_DIR/
                sleep 10
                $ssh_command root@${HOSTS[$i]} "/bin/bash $SH_DIR/$(basename $ME)"
            done
        fi
    else
        Conf_Type
        Yellow_Echo "仍要更新证书？"
        User_Verify
        case $type in
        0)
            Renew_Ca_Certs
            # 解决 kubelet 启动无法认证
            Bootstrap_Kubelet
            ;;
        1)
            Renew_All_Certs
            ;;
        *) ;;
        esac
    fi
}

Do_All
# 执行完毕的时间
Green_Echo "$HOSTNAME 本次执行花时:$SECONDS 秒"
Green_Echo "请手动重启各 POD，先处理 master 相关，再处理其它 POD."
