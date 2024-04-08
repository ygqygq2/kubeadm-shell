#!/usr/bin/env bash
##############################################################
# @Author      : Chinge Yang
# @Date        : 2020-03-12 12:06:56
# @LastEditTime: 2022-09-20 16:21:44
# @LastEditors : Chinge Yang
# @Description :
# @FilePath    : /kubeadm-shell/functions/system.sh
##############################################################

function System_Opt() {
    Yellow_Echo "进行系统优化："
    # User_Pass
    # [ $? -eq 1 ] && return 1

    #修改SSH为允许用key登录
    mkdir -p /root/.ssh/
    chmod -R 700 /root/.ssh/

    # sed -i "s#PasswordAuthentication yes#PasswordAuthentication no#g"  /etc/ssh/sshd_config
    sed -i "s@#UseDNS yes@UseDNS no@" /etc/ssh/sshd_config
    sed -i 's/.*LogLevel.*/LogLevel DEBUG/g' /etc/ssh/sshd_config
    sed -i 's@#MaxStartups 10@MaxStartups 50@g' /etc/ssh/sshd_config
    # sed -i 's@#PermitRootLogin yes@PermitRootLogin no@g' /etc/ssh/sshd_config
    systemctl reload sshd
    echo '设置ssh done!' >>${install_log}

    # 关闭防火墙
    systemctl disable firewalld
    systemctl stop firewalld
    echo '关闭防火墙 done!' >>${install_log}

    #关闭，开启一些服务
    systemctl enable crond || systemctl enable cron
    systemctl start crond || systemctl start cron

    # 设置.bashrc
    if ! grep 'ulimit' /root/.bashrc >/dev/null; then
        cat >>/root/.bashrc <<EOF
ulimit -c unlimited
ulimit -n 40960
EOF
    fi
    echo '设置.bashrc done!' >>${install_log}

    #设置.bash_profile
    if ! grep 'redhat-release' /root/.bash_profile >/dev/null 2>&1; then
        cat >>/root/.bash_profile <<EOF
if [ -f ~/.bashrc ] ; then
    source ~/.bashrc
fi
echo '=========================================================='
[ -f /etc/redhat-release ] && cat /etc/redhat-release
echo '=========================================================='
EOF
    fi
    echo '设置.bash_profile done!' >>${install_log}

    # 修改系统语言
    echo 'LANG="en_US.UTF-8"' >/etc/locale.conf
    echo '设置系统语言 done!' >>${install_log}

    #修改最大的连接数为40960，重启之后就自动生效。
    ! grep "*                soft   nofile          40960" /etc/security/limits.conf >/dev/null &&
        echo '*                soft   nofile          40960' >>/etc/security/limits.conf

    ! grep "*                hard   nofile          40960" /etc/security/limits.conf >/dev/null &&
        echo '*                hard   nofile          40960' >>/etc/security/limits.conf
    ########################################
    [ -f /etc/bash.bashrc ] && BASHRC="/etc/bash.bashrc" || BASHRC="/etc/bashrc"
    ! grep 'HISTFILESIZE' ${BASHRC} >/dev/null && echo 'HISTFILESIZE=2000' >> ${BASHRC}
    ! grep 'HISTSIZE' ${BASHRC} >/dev/null && echo 'HISTSIZE=2000' >> ${BASHRC}
    ! grep 'HISTTIMEFORMAT="%Y%m%d-%H:%M:%S: "' ${BASHRC} >/dev/null && echo 'HISTTIMEFORMAT="%Y%m%d-%H:%M:%S: "' >> ${BASHRC}
    ! grep 'export HISTTIMEFORMAT' ${BASHRC} >/dev/null && echo 'export HISTTIMEFORMAT' >> ${BASHRC}
    ########################################
}

function Init_K8s() {
    # 配置转发相关参数，否则可能会出错
    cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
net.ipv4.ip_forward = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
vm.overcommit_memory = 0
net.ipv4.tcp_slow_start_after_idle = 0
EOF
    sysctl --system
    echo '设置开启转发内核参数 done! ' >>${install_log}

    # 加载ipvs相关内核模块
    # 如果重新开机，需要重新加载
    modprobe ip_vs
    modprobe ip_vs_rr
    modprobe ip_vs_wrr
    modprobe ip_vs_sh
    modprobe nf_conntrack
    modprobe br_netfilter

    $PM install -y ipvsadm
    if [ "${DISTRO}" == "CentOS" ]; then
        # 安装ipvsadm
        echo '安装ipvsadm done!' >>${install_log}
        # 配置开机生效模块文件，需要增加可执行权限
        cat >/etc/sysconfig/modules/ipvs.modules <<EOF
#! /bin/sh

modules=("ip_vs"
"ip_vs_rr"
"ip_vs_wrr"
"ip_vs_sh"
"nf_conntrack"
"br_netfilter"
)

for mod in \${modules[@]}; do
/sbin/modinfo -F filename \$mod > /dev/null 2>&1
if [ $? -eq 0 ]; then
/sbin/modprobe \$mod
fi
done
EOF
        chmod a+x /etc/sysconfig/modules/ipvs.modules
    else
        cat > /etc/modules-load.d/ipvs.conf <<EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF
    fi
    echo '设置开机加载内核模块 done! ' >>${install_log}

    # 防火墙设置，否则可能不能转发
    iptables -P FORWARD ACCEPT

    # 关闭交换分区，并永久注释
    swapoff -a
    swap_line=$(grep '^.*swap' /etc/fstab)
    if [ ! -z "$swap_line" ]; then
        sed -i "s@$swap_line@#$swap_line@g" /etc/fstab
    fi
    echo '关闭交换分区 done! ' >>${install_log}

    # 开启防火墙规则或者关闭防火墙
    # firewall-cmd --add-rich-rule 'rule family=ipv4 source address=192.168.105.0/24 accept' # # 指定源IP（段），即时生效
    # firewall-cmd --add-rich-rule 'rule family=ipv4 source address=192.168.105.0/24 accept' --permanent # 指定源IP（段），永久生效
}
