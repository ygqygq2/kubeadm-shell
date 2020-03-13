#!/usr/bin/env bash
##############################################################
# File Name: setup_slb.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 14:54:49
# Description:
##############################################################

function set_slb() {
    # 设置keepalived+haproxy
    [ $INSTALL_SLB != "true" ] && return 0
    # 拉取haproxy镜像
    [ ! -d /etc/haproxy ] && mkdir /etc/haproxy
    cat >/etc/haproxy/haproxy.cfg<<EOF
global
  log 127.0.0.1 local0 err
  maxconn 50000
  uid 99
  gid 99
  #daemon
  nbproc 1
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
  server ${NAMES[0]} ${HOSTS[0]}:6443 weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
  server ${NAMES[1]} ${HOSTS[1]}:6443 weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
  server ${NAMES[2]} ${HOSTS[2]}:6443 weight 1 maxconn 1000 check inter 2000 rise 2 fall 3
EOF

    # 启动haproxy
    check_haproxy_docker=$(docker ps|grep -w k8s-haproxy)
    if [ -z "$check_haproxy_docker" ]; then
        docker run -d --name k8s-haproxy \
            -v /etc/haproxy:/usr/local/etc/haproxy:ro \
            -p 8443:8443 \
            -p 1080:1080 \
            --restart always \
            haproxy:1.7.8-alpine
    fi
    return_error_exit "docker 安装 haproxy"

    # 启动
    # 载入内核相关模块
    # lsmod | grep ip_vs
    modprobe ip_vs

    # 获取LVS网卡名
    subnet=$(echo $k8s_master_vip|awk -F '.' '{print $1"."$2"."$3"."}')
    network_card_name=$(ip route | egrep "^$subnet" | awk '{print $3}')

    # 启动keepalived
    check_keepalived_docker=$(docker ps|grep -w k8s-keepalived)
    if [ -z "$check_keepalived_docker" ]; then
        docker run --net=host --cap-add=NET_ADMIN \
            -e KEEPALIVED_INTERFACE=$network_card_name \
            -e KEEPALIVED_VIRTUAL_IPS="#PYTHON2BASH:['$k8s_master_vip']" \
            -e KEEPALIVED_UNICAST_PEERS="#PYTHON2BASH:['${HOST[0]}','${HOST[1]}','${HOST[2]}']" \
            -e KEEPALIVED_PASSWORD=k8s \
            --name k8s-keepalived \
            --restart always \
            -d osixia/keepalived:latest
    fi
    return_error_exit "docker 安装 keepalived"
    echo '安装k8s keepalived haproxy done! '>>${install_log}
}
