#!/usr/bin/env bash
##############################################################
# File Name: setup_slb.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 14:54:49
# Description:
##############################################################

function Set_Slb() {
  # 设置keepalived+haproxy
  [ $INSTALL_SLB != "true" ] && return 0

  # 安装 haproxy
  [ ! -d /etc/haproxy ] && mkdir /etc/haproxy
  cat >/etc/haproxy/haproxy.cfg <<EOF
global
  log 127.0.0.1 local0 err
  maxconn 50000
  uid 99
  gid 99
  #daemon
  pidfile haproxy.pid

defaults
  mode http
  log 127.0.0.1 local0 err
  maxconn 50000
  retries 3
  timeout connect 5s
  timeout client 30s
  timeout server 30s
  timeout check 2s

listen admin_stats
  mode http
  bind 0.0.0.0:1080
  log 127.0.0.1 local0 err
  stats refresh 30s
  stats uri     /haproxy-status
  stats realm   Haproxy\ Statistics
  stats auth    admin:k8s
  stats hide-version
  stats admin if TRUE

frontend k8s-https
  bind 0.0.0.0:8443
  mode tcp
  #maxconn 50000
  default_backend k8s-https

backend k8s-https
  mode tcp
  balance roundrobin
$(for m in ${!NAMES[@]}; do echo "  server ${NAMES[m]} ${HOSTS[m]}:6443 weight 1 maxconn 1000 check inter 2000 rise 2 fall 3"; done)

EOF

  # 启动haproxy
  rsync -avz $SH_DIR/conf/haproxy/haproxy.yaml /etc/kubernetes/manifests/
  Return_Error_Exit "$cli_command 安装 haproxy"

  # 安装 keepalived
  [ ! -d /etc/keepalived ] && mkdir /etc/keepalived
  # 载入内核相关模块
  # lsmod | grep ip_vs
  modprobe ip_vs

  # 获取LVS网卡名
  subnet=$(echo $k8s_master_vip | awk -F '.' '{print $1"."$2"."$3"."}')
  network_card_name=$(ip route | egrep "^$subnet" | awk '{print $3}')

  # 启动keepalived
  cat >/etc/keepalived/keepalived.conf<<EOF
! /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state $([ "$HOSTNAME" == "${NAMES[0]}" ] && echo "MASTER" || echo "BACKUP")
    interface ${network_card_name}
    virtual_router_id 60
    priority $([ "$HOSTNAME" == "${NAMES[0]}" ] && echo "101" || echo $((1 + RANDOM % 100)))
    authentication {
        auth_type PASS
        auth_pass k8s
    }
    virtual_ipaddress {
        ${k8s_master_vip}
    }
    track_script {
        check_apiserver
    }
}
EOF
  rsync -avz $SH_DIR/conf/keepalived/check_apiserver.sh /etc/keepalived/
  rsync -avz $SH_DIR/conf/keepalived/keepalived.yaml /etc/kubernetes/manifests/
  Return_Error_Exit "安装 keepalived"
  echo '安装k8s keepalived haproxy done! ' >>${install_log}
}
