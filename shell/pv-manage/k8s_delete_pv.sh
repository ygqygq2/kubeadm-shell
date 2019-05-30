#!/usr/bin/env bash
# rbd类型pv，删除image
# cephfs类型pv，删除ceph auth，删除cephfs目录，删除secret

#获取脚本所存放目录
cd `dirname $0`
SH_DIR=`pwd`
ME=$0
PARAMETERS=$*
pvs="$PARAMETERS"
delete_log="/tmp/delete_pv.log"

# ceph管理节点
ceph_deploy_host="master1"
# ceph池
pool="kube"
cephfs_mount_dir="/data/cephfs"
cephfs_provisioned_info="pv.kubernetes.io/provisioned-by: ceph.com/cephfs"
rbd_provisioned_info="pv.kubernetes.io/provisioned-by: ceph.com/rbd"

# 定义ssh参数
ssh_port="22"
ssh_parameters="-o StrictHostKeyChecking=no -o ConnectTimeout=60"
ssh_command="ssh ${ssh_parameters} -p ${ssh_port}"
scp_command="scp ${ssh_parameters} -P ${ssh_port}"

#定义输出颜色函数
function red_echo () {
#用法:  red_echo "内容"
        local what="$*"
        echo -e "\e[1;31m ${what} \e[0m"
}

function green_echo () {
#用法:  green_echo "内容"
        local what="$*"
        echo -e "\e[1;32m ${what} \e[0m"
}

function yellow_echo () {
#用法:  yellow_echo "内容"
        local what="$*"
        echo -e "\e[1;33m ${what} \e[0m"
}

function blue_echo () {
#用法:  blue_echo "内容"
        local what="$*"
        echo -e "\e[1;34m ${what} \e[0m"
}

function twinkle_echo () {
#用法:  twinkle_echo $(red_echo "内容")  ,此处例子为红色闪烁输出
    local twinkle='\e[05m'
    local what="${twinkle} $*"
    echo -e "${what}"
}

function return_echo () {
    if [ $? -eq 0 ]; then
        echo -n "$(date +%F-%T) $*" && green_echo "成功"
        return 0
    else
        echo -n "$(date +%F-%T) $*" && red_echo "失败"
        return 1
    fi
}

function return_error_exit () {
    [ $? -eq 0 ] && local REVAL="0"
    local what=$*
    if [ "$REVAL" = "0" ];then
            [ ! -z "$what" ] && { echo -n "$*" && green_echo "成功" ; }
    else
            red_echo "$* 失败，脚本退出"
            exit 1
    fi
}

#定义确认函数
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

#定义跳过函数
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

function verify_pv() {
    if [ -z "$pvs" ]; then
        pvs=$(kubectl get pv|grep Released|grep -v NAME|awk '{print $1}' )
        if [ -z "$pvs" ]; then
            green_echo "No pv need to clear data."
            exit 0
        fi
    fi
    yellow_echo "Delete pv list"
    echo $pvs|sed 's/ /\n/g'
    user_verify_function
}

function clear_pv() {
    for pv in ${pvs[@]}; do
        pv_tag=""
        tmp_pv_yaml="/tmp/.${pv}.yaml"
        # 判断pv状态
        pv_status=$(kubectl get pv $pv --template={{.status.phase}})
        if [ "$pv_status" == "Bound" ]; then
            echo "pv 【$(green_echo $pv)】status is $(red_echo $pv_status)"
            continue
        fi

        # 获取pv类型
        kubectl get pv $pv -oyaml > $tmp_pv_yaml 2>&1
        if cat $tmp_pv_yaml|grep "$cephfs_provisioned_info">/dev/null; then
            pv_tag="cephfs"
        elif cat $tmp_pv_yaml|grep "$rbd_provisioned_info">/dev/null; then
            pv_tag="rbd"
        else
            echo "Not supported pv 【$(yellow_echo $pv)】."
            continue
        fi

        case $pv_tag in  
            cephfs)
            # cephfs目录挂载成功才操作
            [ ! -z "$mount_notice" ] && continue
            clear_cephfs_pv $pv
            ;;
            rbd)
            clear_rbd_pv $pv
            ;;
            *)
            continue
        esac

    done
}

function clear_rbd_pv() {
    local pv=$1
    image_name=$(kubectl get pv $pv -ojsonpath={.spec.rbd.image})
    if [ ! -z "$image_name" ]; then
        $ssh_command root@$ceph_deploy_host "rbd remove $pool/$image_name"
        return_echo "rbd remove $pool/$image_name" && kubectl delete pv $pv
    fi
}

function check_cephfs_mount() {
    mount_notice=""
    mountpoint $cephfs_mount_dir > /dev/null 2>&1
    [ $? -ne 0 ] && mount_notice=$(red_echo "$cephfs_mount_dir not mount")
    red_echo "$mount_notice"
}

function clear_cephfs_pv() {
    local pv=$1
    secret_name=$(kubectl get pv $pv --template={{.spec.cephfs.secretRef.name}}) 
    secret_namespace=$(kubectl get pv $pv --template={{.spec.cephfs.secretRef.namespace}}) 
    cephfs_path=$(kubectl get pv $pv --template={{.spec.cephfs.path}})
    # 删除ceph用户
    cephfs_user=$(kubectl get pv $pv --template={{.spec.cephfs.user}})
    if [ ! -z "$cephfs_user" ]; then
        $ssh_command root@$ceph_deploy_host "ceph auth del client.$cephfs_user"
        return_echo "Remove cephfs user 【$cephfs_user】"
        [ $? -ne 0 ] && return 1
        # 删除pv中cephfs目录
        [ -d ${cephfs_mount_dir}${cephfs_path} ] && rm -rf ${cephfs_mount_dir}${cephfs_path}
        return_echo "Remove cephfs directory 【${cephfs_mount_dir}${cephfs_path}】"
        if [ $? -eq 0 ]; then
            kubectl delete pv $pv
            return_echo "Delete pv 【$pv】"
            kubectl delete secret -n $secret_namespace $secret_name
            return_echo "Delete secret 【$secret_namespace/$secret_name】"
        fi        
    else
        yellow_echo "Get 【$pv】 cephfs user error!"
        return 1
    fi
}


check_cephfs_mount
verify_pv
clear_pv|tee -a $delete_log

exit 0
