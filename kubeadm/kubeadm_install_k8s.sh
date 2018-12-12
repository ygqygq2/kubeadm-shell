#!/usr/bin/env bash                                                                                                                                                                           
##############################################################
# File Name: kubeadm_install_k8s.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: http://ygqygq2.blog.51cto.com
# Created Time : 2018-10-22 22:57:11
# Description: 
# 1. Kubeadm安装Kubernetes（3台master）
# 2. 需要在节点提前手动设置hostname
# 3. 脚本初始化时添加ssh key登录其它节点，可能需要用户按提示输入ssh密码
# 4. 安装集群在第一台master节点上执行此脚本；添加节点在节点上执行此脚本。
##############################################################

##############################################################
# 是否安装集群，false为添加节点，true为安装集群
INSTALL_CLUSTER="false"
# 是否安装Keepalived+HAproxy
INSTALL_SLB="true"
# 定义Kubernetes信息
KUBEVERSION="v1.13.0"
DOCKERVERSION="docker-ce-18.06.1.ce"
# k8s master VIP（单节点为节点IP）
k8s_master_vip="192.168.105.150"
# 主机名:IP，需要执行脚本前设置
server0="master1:192.168.105.151"
server1="master2:192.168.105.152"
server2="master3:192.168.105.153"
# K8S网段
podSubnet="10.244.0.0/16"
# 可获取kubeadm join命令的节点IP
k8s_join_ip=$k8s_master_vip
##############################################################
NAMES=(${server0%:*} ${server1%:*} ${server2%:*})
HOSTS=(${server0#*:} ${server1#*:} ${server2#*:})
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
cd `dirname $0`
SH_DIR=`pwd`
ME=$0
PARAMETERS=$*
# 定义ssh参数
ssh_port="22"
ssh_parameters="-o StrictHostKeyChecking=no -o ConnectTimeout=60"
ssh_command="ssh ${ssh_parameters} -p ${ssh_port}"
scp_command="scp ${ssh_parameters} -P ${ssh_port}"

# 定义日志
install_log=/root/install_log.txt

#定义输出颜色函数
function red_echo () {
#用法:  red_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;31m ${what} \e[0m"
}

function green_echo () {
#用法:  green_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;32m ${what} \e[0m"
}

function yellow_echo () {
#用法:  yellow_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;33m ${what} \e[0m"
}

function blue_echo () {
#用法:  blue_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;34m ${what} \e[0m"
}

function twinkle_echo () {
#用法:  twinkle_echo $(red_echo "内容")  ,此处例子为红色闪烁输出
local twinkle='\e[05m'
local what="${twinkle} $*"
echo -e "$(date +%F-%T) ${what}"
}

function return_echo () {
if [ $? -eq 0 ]; then
    echo -n "$* " && green_echo "成功"
    return 0
else
    echo -n "$* " && red_echo "失败"
    return 1
fi
}

function return_error_exit () {
[ $? -eq 0 ] && local REVAL="0"
local what=$*
if [ "$REVAL" = "0" ];then
    [ ! -z "$what" ] && { echo -n "$* " && green_echo "成功" ; }
else
    red_echo "$* 失败，脚本退出"
    exit 1
fi
}

# 定义确认函数
function user_verify_function () {
while true;do
    echo ""
    read -p "是否确认?[Y/N]:" Y
    case $Y in
        [yY]|[yY][eE][sS])
            echo -e "answer:  \\033[20G [ \e[1;32m是\e[0m ] \033[0m"
            break
        ;;
        [nN]|[nN][oO])
            echo -e "answer:  \\033[20G [ \e[1;32m否\e[0m ] \033[0m"
            exit 1
        ;;
        *)
            continue
    esac
done
}

# 定义跳过函数
function user_pass_function () {
while true;do
    echo ""
    read -p "是否确认?[Y/N]:" Y
    case $Y in
        [yY]|[yY][eE][sS])
            echo -e "answer:  \\033[20G [ \e[1;32m是\e[0m ] \033[0m"
            break
            ;;
        [nN]|[nN][oO])
            echo -e "answer:  \\033[20G [ \e[1;32m否\e[0m ] \033[0m"
            return 1
            ;;
        *)
            continue
    esac
done
}


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
    rm -rf /etc/localtime
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
gpgcheck=1
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
gpgcheck=1
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
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    rpm --import https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg \
        https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg

    echo '添加yum源 done!'>>${install_log}
    yum clean all
    yum makecache
}

function init_install() {
    print_sys_info
    set_timezone
    disable_selinux
    check_hosts
    ready_yum
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
    echo '创建ssh登录所用的目录---done!'>>${install_log}
    
    # sed -i "s#PasswordAuthentication yes#PasswordAuthentication no#g"  /etc/ssh/sshd_config
    sed -i "s@#UseDNS yes@UseDNS no@" /etc/ssh/sshd_config
    sed -i 's/.*LogLevel.*/LogLevel DEBUG/g' /etc/ssh/sshd_config
    sed -i 's@#MaxStartups 10@MaxStartups 50@g' /etc/ssh/sshd_config
    # sed -i 's@#PermitRootLogin yes@PermitRootLogin no@g' /etc/ssh/sshd_config
    service sshd reload
    echo '设置ssh免密登录 done!'>>${install_log}
    
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
    if ! grep 'df' /root/.bash_profile > /dev/null; then
    cat >> /root/.bash_profile <<EOF
echo '=========================================================='
cat /etc/redhat-release
echo '=========================================================='
df -lh
EOF
    fi
    echo '设置.bash_profile done!'>>${install_log}

    # 修改系统语言
    echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
    echo '设置系统语言 done!'>>${install_log}

    # 更新bash，修复漏洞
    yum -y update bash

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
    yum -y install $DOCKERVERSION
    systemctl enable docker && systemctl restart docker
    echo '安装docker ce done! '>>${install_log}

    # 安装kubelet
    yum install -y kubelet-${KUBEVERSION/v/} kubeadm-${KUBEVERSION/v/} kubectl${KUBEVERSION/v/} ipvsadm
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

function set_slb() {
    # 设置keepalived+haproxy
    [ $INSTALL_SLB != "true" ] && return 0
    # 拉取haproxy镜像
    mkdir /etc/haproxy
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
            -d keepalived:latest
    fi
    echo '安装k8s keepalived haproxy done! '>>${install_log}
}

function install_cfssl() {
    #  安装cfssl
    [ -f /usr/local/sbin/cfssl ] && yellow_echo "No need to install cfssl" && return 0 
    wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
    wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
    wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
    chmod +x cfssl_linux-amd64 cfssljson_linux-amd64 cfssl-certinfo_linux-amd64
    \mv cfssl_linux-amd64 /usr/local/sbin/cfssl
    \mv cfssljson_linux-amd64 /usr/local/sbin/cfssljson
    \mv cfssl-certinfo_linux-amd64 /usr/local/sbin/cfssl-certinfo
    echo '安装cfssl done! '>>${install_log}
}

function generate_cert() {
    # 生成有效期为10年CA证书
    cd $SH_DIR
    cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "server": {
        "expiry": "87600h",
        "usages": [
          "signing",
          "key encipherment",
          "server auth"
        ]
      },
      "client": {
        "expiry": "87600h",
        "usages": [
          "signing",
          "key encipherment",
          "client auth"
        ]
      },
      "peer": {
        "expiry": "87600h",
        "usages": [
          "signing",
          "key encipherment",
          "client auth"
        ]
      }
    }
  }
}
EOF
    cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "CN": "kubernetes"
    }
  ]
}
EOF

    cfssl gencert -initca ca-csr.json -config ca-config.json| cfssljson -bare ca - 
    [ -d /etc/kubernetes/pki ] && mv /etc/kubernetes/pki /etc/kubernetes/pki.bak
    mkdir -p /etc/kubernetes/pki/etcd
    rsync -avz ca.pem /etc/kubernetes/pki/etcd/ca.crt
    rsync -avz ca-key.pem /etc/kubernetes/pki/etcd/ca.key
    rsync -avz ca.pem /etc/kubernetes/pki/ca.crt
    rsync -avz ca-key.pem /etc/kubernetes/pki/ca.key

    # 分发到其它master节点
    for h in ${HOSTS[@]}; do
        rsync -avz -e "${ssh_command}" /etc/kubernetes/pki/
    done
    echo '安装k8s证书 done! '>>${install_log}
}

function install_k8s() {
    # 安装K8S集群
    # 生成kubeadm 配置文件
    for i in "${!HOSTS[@]}"; do
        # 添加hosts
        ! grep ${NAMES[0]} /etc/hosts > /dev/null && echo $server0|awk -F ':' '{print $2" "$1}' >> /etc/hosts
        ! grep ${NAMES[1]} /etc/hosts > /dev/null && echo $server1|awk -F ':' '{print $2" "$1}' >> /etc/hosts
        ! grep ${NAMES[2]} /etc/hosts > /dev/null && echo $server2|awk -F ':' '{print $2" "$1}' >> /etc/hosts
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
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: ${KUBEVERSION}
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers
controlPlaneEndpoint: "${k8s_master_vip}:${control_plane_port}"

apiServer:
  extraArgs:
    bind-address: 0.0.0.0
  CertSANs:
    - "${server0#*:}"
    - "${server1#*:}"
    - "${server2#*:}"
    - "${server0%:*}"
    - "${server1%:*}"
    - "${server2%:*}"
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

        # 提前拉取镜像
        $ssh_command root@${HOST} "kubeadm config images pull --config /etc/kubernetes/kubeadmcfg.yaml"

        # 添加环境变量
        $ssh_command root@${HOST} "! grep KUBECONFIG /root/.bash_profile \
            && echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bash_profile"

        if [ $i -eq 0 ]; then
            # 初始化
            kubeadm init --config /etc/kubernetes/kubeadmcfg.yaml
            return_error_exit "kubeadm init"
            sleep 60
              mkdir -p $HOME/.kube
              \cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
              chown $(id -u):$(id -g) $HOME/.kube/config  mkdir -p $HOME/.kube
              \cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
              chown $(id -u):$(id -g) $HOME/.kube/config

            # 将ca相关文件传至其他master节点
            CONTROL_PLANE_IPS=(${HOSTS[1]} ${HOSTS[2]})
            for host in ${CONTROL_PLANE_IPS[@]}; do
                $scp_command /etc/kubernetes/pki/ca.crt root@$host:/etc/kubernetes/pki/ca.crt
                $scp_command /etc/kubernetes/pki/ca.key root@$host:/etc/kubernetes/pki/ca.key
                $scp_command /etc/kubernetes/pki/sa.key root@$host:/etc/kubernetes/pki/sa.key
                $scp_command /etc/kubernetes/pki/sa.pub root@$host:/etc/kubernetes/pki/sa.pub
                $scp_command /etc/kubernetes/pki/front-proxy-ca.crt root@$host:/etc/kubernetes/pki/front-proxy-ca.crt
                $scp_command /etc/kubernetes/pki/front-proxy-ca.key root@$host:/etc/kubernetes/pki/front-proxy-ca.key
                $ssh_command root@$host "mkdir -p /etc/kubernetes/pki/etcd"
                $scp_command /etc/kubernetes/pki/etcd/ca.crt root@$host:/etc/kubernetes/pki/etcd/ca.crt
                $scp_command /etc/kubernetes/pki/etcd/ca.key root@$host:/etc/kubernetes/pki/etcd/ca.key
                $scp_command /etc/kubernetes/admin.conf root@$host:/etc/kubernetes/admin.conf
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

function add_node() {
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

function do_all() {
    if [ "$HOSTNAME" = "${NAMES[0]}" ]; then
        # 免交互生成ssh key
        [ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''
        chmod 0600 ~/.ssh/id_rsa
        for h in ${HOSTS[@]}; do
            ssh-copy-id ${ssh_parameters} -p ${ssh_port} -i ~/.ssh/id_rsa -f root@${h}
        done
    fi

    # 第一台master节点
    if [[ "$INSTALL_CLUSTER" != "false" && "$HOSTNAME" = "${NAMES[0]}" ]]; then
        check_running=$(ps aux|grep "/bin/bash /tmp/$(basename $ME)"|grep -v grep)
        if [ -z "$check_running" ]; then  # 为空表示非远程执行脚本
            for ((i=$((${#HOSTS[@]}-1)); i>=0; i--)); do
                $ssh_command root@${HOSTS[$i]} "yum -y install rsync"
                # 将脚本分发至master节点
                rsync -avz -e "${ssh_command}" $ME root@${HOSTS[$i]}:/tmp/
                $ssh_command root@${HOSTS[$i]} "/bin/bash /tmp/$(basename $ME)"
            done
        else
            # 系统检查
            check_system
            # 系统优化
            system_opt
            # 安装docker-ce等
            init_k8s
            # 安装证书工具
            install_cfssl
            # 生成证书
            generate_cert

            set_slb

            # 安装Kubernetes
            install_k8s
        fi
    else  # 其它节点
        # 系统检查
        check_system
        # 系统优化
        system_opt
        # 安装docker-ce等
        init_k8s

        # 安装k8s，master节点设置lvs
        if [ "$INSTALL_CLUSTER" != "false" ]; then
            set_slb
        else
            # 注册Kubernetes节点
            add_node
        fi
    fi
}


do_all
# 执行完毕的时间
green_echo "本次安装花时:$SECONDS 秒"
echo '完成安装 '>>${install_log}

