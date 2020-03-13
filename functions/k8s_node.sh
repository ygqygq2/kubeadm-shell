#!/usr/bin/env bash
##############################################################
# File Name: k8s_node.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 15:04:08
# Description:
##############################################################

function add_node() {
    green_echo "添加kubernetes节点[$HOSTNAME]"
    user_verify_function
    # 配置kubelet
    rsync -avz -e "${ssh_command}" root@${k8s_join_ip}:/etc/hosts /etc/hosts
    rsync -avz -e "${ssh_command}" root@${k8s_join_ip}:/etc/sysconfig/kubelet /etc/sysconfig/kubelet
    systemctl daemon-reload
    systemctl enable kubelet && systemctl restart kubelet

    # 获取加入k8s节点命令
    k8s_add_node_command=$($ssh_command root@$k8s_join_ip "kubeadm token create --print-join-command")
    $k8s_add_node_command
    echo '添加k8s node done! '>>${install_log}
}