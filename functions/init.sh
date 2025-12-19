#!/usr/bin/env bash
##############################################################
# @Author      : Chinge Yang
# @Date        : 2022-09-20 15:56:30
# @LastEditTime: 2022-09-20 17:16:22
# @LastEditors : Chinge Yang
# @Description : 初始化函数
# @FilePath    : /kubeadm-shell/functions/init.sh
##############################################################

function Ready_Local_Repo() {
    if [ "$PM" == "yum" ]; then
        rpm -ivh $PACKAGES_DIR/deltarpm-*.rpm
        rpm -ivh $PACKAGES_DIR/libxml2-python-*.rpm
        rpm -ivh $PACKAGES_DIR/python-deltarpm-*.rpm
        rpm -ivh $PACKAGES_DIR/createrepo-*.rpm

        createrepo $PACKAGES_DIR

        # 备份现有源
        [ ! -d /etc/yum.repos.d/bak/ ] && {
            mkdir /etc/yum.repos.d/bak/
            mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
        }

        cat >/etc/yum.repos.d/CentOS-Media.repo <<EOF
[c7-media]
name=CentOS-$releasever - Media
baseurl=file://$PACKAGES_DIR
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
       file://$GPG_DIR/Docker.gpg
       file://$GPG_DIR/Aliyun-kubernetes-yum-key.gpg
       file://$GPG_DIR/Aliyun-kubernetes-rpm-package-key.gpg
EOF
    elif [ "$PM" == "apt" ]; then
        # 备份现有源
        [ ! -d /etc/apt/sources.list.d/bak/ ] && {
            mkdir /etc/apt/bak/
            mv /etc/apt/sources.list /etc/apt/bak/
            mv /etc/apt/sources.list.d/*.list /etc/apt/bak/
        }

        cat >/etc/apt/sources.list.d/local.list <<EOF
deb [trusted=yes] file:$PACKAGES_DIR ./
EOF
        apt -y update
    else
        Red_Echo "当前系统不支持离线安装"
        return 1
    fi
}

Install_LSB() {
    echo "[+] Installing lsb..."
    if [ "$PM" = "yum" ]; then
        yum -y install redhat-lsb
    elif [ "$PM" = "apt" ]; then
        apt-get update
        apt-get --no-install-recommends install -y lsb-release
    fi
}

Get_Dist_Version() {
    if command -v lsb_release >/dev/null 2>&1; then
        DISTRO_Version=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_Version="$DISTRIB_RELEASE"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_Version="$VERSION_ID"
    fi
    if [[ "${DISTRO}" = "" || "${DISTRO_Version}" = "" ]]; then
        if command -v python2 >/dev/null 2>&1; then
            DISTRO_Version=$(python2 -c 'import platform; print platform.linux_distribution()[1]')
        elif command -v python3 >/dev/null 2>&1; then
            DISTRO_Version=$(python3 -c 'import distro; print(distro.linux_distribution()[1])' || python3 -c 'import platform; print(platform.linux_distribution()[1])')
        else
            Install_LSB
            DISTRO_Version=$(lsb_release -rs)
        fi
    fi
    printf -v "${DISTRO}_Version" '%s' "${DISTRO_Version}"
}

Get_Dist_Name() {
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
        if grep -Eq "CentOS Stream" /etc/*-release; then
            isCentosStream='y'
        fi
    elif grep -Eqi "Alibaba" /etc/issue || grep -Eq "Alibaba Cloud Linux" /etc/*-release; then
        DISTRO='Alibaba'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun Linux" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Amazon Linux" /etc/issue || grep -Eq "Amazon Linux" /etc/*-release; then
        DISTRO='Amazon'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Oracle Linux" /etc/issue || grep -Eq "Oracle Linux" /etc/*-release; then
        DISTRO='Oracle'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux" /etc/issue || grep -Eq "Red Hat Enterprise Linux" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "rockylinux" /etc/issue || grep -Eq "Rocky Linux" /etc/*-release; then
        DISTRO='Rocky'
        PM='yum'
    elif grep -Eqi "almalinux" /etc/issue || grep -Eq "AlmaLinux" /etc/*-release; then
        DISTRO='Alma'
        PM='yum'
    elif grep -Eqi "openEuler" /etc/issue || grep -Eq "openEuler" /etc/*-release; then
        DISTRO='openEuler'
        PM='yum'
    elif grep -Eqi "Anolis OS" /etc/issue || grep -Eq "Anolis OS" /etc/*-release; then
        DISTRO='Anolis'
        PM='yum'
    elif grep -Eqi "Kylin Linux Advanced Server" /etc/issue || grep -Eq "Kylin Linux Advanced Server" /etc/*-release; then
        DISTRO='Kylin'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt'
    elif grep -Eqi "Deepin" /etc/issue || grep -Eq "Deepin" /etc/*-release; then
        DISTRO='Deepin'
        PM='apt'
    elif grep -Eqi "Mint" /etc/issue || grep -Eq "Mint" /etc/*-release; then
        DISTRO='Mint'
        PM='apt'
    elif grep -Eqi "Kali" /etc/issue || grep -Eq "Kali" /etc/*-release; then
        DISTRO='Kali'
        PM='apt'
    elif grep -Eqi "UnionTech OS" /etc/issue || grep -Eq "UnionTech OS" /etc/*-release; then
        DISTRO='UOS'
        if command -v apt >/dev/null 2>&1; then
            PM='apt'
        elif command -v yum >/dev/null 2>&1; then
            PM='yum'
        fi
    elif grep -Eqi "Kylin Linux Desktop" /etc/issue || grep -Eq "Kylin Linux Desktop" /etc/*-release; then
        DISTRO='Kylin'
        PM='yum'
    else
        DISTRO='unknow'
    fi
    Get_OS_Bit
}

Get_RHEL_Version() {
    Get_Dist_Name
    if [ "${DISTRO}" = "RHEL" ] || [ "${DISTRO}" = "CentOS" ]; then
        if grep -Eqi "release 5." /etc/redhat-release; then
            echo "Current Version: $DISTRO Ver 5"
            RHEL_Ver='5'
        elif grep -Eqi "release 6." /etc/redhat-release; then
            echo "Current Version: $DISTRO Ver 6"
            RHEL_Ver='6'
        elif grep -Eqi "release 7." /etc/redhat-release; then
            echo "Current Version: $DISTRO Ver 7"
            RHEL_Ver='7'
        elif grep -Eqi "release 8." /etc/redhat-release; then
            echo "Current Version: $DISTRO Ver 8"
            RHEL_Ver='8'
        elif grep -Eqi "release 9." /etc/redhat-release; then
            echo "Current Version: $DISTRO Ver 9"
            RHEL_Ver='9'
        fi
        RHEL_Version="$(cat /etc/redhat-release | sed 's/.*release\ //' | sed 's/\ .*//')"
    fi
}

Get_OS_Bit() {
    Init_Arch
    # if [[ $(getconf WORD_BIT) = '32' && $(getconf LONG_BIT) = '64' ]]; then
    #     Is_64bit='y'
    #     ARCH='x86_64'
    # else
    #     Is_64bit='n'
    #     ARCH='i386'
    # fi

    # if uname -m | grep -Eqi "arm|aarch64"; then
    #     Is_ARM='y'
    #     if uname -m | grep -Eqi "armv7|armv6"; then
    #         ARCH='armhf'
    #     elif uname -m | grep -Eqi "aarch64"; then
    #         ARCH='aarch64'
    #     else
    #         ARCH='arm'
    #     fi
    # fi
}

function Set_Timezone() {
    Blue_Echo "Setting timezone..."
    rm -rf /etc/localtime
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

function Set_Chrony() {
    #设置chrony服务
    ntpdate ntp1.aliyun.com
    cat >/etc/chrony.conf <<EOF
server ntp1.aliyun.com iburst
server time1.cloud.tencent.com iburst
server ntp.myhuaweicloud.com iburst
server pool.ntp.org iburst
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
    [ -f /etc/chrony/chrony.conf ] && ln -sf /etc/chrony.conf /etc/chrony/chrony.conf
}

function CentOS_InstallNTP() {
    Blue_Echo "[+] Installing chrony..."
    yum install -y ntpdate chrony
    Set_Chrony
    systemctl start chronyd
    systemctl enable chronyd
    date
    echo '设置时区，同步时间 done! ' >>${install_log}
}

function Deb_InstallNTP() {
    apt-get update -y
    [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
    Blue_Echo "[+] Installing chrony..."
    apt-get install -y ntpdate chrony
    Set_Chrony
    systemctl start chrony
    systemctl enable chrony
    date
    echo '设置时区，同步时间 done! ' >>${install_log}
}

function CentOS_RemoveAMP() {
    Blue_Echo "[-] Yum remove packages..."
    rpm -qa | grep httpd
    rpm -e httpd httpd-tools --nodeps
    yum -y remove httpd*
    yum clean all
}

function Deb_RemoveAMP() {
    Blue_Echo "[-] apt-get remove packages..."
    apt-get update -y
    [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
    for removepackages in apache2-doc; do apt-get purge -y $removepackages; done
    dpkg -P apache2-doc
    apt-get autoremove -y && apt-get clean
}

function Disable_Selinux() {
    if [ -s /etc/selinux/config ]; then
        setenforce 0
        sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    fi
}

function Xen_Hwcap_Setting() {
    if [ -s /etc/ld.so.conf.d/libc6-xen.conf ]; then
        sed -i 's/hwcap 1 nosegneg/hwcap 0 nosegneg/g' /etc/ld.so.conf.d/libc6-xen.conf
    fi
}

function Check_Hosts() {
    if grep -Eqi '^127.0.0.1[[:space:]]*localhost' /etc/hosts; then
        echo "Hosts: ok."
    else
        echo "127.0.0.1 localhost.localdomain localhost" >>/etc/hosts
    fi

    pingresult=$(ping -c1 www.baidu.com 2>&1)
    echo "${pingresult}"
    if echo "${pingresult}" | grep -q "unknown host"; then
        echo "DNS...fail"
        echo "Writing nameserver to /etc/resolv.conf ..."
        echo -e "nameserver 208.67.220.220\nnameserver 114.114.114.114" >/etc/resolv.conf
        echo '添加DNS done!' >>${install_log}
    else
        echo "DNS...ok"
    fi
}

function RHEL_Modify_Source() {
    Get_RHEL_Version
    if [ "${RHELRepo}" = "local" ]; then
        echo "DO NOT change RHEL repository, use the repository you set."
    else
        echo "RHEL ${RHEL_Ver} will use aliyun centos repository..."
        if [ ! -s "/etc/yum.repos.d/Centos-${RHEL_Ver}.repo" ]; then
            if command -v curl >/dev/null 2>&1; then
                curl http://mirrors.aliyun.com/repo/Centos-${RHEL_Ver}.repo -o /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
            else
                wget --prefer-family=IPv4 http://mirrors.aliyun.com/repo/Centos-${RHEL_Ver}.repo -O /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
            fi
        fi
        if echo "${RHEL_Version}" | grep -Eqi "^6"; then
            sed -i "s#centos/\$releasever#centos-vault/\$releasever#g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
            sed -i "s/\$releasever/${RHEL_Version}/g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
        elif echo "${RHEL_Version}" | grep -Eqi "^7"; then
            sed -i "s/\$releasever/7/g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
        elif echo "${RHEL_Version}" | grep -Eqi "^8"; then
            sed -i "s#centos/\$releasever#centos-vault/8.5.2111#g" /etc/yum.repos.d/Centos-${RHEL_Ver}.repo
        fi
        yum clean all
        yum makecache
    fi
    sed -i "s/^enabled[ ]*=[ ]*1/enabled=0/" /etc/yum/pluginconf.d/subscription-manager.conf
}

function Ubuntu_Modify_Source() {
    if [ "${country}" = "CN" ]; then
        OldReleasesURL='http://mirrors.aliyun.com/oldubuntu-releases/ubuntu/'
    else
        OldReleasesURL='http://old-releases.ubuntu.com/ubuntu/'
    fi
    CodeName=''
    if grep -Eqi "10.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^10.10'; then
        CodeName='maverick'
    elif grep -Eqi "11.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^11.04'; then
        CodeName='natty'
    elif  grep -Eqi "11.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^11.10'; then
        CodeName='oneiric'
    elif grep -Eqi "12.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^12.10'; then
        CodeName='quantal'
    elif grep -Eqi "13.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^13.04'; then
        CodeName='raring'
    elif grep -Eqi "13.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^13.10'; then
        CodeName='saucy'
    elif grep -Eqi "10.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^10.04'; then
        CodeName='lucid'
    elif grep -Eqi "14.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^14.10'; then
        CodeName='utopic'
    elif grep -Eqi "15.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^15.04'; then
        CodeName='vivid'
    elif grep -Eqi "12.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^12.04'; then
        CodeName='precise'
    elif grep -Eqi "15.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^15.10'; then
        CodeName='wily'
    elif grep -Eqi "16.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.10'; then
        CodeName='yakkety'
    elif grep -Eqi "14.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^14.04'; then
        Ubuntu_Deadline trusty
    elif grep -Eqi "17.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^17.04'; then
        CodeName='zesty'
    elif grep -Eqi "17.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^17.10'; then
        CodeName='artful'
    elif grep -Eqi "16.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.04'; then
        Ubuntu_Deadline xenial
    elif grep -Eqi "16.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^16.10'; then
        CodeName='yakkety'
    elif grep -Eqi "18.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^18.04'; then
        Ubuntu_Deadline bionic
    elif grep -Eqi "18.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^18.10'; then
        CodeName='cosmic'
    elif grep -Eqi "19.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^19.04'; then
        CodeName='disco'
    elif grep -Eqi "19.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^19.10'; then
        CodeName='eoan'
    elif grep -Eqi "20.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^20.04'; then
        Ubuntu_Deadline focal
    elif grep -Eqi "20.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^20.10'; then
        CodeName='groovy'
    elif grep -Eqi "21.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^21.04'; then
        CodeName='hirsute'
    elif grep -Eqi "21.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^21.10'; then
        CodeName='impish'
    elif grep -Eqi "22.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^22.04'; then
        Ubuntu_Deadline jammy
    elif grep -Eqi "22.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^22.10'; then
        CodeName='kinetic'
    elif grep -Eqi "23.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^23.04'; then
        CodeName='lunar'
    elif grep -Eqi "23.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^23.10'; then
        CodeName='mantic'
    elif grep -Eqi "24.04" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^24.04'; then
        Ubuntu_Deadline noble
    elif grep -Eqi "24.10" /etc/*-release || echo "${Ubuntu_Version}" | grep -Eqi '^24.10'; then
        CodeName='oracular'
    fi
    if [ "${CodeName}" != "" ]; then
        \cp /etc/apt/sources.list /etc/apt/sources.list.$(date +"%Y%m%d")
        cat >/etc/apt/sources.list <<EOF
deb ${OldReleasesURL} ${CodeName} main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-security main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-updates main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-proposed main restricted universe multiverse
deb ${OldReleasesURL} ${CodeName}-backports main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName} main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-security main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-updates main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-proposed main restricted universe multiverse
deb-src ${OldReleasesURL} ${CodeName}-backports main restricted universe multiverse
EOF
    fi
}

function Check_Old_Releases_URL() {
    OR_Status=$(wget --spider --server-response ${OldReleasesURL}/dists/$1/Release 2>&1 | awk '/^  HTTP/{print $2}')
    if [ "${OR_Status}" = "200" ]; then
        echo "Ubuntu old-releases status: ${OR_Status}"
        CodeName="$1"
    fi
}

function Ubuntu_Deadline()
{
    trusty_deadline=`date -d "2024-4-30 00:00:00" +%s`
    xenial_deadline=`date -d "2026-4-30 00:00:00" +%s`
    bionic_deadline=`date -d "2028-7-30 00:00:00" +%s`
    focal_deadline=`date -d "2030-4-30 00:00:00" +%s`
    jammy_deadline=`date -d "2032-4-30 00:00:00" +%s`
    noble_deadline=`date -d "2036-4-30 00:00:00" +%s`
    cur_time=`date  +%s`
    case "$1" in
        trusty)
            if [ ${cur_time} -gt ${trusty_deadline} ]; then
                echo "${cur_time} > ${trusty_deadline}"
                Check_Old_Releases_URL trusty
            fi
            ;;
        xenial)
            if [ ${cur_time} -gt ${xenial_deadline} ]; then
                echo "${cur_time} > ${xenial_deadline}"
                Check_Old_Releases_URL xenial
            fi
            ;;
        bionic)
            if [ ${cur_time} -gt ${bionic_deadline} ]; then
                echo "${cur_time} > ${bionic_deadline}"
                Check_Old_Releases_URL bionic
            fi
            ;;
        focal)
            if [ ${cur_time} -gt ${focal_deadline} ]; then
                echo "${cur_time} > ${focal_deadline}"
                Check_Old_Releases_URL focal
            fi
            ;;
        jammy)
            if [ ${cur_time} -gt ${jammy_deadline} ]; then
                echo "${cur_time} > ${jammy_deadline}"
                Check_Old_Releases_URL jammy
            fi
            ;;
        noble)
            if [ ${cur_time} -gt ${noble_deadline} ]; then
                echo "${cur_time} > ${noble_deadline}"
                Check_Old_Releases_URL noble
            fi
            ;;
    esac
}

function CentOS_Modify_Source() {
    Get_RHEL_Version
    if echo "${CentOS_Version}" | grep -Eqi "^6"; then
        Yellow_Echo "CentOS 6 is now end of life, use vault repository."
        local repo_url="https://mirrors.aliyun.com/repo/Centos-vault-6.10.repo"
    elif  echo "${CentOS_Version}" | grep -Eqi "^7"; then
        local repo_url="https://mirrors.aliyun.com/repo/Centos-7.repo"
    elif echo "${CentOS_Version}" | grep -Eqi "^8" && [ "${isCentosStream}" != "y" ]; then
        Yellow_Echo "CentOS 8 is now end of life, use vault repository."
        local repo_url="https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo"
    elif echo "${CentOS_Version}" | grep -Eqi "^9" || [ "${isCentosStream}" = "y" ]; then
        Yellow_Echo "Using CentOS Stream 9 repository."
        local repo_url="https://mirrors.aliyun.com/repo/centos-stream-9.repo"
    fi

    mkdir -p /etc/yum.repos.d/bak
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null || true
    curl -o /etc/yum.repos.d/CentOS-Base.repo "$repo_url"
}

function Ubuntu_Docker_Source() {
    if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    fi
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get -y update
}

function RHEL_Docker_Source() {
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/gpg | tee /etc/pki/rpm-gpg/RPM-GPG-KEY-docker-ce
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-docker-ce
}

function Ubuntu_Kubernetes_Source() {
    if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
    curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBEVERSION%.*}/deb/Release.key | \
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    fi
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBEVERSION%.*}/deb/ /" | \
        tee /etc/apt/sources.list.d/kubernetes.list
    apt-get -y update
}

function RHEL_Kubernetes_Source() {
    cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBEVERSION%.*}/rpm/
enabled=1
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBEVERSION%.*}/rpm/repodata/repomd.xml.key
EOF
    rpm --import https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBEVERSION%.*}/rpm/repodata/repomd.xml.key
}

function Ubuntu_Crio_Source() {
    # ref: https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/
    local tmp_VERSION=${KUBEVERSION#*v}
    local VERSION=${tmp_VERSION%.*}
    echo 'deb http://deb.debian.org/debian buster-backports main' >/etc/apt/sources.list.d/backports.list
    apt update -y
    apt install -y -t buster-backports libseccomp2 || apt update -y -t buster-backports libseccomp2

    echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" \
        >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" \
        >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

    mkdir -p /usr/share/keyrings
    curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
    curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

    apt-get update -y
    apt-get install -y cri-o cri-o-runc
}

function RHEL_Crio_Source() {
    # ref https://kubernetes.io/docs/setup/production-environment/container-runtimes/#tab-cri-cri-o-installation-2
    OS="${DISTRO}_${RHEL_Ver}"
    local tmp_VERSION=${KUBEVERSION#*v}
    local VERSION=${tmp_VERSION%.*}
    curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo \
        https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
    curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo \
        https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
    sed -i 's@gpgcheck=1@gpgcheck=0@g' /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
}

function Modify_Source() {
    if [ "${DISTRO}" = "RHEL" ]; then
        RHEL_Modify_Source
        RHEL_Kubernetes_Source
    elif [ "${DISTRO}" = "Ubuntu" ]; then
        Ubuntu_Modify_Source
        Ubuntu_Kubernetes_Source
    elif [ "${DISTRO}" = "CentOS" ]; then
        CentOS_Modify_Source
        RHEL_Kubernetes_Source
    fi

    # 判断 container runtime 类型
    case $INSTALL_CR in
    docker | containerd)
        if [ "${DISTRO}" = "Ubuntu" ]; then
            Ubuntu_Docker_Source
        else
            RHEL_Docker_Source
        fi
        ;;
    crio)
        if [ "${DISTRO}" = "Ubuntu" ]; then
            Ubuntu_Crio_Source
        else
            RHEL_Crio_Source
        fi
        ;;
    *)
        Red_Echo "不支持的 Container Runtime 类型"
        exit 1
        ;;
    esac

    echo '添加包管理源 done!' >>${install_log}
}

function Check_PowerTools() {
    if ! yum -v repolist all | grep "PowerTools"; then
        Red_Echo "PowerTools repository not found!"
    fi
    repo_id=$(yum repolist all | grep -Ei "PowerTools" | head -n 1 | awk '{print $1}')
}

function Check_Codeready() {
    repo_id=$(yum repolist all | grep -E "CodeReady" | head -n 1 | awk '{print $1}')
    [ -z "${repo_id}" ] && repo_id="ol8_codeready_builder"
}

function CentOS_Dependent() {
    if [ -s /etc/yum.conf ]; then
        \cp /etc/yum.conf /etc/yum.conf.tmp
        sed -i 's:exclude=.*:exclude=:g' /etc/yum.conf
    fi

    Blue_Echo "[+] Yum installing dependent packages..."
    for packages in bash openssh-clients wget rsync yum-utils vim; do yum -y install $packages; done

    yum -y update nss

    if echo "${CentOS_Version}" | grep -Eqi "^8" || echo "${RHEL_Version}" | grep -Eqi "^8" || echo "${Rocky_Version}" | grep -Eqi "^8" || echo "${Alma_Version}" | grep -Eqi "^8" || echo "${Anolis_Version}" | grep -Eqi "^8"; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for c8packages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${c8packages} -y; done
        fi
        dnf install libarchive -y

        dnf install gcc-toolset-10 -y
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
        for cs9packages in oniguruma-devel libzip-devel libtirpc-devel libxcrypt-compat; do dnf --enablerepo=crb install ${cs9packages} -y; done
    fi

    if [ "${DISTRO}" = "Oracle" ] && echo "${Oracle_Version}" | grep -Eqi "^8"; then
        Check_Codeready
        for o8packages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${o8packages} -y; done
        dnf install libarchive -y
    fi

    if echo "${CentOS_Version}" | grep -Eqi "^7" || echo "${RHEL_Version}" | grep -Eqi "^7" || echo "${Aliyun_Version}" | grep -Eqi "^2" || echo "${Alibaba_Version}" | grep -Eqi "^2" || echo "${Oracle_Version}" | grep -Eqi "^7"; then
        if [ "${DISTRO}" = "Oracle" ]; then
            yum -y remove oracle-epel-release
            yum -y install oracle-epel-release
            yum -y --enablerepo=*EPEL* install oniguruma-devel
        else
            yum -y remove epel-release
            yum -y install epel-release
            if [ "${country}" = "CN" ]; then
                sed -e 's!^metalink=!#metalink=!g' \
                    -e 's!^#baseurl=!baseurl=!g' \
                    -e 's!//download\.fedoraproject\.org/pub!//mirrors.aliyun.com!g' \
                    -e 's!//download\.example/pub!//mirrors.aliyun.com!g' \
                    -i /etc/yum.repos.d/epel*.repo
            fi
        fi
        yum -y install oniguruma oniguruma-devel
    fi

    if [ "${DISTRO}" = "Fedora" ] || echo "${CentOS_Version}" | grep -Eqi "^9" || echo "${Alma_Version}" | grep -Eqi "^9" || echo "${Rocky_Version}" | grep -Eqi "^9"; then
        dnf install chkconfig -y
    fi

    if [ "${DISTRO}" = "UOS" ]; then
        Check_PowerTools
        if [ "${repo_id}" != "" ]; then
            echo "Installing packages in PowerTools repository..."
            for uospackages in rpcgen re2c oniguruma-devel; do dnf --enablerepo=${repo_id} install ${uospackages} -y; done
        fi
    fi

    if [ -s /etc/yum.conf.tmp ]; then
        mv -f /etc/yum.conf.tmp /etc/yum.conf
    fi
}

function Deb_Dependent() {
    Blue_Echo "[+] Apt-get installing dependent packages..."
    apt-get update -y
    [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
    apt-get autoremove -y
    apt-get -fy install
    export DEBIAN_FRONTEND=noninteractive
    apt-get --no-install-recommends install -y build-essential gcc g++ make
    for packages in bash openssh-client wget rsync apt-transport-https ca-certificates curl software-properties-common vim; do apt-get --no-install-recommends install -y $packages; done
}

function Check_System() {
    # clear
    printf "Checking system config now......\n"

    SUCCESS="\e[1;32m检测正常\e[0m"
    FAILURE="\e[1;31m检测异常\e[0m"
    UNKNOWN="\e[1;31m未检测到\e[0m"
    UPGRADE="\e[1;31m自动修改\e[0m"

    #检查CPU型号
    CPUNAME=$(awk -F ': ' '/model name/ {print $NF}' /proc/cpuinfo | uniq | sed 's/[ ]\{3\}//g')
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
    [[ $(echo ${MEMSIZE%G*} | awk '{if($0>=4)print $0}') ]] && MEMSIZEACK="$SUCCESS" || MEMSIZEACK="$FAILURE"

    function CHECK_DISK_SIZE() {
        #检查硬盘大小
        DSKSIZE=($(parted -l 2>/dev/null | grep Disk | grep '/dev/' | grep -v mapper | awk '{print $2 $3}'))
        for DS in "${DSKSIZE[@]}"; do
            [[ $(echo ${DSKSIZE%G*} | awk -F':' '{if($2>=50)print $2}') ]] && DSKSIZEACK="$SUCCESS" || DSKSIZEACK="$FAILURE"
            printf "$DSKSIZEACK	硬盘大小:			$DS\n"
        done
    }

    #检查根分区可用大小
    DSKFREE=$(df -h / | awk 'END{print $(NF-2)}')
    [[ $(echo ${DSKFREE%G*} | awk '{if($0>=50)print $0}') ]] && DSKFREEACK="$SUCCESS" || DSKFREEACK="$FAILURE"

    function CHECK_NETWORK_CARD() {
        #获取网卡名
        IFCFGS=($(cat /proc/net/dev | awk '{i++; if(i>2){print $1}}' | sed 's/^[\t]*//g' | sed 's/[:]*$//g' | grep -E -v "lo|.old"))
        $PM -y install ethtool >/dev/null 2>&1
        for IFCFG in ${IFCFGS[@]}; do
            #检查网卡类型,暂时不检测
            ETHTYPE=$(ethtool -i $IFCFG | awk '/driver:/{print $NF}')
            [[ "$ETHTYPE" = "XXXX" ]] && ETHTYPEACK="$SUCCESS" || ETHTYPEACK="$FAILURE"
            ETHTYPEACK="$SUCCESS"

            #检查网卡驱动版本,暂时不检测
            DRIVERS=$(ethtool -i $IFCFG | awk '{if($1=="version:") print $NF}')
            [[ "$DRIVERS" = "XXXX" ]] && DRIVERSACK="$SUCCESS" || DRIVERSACK="$UPGRADE"
            DRIVERSACK="$SUCCESS"

            #检查网卡速率
            ETHRATE=$(ethtool $IFCFG | awk '/Speed:/{print $NF}')
            if [[ "$ETHRATE" =~ ^[0-9]+Mb/s$ ]]; then
                [[ "${ETHRATE/"Mb/s"/}" -ge "1000" ]] && ETHRATEACK="$SUCCESS" || ETHRATEACK="$FAILURE"
            else
                ETHRATEACK="$UNKNOWN"
            fi

            printf "$ETHTYPEACK	${IFCFG}网卡类型:			$ETHTYPE\n"
            printf "$DRIVERSACK	${IFCFG}网卡驱动版本:				$DRIVERS\n"
            printf "$ETHRATEACK	${IFCFG}网卡速率:			$ETHRATE\n"
        done
    }

    #检查服务器生产厂家
    SEROEMS=$(dmidecode | grep -A4 "System Information" | awk -F': ' '/Manufacturer/{print $NF}')
    [[ -n "$SEROEMS" ]] && SEROEMSACK="$SUCCESS" || SEROEMSACK="$UNKNOWN"

    #检查服务器型号
    SERTYPE=$(dmidecode | grep -A4 "System Information" | awk -F': ' '/Product/{print $NF}')
    [[ -n "$SERTYPE" ]] && SERTYPEACK="$SUCCESS" || SERTYPEACK="$UNKNOWN"

    #检查服务器序列号
    SERSNUM=$(dmidecode | grep -A4 "System Information" | awk -F': ' '/Serial Number/{print $NF}')
    [[ -n "$SERSNUM" ]] && SERSNUMACK="$SUCCESS" || SERSNUMACK="$UNKNOWN"

    #检查IP个数
    IPADDRN=$(ip a | grep -v "inet6" | awk '/inet/{print $2}' | awk '{print $1}' |
        egrep -v '^127\.' | awk -F/ '{print $1}' | wc -l)
    [[ $IPADDRN -ge 1 ]] && IPADDRS=($(ip a | grep -v "inet6" |
        awk '/inet/{print $2}' | awk '{print $1}' | egrep -v '^127\.' | awk -F/ '{print $1}'))
    [[ $IPADDRN -ge 1 ]] && IPADDRP=$(echo ${IPADDRS[*]} | sed 's/[ ]/,/g')
    [[ $IPADDRN -ge 1 ]] && IPADDRNACK="$SUCCESS" || IPADDRNACK="$FAILURE"

    #检查操作系统版本
    [[ $(echo "$DISTRO" | grep -E 'CentOS|RHEL|Ubuntu') ]] && OSVERSIACK="$SUCCESS" || OSVERSIACK="$FAILURE"

    #检查操作系统类型
    OSTYPES=$(uname -i)
    [[ $OSTYPES = "x86_64" ]] && OSTYPESACK="$SUCCESS" || OSTYPESACK="$FAILURE"

    #检查系统运行等级
    OSLEVEL=$(runlevel)
    [[ "$OSLEVEL" =~ 3|5 ]] && OSLEVELACK="$SUCCESS" || OSLEVELACK="$FAILURE"

    function CHECK_DISK_SPEED() {
        Twinkle_Echo $(Yellow_Echo "Will check disk speed ......")
        User_Pass
        [ $? -eq 1 ] && return 1
        $PM -y install hdparm >/dev/null 2>&1 # 先安装测试工具
        #检查硬盘读写速率
        DISKHW=($(hdparm -Tt $(fdisk -l | grep -i -A1 device | awk 'END{print $1}') | awk '{if(NR==3||NR==4)print $(NF-1),$NF}'))
        #Timing cached reads
        CACHEHW=$(echo ${DISKHW[*]} | awk '{print $1,$2}')
        [[ $(echo $CACHEHW | awk '{if($1>3000)print $0}') ]] && CACHEHWACK="$SUCCESS" || CACHEHWACK="$FAILURE"
        #Timing buffered disk reads
        BUFFRHW=$(echo ${DISKHW[*]} | awk '{print $3,$4}')
        [[ $(echo $BUFFRHW | awk '{if($1>100)print $0}') ]] && BUFFRHWACK="$SUCCESS" || BUFFRHWACK="$FAILURE"

        printf "$CACHEHWACK	硬盘cache读写速率:			$CACHEHW\n"
        printf "$BUFFRHWACK	硬盘buffer读写速率:			$BUFFRHW\n"
    }

    #检查时区
    OSZONES=$(date +%Z)
    [[ "$OSZONES" = "CST" ]] && OSZONESACK="$SUCCESS" || OSZONESACK="$UPGRADE"

    #检查DNS配置
    $PM -y install bind-utils || $PM -y install bind9-utils
    DNS=($(awk '{if($1=="nameserver") print $2}' /etc/resolv.conf))
    DNSCONF=$(echo ${DNS[*]} | sed 's/[ ]/,/g')
    [[ $(grep "\<nameserver\>" /etc/resolv.conf) ]] && DNSCONFACK="$SUCCESS" || DNSCONFACK="$FAILURE"
    if [[ $(nslookup www.baidu.com | grep -A5 answer | awk '{if($1=="Address:") print $2}') ]]; then
        DNSRESO=($(nslookup www.baidu.com | grep -A5 answer | awk '{if($1=="Address:") print $2}'))
        DNSRESU=$(echo ${DNSRESO[*]} | sed 's/[ ]/,/g')
        DNSRESOACK="$SUCCESS"
    else
        DNSRESU="未知"
        DNSRESOACK="$FAILURE"
    fi

    #检查SElinux状态
    if command -v sestatus >/dev/null 2>&1; then
        SELINUX=$(sestatus | awk -F':' '{if($1=="SELinux status") print $2}' | xargs echo)
        if [[ $SELINUX = disabled ]]; then
            SELINUXACK="$SUCCESS"
        else
            SELINUXACK="$FAILURE"
            sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
        fi
    else
        SELINUX="未知"
        SELINUXACK="$SUCCESS"
    fi
    HOSTNAME=$(hostname)
    if [[ $HOSTNAME != "localhost.localdomain" ]]; then
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
    printf "%35s\e[1;32mUbuntu 默认未安装 SElinux.\e[0m\n"
    printf "===========================================================================\n"
    printf "系统分区情况如下:\n\n"
    df -hPT -xtmpfs
    printf "\n"
    [[ $(df -hPT -xtmpfs | grep -A1 Filesystem | awk 'END{print $1}' | wc -L) -gt 9 ]] && printf "%30s\033[1;32m提示:存在LVM分区\033[0m\n"
    printf "===========================================================================\n"
    sleep 15
}

Make_Install() {
    make -j $(grep 'processor' /proc/cpuinfo | wc -l)
    if [ $? -ne 0 ]; then
        make
    fi
    make install
}

Kill_PM() {
    if ps aux | grep -E "yum|dnf" | grep -qv "grep"; then
        kill -9 $(ps -ef | grep -E "yum|dnf" | grep -v grep | awk '{print $2}')
        if [ -s /var/run/yum.pid ]; then
            rm -f /var/run/yum.pid
        fi
    elif ps aux | grep -E "apt-get|dpkg|apt" | grep -qv "grep"; then
        kill -9 $(ps -ef | grep -E "apt-get|apt|dpkg" | grep -v grep | awk '{print $2}')
        if [[ -s /var/lib/dpkg/lock-frontend || -s /var/lib/dpkg/lock ]]; then
            rm -f /var/lib/dpkg/lock-frontend
            rm -f /var/lib/dpkg/lock
            dpkg --configure -a
        fi
    fi
}

Download_Files() {
    local URL=$1
    local FileName=$2
    if [ -s "${FileName}" ]; then
        echo "${FileName} [found]"
    else
        echo "Notice: ${FileName} not found!!!download now..."
        wget -c --progress=bar:force --prefer-family=IPv4 --no-check-certificate ${URL} -O ${FileName}
    fi
}

Tar_Cd() {
    local FileName=$1
    local DirName=$2
    cd ${SH_DIR}/src
    [[ -d "${DirName}" ]] && rm -rf ${DirName}
    echo "Uncompress ${FileName}..."
    tar zxf ${FileName}
    if [ -n "${DirName}" ]; then
        echo "cd ${DirName}..."
        cd ${DirName}
    fi
}

Tarj_Cd() {
    local FileName=$1
    local DirName=$2
    cd ${SH_DIR}/src
    [[ -d "${DirName}" ]] && rm -rf ${DirName}
    echo "Uncompress ${FileName}..."
    tar jxf ${FileName}
    if [ -n "${DirName}" ]; then
        echo "cd ${DirName}..."
        cd ${DirName}
    fi
}

TarJ_Cd() {
    local FileName=$1
    local DirName=$2
    cd ${SH_DIR}/src
    [[ -d "${DirName}" ]] && rm -rf ${DirName}
    echo "Uncompress ${FileName}..."
    tar Jxf ${FileName}
    if [ -n "${DirName}" ]; then
        echo "cd ${DirName}..."
        cd ${DirName}
    fi
}

Print_Sys_Info() {
    eval echo "${DISTRO} \${${DISTRO}_Version}"
    cat /etc/issue
    cat /etc/*-release
    uname -a
    MemTotal=$(free -m | grep Mem | awk '{print  $2}')
    echo "Memory is: ${MemTotal} MB "
    df -h
    Check_Openssl
    Check_WSL
    Get_Country
    echo "Server Location: ${country}"
}

StartUp() {
    init_name=$1
    echo "Add ${init_name} service at system startup..."
    if [ "${isWSL}" != "y" ] && command -v systemctl >/dev/null 2>&1 && [[ -s /etc/systemd/system/${init_name}.service || -s /lib/systemd/system/${init_name}.service || -s /usr/lib/systemd/system/${init_name}.service ]]; then
        systemctl daemon-reload
        systemctl enable ${init_name}.service
    else
        if [ "$PM" = "yum" ]; then
            chkconfig --add ${init_name}
            chkconfig ${init_name} on
        elif [ "$PM" = "apt" ]; then
            update-rc.d -f ${init_name} defaults
        fi
    fi
}

Remove_StartUp() {
    init_name=$1
    echo "Removing ${init_name} service at system startup..."
    if [ "${isWSL}" != "y" ] && command -v systemctl >/dev/null 2>&1 && [[ -s /etc/systemd/system/${init_name}.service || -s /lib/systemd/system/${init_name}.service || -s /usr/lib/systemd/system/${init_name}.service ]]; then
        systemctl disable ${init_name}.service
    else
        if [ "$PM" = "yum" ]; then
            chkconfig ${init_name} off
            chkconfig --del ${init_name}
        elif [ "$PM" = "apt" ]; then
            update-rc.d -f ${init_name} remove
        fi
    fi
}

Get_Country() {
    if command -v curl >/dev/null 2>&1; then
        country=$(curl -sSk --connect-timeout 30 -m 60 http://ip.vpszt.com/country)
        if [ $? -ne 0 ]; then
            country=$(curl -sSk --connect-timeout 30 -m 60 https://ip.vpser.net/country)
        fi
    else
        country=$(wget --timeout=5 --no-check-certificate -q -O - http://ip.vpszt.com/country)
    fi
}

Check_Mirror() {
    if ! command -v curl >/dev/null 2>&1; then
        if [ "$PM" = "yum" ]; then
            yum install -y curl
        elif [ "$PM" = "apt" ]; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get upgrade
            apt-get install -y curl
        fi
    fi
}

StartOrStop() {
    local action=$1
    local service=$2
    if [ "${isWSL}" = "n" ] && command -v systemctl >/dev/null 2>&1 && [[ -s /etc/systemd/system/${service}.service ]]; then
        systemctl ${action} ${service}.service
    else
        /etc/init.d/${service} ${action}
    fi
}

Check_WSL() {
    if [[ "$(</proc/sys/kernel/osrelease)" == *[Mm]icrosoft* ]]; then
        echo "running on WSL"
        isWSL="y"
    else
        isWSL="n"
    fi
}

Check_Openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        Blue_Echo "[+] Installing openssl..."
        if [ "${PM}" = "yum" ]; then
            yum install -y openssl
        elif [ "${PM}" = "apt" ]; then
            apt-get update -y
            [[ $? -ne 0 ]] && apt-get update --allow-releaseinfo-change -y
            apt-get install -y openssl
        fi
    fi
    openssl version
    if openssl version | grep -Eqi "OpenSSL 3.*"; then
        isOpenSSL3='y'
    fi
}

function Init_Install() {
    Get_Dist_Version
    Check_Mirror
    Set_Timezone
    Disable_Selinux
    Print_Sys_Info
    Check_Hosts
    Check_System
    if [ "$PM" = "yum" ]; then
        CentOS_Dependent
        CentOS_InstallNTP
        # CentOS_RemoveAMP
    elif [ "$PM" = "apt" ]; then
        Deb_Dependent
        Deb_InstallNTP
        Xen_Hwcap_Setting
        # Deb_RemoveAMP
    fi
    Modify_Source
}

function Offline_Init_Install() {
    Get_Dist_Version
    Set_Timezone
    Disable_Selinux
    Ready_Local_Repo
    Check_System
}
