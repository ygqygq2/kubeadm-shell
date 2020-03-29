#!/usr/bin/env bash
##############################################################
# File Name: system.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 12:06:56
# Description:
##############################################################

function print_sys_info() {
    cat /etc/issue
    cat /etc/*-release
    uname -a
    MemTotal=`free -m | grep Mem | awk '{print  $2}'`
    echo "Memory is: ${MemTotal} MB "
    df -h
}

function set_timezone() {
    blue_echo "Setting timezone..."
    rm -f /etc/localtime
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

function disable_selinux() {
    if [ -s /etc/selinux/config ]; then
        setenforce 0
        sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    fi
}

function check_hosts() {
    if grep -Eqi '^127.0.0.1[[:space:]]*localhost' /etc/hosts; then
        echo "Hosts: ok."
    else
        echo "127.0.0.1 localhost.localdomain localhost" >> /etc/hosts
    fi
    ping -c1 www.baidu.com
    if [ $? -eq 0 ] ; then
        echo "DNS...ok"
    else
        echo "DNS...fail, add dns server to /etc/resolv.conf"
        cat > /etc/resolv.conf <<EOF
nameserver 114.114.114.114
nameserver 8.8.8.8
EOF
        echo '添加DNS done!'>>${install_log}
    fi
}

function ready_yum() {
    # 添加yum源
    [ ! -d /etc/yum.repos.d/bak/ ] && { mkdir /etc/yum.repos.d/bak/ ;mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ ; }
    cat > /etc/yum.repos.d/CentOS-Base.repo <<EOF
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-\$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/\$releasever/os/\$basearch/
    http://mirrors.aliyuncs.com/centos/\$releasever/os/\$basearch/
    http://mirrors.cloud.aliyuncs.com/centos/\$releasever/os/\$basearch/
gpgcheck=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#released updates 
[updates]
name=CentOS-\$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/\$releasever/updates/\$basearch/
    http://mirrors.aliyuncs.com/centos/\$releasever/updates/\$basearch/
    http://mirrors.cloud.aliyuncs.com/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/\$releasever/extras/\$basearch/
    http://mirrors.aliyuncs.com/centos/\$releasever/extras/\$basearch/
    http://mirrors.cloud.aliyuncs.com/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/\$releasever/centosplus/\$basearch/
    http://mirrors.aliyuncs.com/centos/\$releasever/centosplus/\$basearch/
    http://mirrors.cloud.aliyuncs.com/centos/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#contrib - packages by Centos Users
[contrib]
name=CentOS-\$releasever - Contrib - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/\$releasever/contrib/\$basearch/
    http://mirrors.aliyuncs.com/centos/\$releasever/contrib/\$basearch/
    http://mirrors.cloud.aliyuncs.com/centos/\$releasever/contrib/\$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7    
EOF
    rpm --import http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

    cat > /etc/yum.repos.d/epel-7.repo <<EOF
[epel]
name=Extra Packages for Enterprise Linux 7 - \$basearch
baseurl=http://mirrors.aliyun.com/epel/7/\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - \$basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/7/\$basearch/debug
failovermethod=priority
enabled=0
gpgkey=https://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7
gpgcheck=0

[epel-source]
name=Extra Packages for Enterprise Linux 7 - \$basearch - Source
baseurl=http://mirrors.aliyun.com/epel/7/SRPMS
failovermethod=priority
enabled=0
gpgkey=https://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7
gpgcheck=0
EOF
    rpm --import https://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7

    cat > /etc/yum.repos.d/docker-ce.repo <<EOF
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/\$basearch/stable
enabled=1
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-stable-debuginfo]
name=Docker CE Stable - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/debug-\$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-stable-source]
name=Docker CE Stable - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/source/stable
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-edge]
name=Docker CE Edge - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/\$basearch/edge
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-edge-debuginfo]
name=Docker CE Edge - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/debug-\$basearch/edge
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-edge-source]
name=Docker CE Edge - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/source/edge
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-test]
name=Docker CE Test - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/\$basearch/test
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-test-debuginfo]
name=Docker CE Test - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/debug-\$basearch/test
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-test-source]
name=Docker CE Test - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/source/test
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-nightly]
name=Docker CE Nightly - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/\$basearch/nightly
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-nightly-debuginfo]
name=Docker CE Nightly - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/debug-\$basearch/nightly
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-nightly-source]
name=Docker CE Nightly - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/source/nightly
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
EOF
    rpm --import https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

    cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    rpm --import https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg \
        https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg

    echo '添加yum源 done!'>>${install_log}
    yum clean all
    yum makecache
}

function ready_local_yum () {
    rpm -ivh $packages_dir/deltarpm-*.rpm
    rpm -ivh $packages_dir/libxml2-python-*.rpm
    rpm -ivh $packages_dir/python-deltarpm-*.rpm
    rpm -ivh $packages_dir/createrepo-*.rpm

    createrepo  $packages_dir

    # 备份现有源
    [ ! -d /etc/yum.repos.d/bak/ ] && { mkdir /etc/yum.repos.d/bak/ ;mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ ; }

cat > /etc/yum.repos.d/CentOS-Media.repo <<EOF
[c7-media]
name=CentOS-$releasever - Media
baseurl=file://$packages_dir
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
       file://$gpg_dir/Docker.gpg
       file://$gpg_dir/Aliyun-kubernetes-yum-key.gpg
       file://$gpg_dir/Aliyun-kubernetes-rpm-package-key.gpg
EOF
}

function setup_time_service (){
    #设置chrony服务
    yum -y install ntpdate
    ntpdate ntp1.aliyun.com
    cat > /etc/chrony.conf <<EOF    
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst
server ntp4.aliyun.com iburst
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony.keys
commandkey 1
generatecommandkey
noclientlog
logchange 0.5
logdir /var/log/chrony
EOF
    systemctl start chronyd 
    systemctl enable chronyd
    echo '设置时区，同步时间 done! '>>${install_log}
}

function init_install() {
    print_sys_info
    set_timezone
    disable_selinux
    check_hosts
}

function check_system () {
    clear
    printf "Checking system config now......\n"

    SUCCESS="\e[1;32m检测正常\e[0m"
    FAILURE="\e[1;31m检测异常\e[0m"
    UNKNOWN="\e[1;31m未检测到\e[0m"
    UPGRADE="\e[1;31m装服升级\e[0m"

    #检查CPU型号
    CPUNAME=$(awk -F ': ' '/model name/ {print $NF}' /proc/cpuinfo|uniq|sed 's/[ ]\{3\}//g')
    [[ -n "$CPUNAME" ]] && CPUNAMEACK="$SUCCESS" || CPUNAMEACK="$UNKNOWN"

    #检查物理CPU个数
    CPUNUMBER=$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)
    [[ "$CPUNUMBER" -ge "1" ]] && CPUNUMBERACK="$SUCCESS" || CPUNUMBERACK="$FAILURE"

    #检查CPU核心数
    CPUCORE=$(grep 'core id' /proc/cpuinfo | sort -u | wc -l)
    [[ "$CPUCORE" -ge "1" ]] && CPUCOREACK="$SUCCESS" || CPUCOREACK="$FAILURE"

    #检查线程数
    CPUPROCESSOR=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)
    [[ "$CPUPROCESSOR" -ge "1" ]] && CPUPROCESSORACK="$SUCCESS" || CPUPROCESSORACK="$FAILURE"

    #检查内存大小
    MEMSIZE=$(awk '/MemTotal/{print ($2/1024/1024)"GB"}' /proc/meminfo)
    [[ $(echo ${MEMSIZE%G*}|awk '{if($0>=4)print $0}') ]] && MEMSIZEACK="$SUCCESS" || MEMSIZEACK="$FAILURE"


    function CHECK_DISK_SIZE () {
    	#检查硬盘大小
        DSKSIZE=($(parted -l 2>/dev/null|grep Disk|grep '/dev/'|grep -v mapper|awk '{print $2 $3}'))
        for DS in ${DSKSIZE[@]}; do
            [[ $(echo ${DSKSIZE%G*}|awk -F':' '{if($2>=50)print $2}') ]] && DSKSIZEACK="$SUCCESS" || DSKSIZEACK="$FAILURE"
            printf "$DSKSIZEACK	硬盘大小:			$DS\n"
        done
    }

    #检查根分区可用大小
    DSKFREE=$(df -h / |awk 'END{print $(NF-2)}')
    [[ $(echo ${DSKFREE%G*}|awk '{if($0>=50)print $0}') ]] && DSKFREEACK="$SUCCESS" || DSKFREEACK="$FAILURE"

    function CHECK_NETWORK_CARD () {
        #获取网卡名
        cd /etc/sysconfig/network-scripts/
        IFCFGS=($(ls ifcfg-*|awk -F'-' '{print $2}'|egrep -v "lo|.old"|awk -F':' '{print $1}'))

        for IFCFG in ${IFCFGS[@]} ; do
        	#检查网卡类型,暂时不检测
        	ETHTYPE=$(ethtool -i $IFCFG|awk '/driver:/{print $NF}')
        	[[ "$ETHTYPE" = "XXXX" ]] && ETHTYPEACK="$SUCCESS" || ETHTYPEACK="$FAILURE"
        	ETHTYPEACK="$SUCCESS"

        	#检查网卡驱动版本,暂时不检测
        	DRIVERS=$(ethtool -i $IFCFG|awk '{if($1=="version:") print $NF}')
        	[[ "$DRIVERS" = "XXXX" ]] && DRIVERSACK="$SUCCESS" || DRIVERSACK="$UPGRADE"
        	DRIVERSACK="$SUCCESS"

        	#检查网卡速率
        	ETHRATE=$(ethtool $IFCFG|awk '/Speed:/{print $NF}')
        	[[ "${ETHRATE/"Mb/s"/}" -ge "1000" ]] && ETHRATEACK="$SUCCESS" || ETHRATEACK="$FAILURE"

        	printf "$ETHTYPEACK	${IFCFG}网卡类型:			$ETHTYPE\n"
        	printf "$DRIVERSACK	${IFCFG}网卡驱动版本:				$DRIVERS\n"
        	printf "$ETHRATEACK	${IFCFG}网卡速率:			$ETHRATE\n"
        done
    }

    #检查服务器生产厂家
    SEROEMS=$(dmidecode |grep -A4 "System Information"|awk -F': ' '/Manufacturer/{print $NF}')
    [[ -n "$SEROEMS" ]] && SEROEMSACK="$SUCCESS" || SEROEMSACK="$UNKNOWN"

    #检查服务器型号
    SERTYPE=$(dmidecode |grep -A4 "System Information"|awk -F': ' '/Product/{print $NF}')
    [[ -n "$SERTYPE" ]] && SERTYPEACK="$SUCCESS" || SERTYPEACK="$UNKNOWN"

    #检查服务器序列号
    SERSNUM=$(dmidecode |grep -A4 "System Information"|awk -F': ' '/Serial Number/{print $NF}')
    [[ -n "$SERSNUM" ]] && SERSNUMACK="$SUCCESS" || SERSNUMACK="$UNKNOWN"

    #检查IP个数
    IPADDRN=$(ip a|grep -v "inet6"|awk '/inet/{print $2}'|awk '{print $1}'|\
    egrep -v '^127\.'|awk -F/ '{print $1}' |wc -l)
    [[ $IPADDRN -ge 1 ]] && IPADDRS=($(ip a|grep -v "inet6"|\
        awk '/inet/{print $2}'|awk '{print $1}'|egrep -v '^127\.'|awk -F/ '{print $1}'))
    [[ $IPADDRN -ge 1 ]] && IPADDRP=$(echo ${IPADDRS[*]}|sed 's/[ ]/,/g')
    [[ $IPADDRN -ge 1 ]] && IPADDRNACK="$SUCCESS" || IPADDRNACK="$FAILURE"

    #检查操作系统版本
    OSVERSI=$(cat /etc/redhat-release)
    [[ $(echo $OSVERSI | grep 'CentOS Linux') ]] && OSVERSIACK="$SUCCESS" || OSVERSIACK="$FAILURE"

    #检查操作系统类型
    OSTYPES=$(uname -i)
    [[ $OSTYPES = "x86_64" ]] && OSTYPESACK="$SUCCESS" || OSTYPESACK="$FAILURE"

    #检查系统运行等级
    OSLEVEL=$(runlevel)
    [[ "$OSLEVEL" =~ "3" ]] && OSLEVELACK="$SUCCESS" || OSLEVELACK="$FAILURE"

    function CHECK_DISK_SPEED () {
    	twinkle_echo $(yellow_echo "Will check disk speed ......")
    	user_pass_function
    	[ $? -eq 1 ] && return 1
        yum -y install hdparm  # 先安装测试工具
    	#检查硬盘读写速率
    	DISKHW=($(hdparm -Tt $(fdisk -l|grep -i -A1 device|awk 'END{print $1}')|awk '{if(NR==3||NR==4)print $(NF-1),$NF}'))
    	#Timing cached reads
    	CACHEHW=$(echo ${DISKHW[*]}|awk '{print $1,$2}')
    	[[ $(echo $CACHEHW|awk '{if($1>3000)print $0}') ]] && CACHEHWACK="$SUCCESS" || CACHEHWACK="$FAILURE"
    	#Timing buffered disk reads
    	BUFFRHW=$(echo ${DISKHW[*]}|awk '{print $3,$4}')
    	[[ $(echo $BUFFRHW|awk '{if($1>100)print $0}') ]] && BUFFRHWACK="$SUCCESS" || BUFFRHWACK="$FAILURE"

    	printf "$CACHEHWACK	硬盘cache读写速率:			$CACHEHW\n"
    	printf "$BUFFRHWACK	硬盘buffer读写速率:			$BUFFRHW\n"
    }

    #检查时区
    OSZONES=$(date +%Z)
    [[ "$OSZONES" = "CST" ]] && OSZONESACK="$SUCCESS" || OSZONESACK="$FAILURE"

    #检查DNS配置
    yum -y install bind-utils
    DNS=($(awk '{if($1=="nameserver") print $2}' /etc/resolv.conf))
    DNSCONF=$(echo ${DNS[*]}|sed 's/[ ]/,/g')
    [[ $(grep "\<nameserver\>" /etc/resolv.conf) ]] && DNSCONFACK="$SUCCESS" || DNSCONFACK="$FAILURE"
    if [[ $(nslookup www.baidu.com|grep -A5 answer|awk '{if($1=="Address:") print $2}') ]];then
        DNSRESO=($(nslookup www.baidu.com|grep -A5 answer|awk '{if($1=="Address:") print $2}'))
        DNSRESU=$(echo ${DNSRESO[*]}|sed 's/[ ]/,/g')
        DNSRESOACK="$SUCCESS"
    else
        DNSRESU="未知"
        DNSRESOACK="$FAILURE"
    fi

    #检查SElinux状态
    SELINUX=$(sestatus |awk -F':' '{if($1=="SELinux status") print $2}'|xargs echo)
    if [[ $SELINUX = disabled ]];then
    	SELINUXACK="$SUCCESS"
    else
    	SELINUXACK="$FAILURE"
    	sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    fi
    HOSTNAME=$(hostname)
    if [[ $HOSTNAME != "localhost.localdomain" ]];then
            HostNameCK="$SUCCESS"
    else
            HostNameCK="$FAILURE"
    fi

    #打印结果
    printf "\n"
    printf "检测结果如下：\n"
    printf "===========================================================================\n"
    printf "$CPUNAMEACK	CPU型号:			$CPUNAME\n"
    printf "$CPUNUMBERACK	CPU个数:			$CPUNUMBER\n"
    printf "$CPUCOREACK	CPU核心数:			$CPUCORE\n"
    printf "$CPUPROCESSORACK	CPU进程数:			$CPUPROCESSOR\n"
    printf "$MEMSIZEACK	内存大小:			$MEMSIZE\n"
    CHECK_DISK_SIZE
    printf "$DSKFREEACK	根分区可用大小:			$DSKFREE\n"
    printf "$SEROEMSACK	服务器生产厂家:			$SEROEMS\n"
    printf "$SERTYPEACK	服务器型号:			$SERTYPE\n"
    printf "$SERSNUMACK	服务器序列号:			$SERSNUM\n"
    CHECK_NETWORK_CARD
    printf "$IPADDRNACK	配置网卡IP数:			$IPADDRN个 $IPADDRP \n"
    printf "$OSVERSIACK	操作系统版本:			$OSVERSI\n"
    printf "$OSTYPESACK	操作系统类型:			$OSTYPES\n"
    printf "$OSLEVELACK	系统运行等级:			$OSLEVEL\n"
    printf "$OSZONESACK	系统时区:			$OSZONES\n"
    printf "$DNSCONFACK	DNS配置:			$DNSCONF\n"
    printf "$DNSRESOACK	DNS解析结果:			$DNSRESU\n"
    printf "$SELINUXACK	SElinux状态:			$SELINUX\n"
    printf "$HostNameCK	主机名检测:			$HOSTNAME\n"
    # CHECK_DISK_SPEED
    printf "\n"
    [[ $SELINUX = disabled ]] || printf "%30s\e[1;32mSElinux状态已修改,请重启系统使其生效.\e[0m\n"
    printf "===========================================================================\n"
    printf "系统分区情况如下:\n\n"
    df -hPT -xtmpfs
    printf "\n"
    [[ $(df -hPT -xtmpfs|grep -A1 Filesystem|awk 'END{print $1}'|wc -L) -gt 9 ]] && printf "%30s\033[1;32m提示:存在LVM分区\033[0m\n"
    printf "===========================================================================\n"
    sleep 15
}

function system_opt () {
    yellow_echo "进行系统优化："
    # user_pass_function
    # [ $? -eq 1 ] && return 1

    init_install

    # 安装基本工具
    yum -y install openssh-clients wget rsync
    #修改SSH为允许用key登录
    mkdir -p /root/.ssh/
    chmod -R 700 /root/.ssh/
    
    # sed -i "s#PasswordAuthentication yes#PasswordAuthentication no#g"  /etc/ssh/sshd_config
    sed -i "s@#UseDNS yes@UseDNS no@" /etc/ssh/sshd_config
    sed -i 's/.*LogLevel.*/LogLevel DEBUG/g' /etc/ssh/sshd_config
    sed -i 's@#MaxStartups 10@MaxStartups 50@g' /etc/ssh/sshd_config
    # sed -i 's@#PermitRootLogin yes@PermitRootLogin no@g' /etc/ssh/sshd_config
    service sshd reload
    echo '设置ssh done!'>>${install_log}
    
    # 关闭防火墙
    systemctl disable firewalld
    systemctl stop firewalld
    echo '关闭防火墙 done!' >>${install_log}

    #关闭，开启一些服务
    systemctl enable crond
    systemctl start crond

    # 设置.bashrc
    cat > /root/.bashrc <<EOF
# .bashrc

# User specific aliases and functions

alias rm='rm --preserve-root -i'
alias cp='cp -i'
alias mv='mv -i'
alias rz='rz -b'

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
export LANG=en_US.UTF-8
export PS1="[\u@\h \W]\\\\$ "

ulimit -c unlimited
ulimit -n 40960
EOF
    echo '设置.bashrc done!'>>${install_log}

    #设置.bash_profile
    if ! grep 'redhat-release' /root/.bash_profile > /dev/null; then
    cat >> /root/.bash_profile <<EOF
echo '=========================================================='
cat /etc/redhat-release
echo '=========================================================='
EOF
    fi
    echo '设置.bash_profile done!'>>${install_log}

    # 修改系统语言
    echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
    echo '设置系统语言 done!'>>${install_log}

    # 更新bash，修复漏洞
    yum -y update bash

    #修改最大的连接数为40960，重启之后就自动生效。
    ! grep "*                soft   nofile          40960" /etc/security/limits.conf > /dev/null \
    && echo '*                soft   nofile          40960'>>/etc/security/limits.conf

    ! grep "*                hard   nofile          40960" /etc/security/limits.conf > /dev/null \
    && echo '*                hard   nofile          40960'>>/etc/security/limits.conf
    ########################################
    ! grep 'HISTFILESIZE=2000' /etc/bashrc > /dev/null && echo 'HISTFILESIZE=2000'>>/etc/bashrc
    ! grep 'HISTSIZE=2000' /etc/bashrc > /dev/null && echo 'HISTSIZE=2000'>>/etc/bashrc
    ! grep 'HISTTIMEFORMAT="%Y%m%d-%H:%M:%S: "' /etc/bashrc > /dev/null && echo 'HISTTIMEFORMAT="%Y%m%d-%H:%M:%S: "'>>/etc/bashrc
    ! grep 'export HISTTIMEFORMAT' /etc/bashrc > /dev/null && echo 'export HISTTIMEFORMAT'>>/etc/bashrc
    ########################################
}

function init_k8s () {
    # 安装docker-ce并启动
    yum -y install docker-ce-$DOCKERVERSION docker-ce-cli-$DOCKERVERSION
    systemctl enable docker && systemctl restart docker
    docker version | tee /tmp/docker-version.log
    cat /tmp/docker-version.log | grep -w $DOCKERVERSION
    if [ $? -ne 0 ]; then
        yellow_echo "docker版本未对应(可手动处理后选择[确认]继续)"
        user_verify_function
    fi
    echo '安装docker ce done! '>>${install_log}

    # 安装kubelet
    yum -y install kubernetes-cni${KUBERNETES_CNI_VERSION:+-$KUBERNETES_CNI_VERSION} kubelet-${KUBEVERSION/v/} kubeadm-${KUBEVERSION/v/} kubectl-${KUBEVERSION/v/} ipvsadm
    systemctl enable kubelet && systemctl start kubelet
    echo '安装kubelet kubeadm kubectl ipvsadm done! '>>${install_log}

    # 防火墙设置，否则可能不能转发
    iptables -P FORWARD ACCEPT

    # 关闭交换分区，并永久注释
    swapoff -a
    swap_line=$(grep '^.*swap' /etc/fstab)
    if [ ! -z "$swap_line" ]; then
        sed -i "s@$swap_line@#$swap_line@g" /etc/fstab
    fi
    echo '关闭交换分区 done! '>>${install_log}

    # 开启防火墙规则或者关闭防火墙
    # firewall-cmd --add-rich-rule 'rule family=ipv4 source address=192.168.105.0/24 accept' # # 指定源IP（段），即时生效
    # firewall-cmd --add-rich-rule 'rule family=ipv4 source address=192.168.105.0/24 accept' --permanent # 指定源IP（段），永久生效

    # 配置转发相关参数，否则可能会出错
    cat <<EOF >  /etc/sysctl.d/k8s.conf
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
    echo '设置开启转发内核参数 done! '>>${install_log}

    # 加载ipvs相关内核模块
    # 如果重新开机，需要重新加载
    modprobe ip_vs
    modprobe ip_vs_rr
    modprobe ip_vs_wrr
    modprobe ip_vs_sh
    modprobe nf_conntrack_ipv4
    # 配置开机生效模块文件，需要增加可执行权限
    cat > /etc/sysconfig/modules/ipvs.modules<<EOF    
#! /bin/sh

modules=("ip_vs"
"ip_vs_rr"
"ip_vs_wrr"
"ip_vs_sh"
"nf_conntrack_ipv4"
)

for mod in \${modules[@]}; do
/sbin/modinfo -F filename \$mod > /dev/null 2>&1
if [ $? -eq 0 ]; then
/sbin/modprobe \$mod
fi
done
EOF
    chmod a+x /etc/sysconfig/modules/ipvs.modules
    echo '设置开机加载内核模块 done! '>>${install_log}
}
