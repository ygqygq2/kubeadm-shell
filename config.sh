#!/usr/bin/env bash
##############################################################
# File Name: config.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 11:39:56
# Description: 配置文件脚本
##############################################################

##############################################################
## 集群安装和证书更新相关共同需要的参数设置
# 主机名:IP，需要执行脚本前设置
server0="master1:10.37.129.11"
server1="master2:10.37.129.12"
server2="master3:10.37.129.13"
##############################################################
## 集群安装相关参数设置
# 是否离线安装集群，true为离线安装
INSTALL_OFFLINE="false"
# 是否安装集群，false为添加节点，true为安装集群
INSTALL_CLUSTER="true"
# 是否安装Keepalived+HAproxy
INSTALL_SLB="true"
# 是否脚本生成CA证书
GENERATE_CA="false"
# 定义Kubernetes信息
KUBEVERSION="v1.22.3"
# 定义安装 Container runtimes: docker/containerd/crio
INSTALL_CR="docker"
# docker 版本, INSTALL_CR="docker"时设置
DOCKERVERSION="20.10.10"
#
KUBERNETES_CNI_VERSION=""
IMAGE_REPOSITORY="registry.cn-hangzhou.aliyuncs.com/google_containers"
# k8s master VIP（单节点为节点IP）
k8s_master_vip="10.37.129.10"
# K8S网段
podSubnet="10.244.0.0/16"
# kube-proxy转发模式，ipvs/iptables
KUBE_PROXY_MODE="ipvs"
# 可获取kubeadm join命令的节点IP
k8s_join_ip=$k8s_master_vip
##############################################################
## 证书更新相关参数设置
# 证书剩余天数自动更新
expire_days="90"
# 证书检查列表
ca_certs_list=(
    "/etc/kubernetes/pki/ca.crt"
    "/etc/kubernetes/pki/etcd/ca.crt"
    "/etc/kubernetes/pki/front-proxy-ca.crt"
    )
certs_list=(
    "/etc/kubernetes/pki/apiserver.crt"
    "/etc/kubernetes/pki/front-proxy-client.crt"
    "/etc/kubernetes/pki/etcd/server.crt"
    )
##############################################################
i=0
while true; do
    tmp_server=$(eval echo \$server${i})
    if [ ! -z "${tmp_server}" ]; then
        NAMES=(${NAMES[@]} ${tmp_server%:*})
        HOSTS=(${HOSTS[@]} ${tmp_server#*:})
    else
        break
    fi
    i=$(($i+1))
done
##############################################################
install_log=/root/install_log.txt
##############################################################
