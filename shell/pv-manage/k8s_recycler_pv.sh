#!/usr/bin/env bash
# 1. 使用pod挂载清除数据达到回收目的

#获取脚本所存放目录
cd `dirname $0`
SH_DIR=`pwd`
ME=$0
PARAMETERS=$*
pvs="$PARAMETERS"

# 定义ssh参数
ssh_port="22"
ssh_parameters="-o StrictHostKeyChecking=no -o ConnectTimeout=60"
ssh_command="ssh ${ssh_parameters} -p ${ssh_port}"
scp_command="scp ${ssh_parameters} -P ${ssh_port}"

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
        echo -n "$*" && green_echo "成功"
        return 0
    else
        echo -n "$*" && red_echo "失败"
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

function recycle_pv() {
    if [ -z "$pvs" ]; then
        # pvs=$(kubectl get pv|grep Released|grep -v NAME|awk '{print $1}' )  ## 为了安全性，不提供pv名则不操作
        if [ -z "$pvs" ]; then
            green_echo "No pv need to clear data."
            exit 0
        fi
    fi
    yellow_echo "Clear data pv list"
    echo $pvs|sed 's/ /\n/g'
    user_verify_function
    for pv in ${pvs[@]}; do
        yellow_echo "回收pv【$pv】"
        storageClassName=$(kubectl get pv $pv -ojsonpath={.spec.storageClassName})
        accessModes=$(kubectl get pv $pv -ojsonpath={.spec.accessModes})
        storage=$(kubectl get pv $pv -ojsonpath={.spec.capacity..storage})
        # 创建pvc
        cat <<EOF | kubectl create -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pv-recycler
spec:
  accessModes: $accessModes
  storageClassName: $storageClassName
  resources:
    requests:
      storage: $storage
EOF
        # 创建pod进行回收作业
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pv-recycler
  namespace: default
spec:
  restartPolicy: Never
  volumes:
  - name: vol
    persistentVolumeClaim:
      claimName: pv-recycler
  containers:
  - name: pv-recycler
    image: "busybox:latest"
    command: ["/bin/sh", "-c", "test -e /scrub && rm -rf /scrub/..?* /scrub/.[!.]* /scrub/*  && test -z \"$(ls -A /scrub>/dev/null 2>&1)\" || exit 1"]
    volumeMounts:
    - name: vol
      mountPath: /scrub
EOF
        #  删除pod
        pod_status=$(kubectl get pod pv-recycler -ojsonpath={.status.phase})
        until [ "$pod_status" == "Succeeded" ]; do
            echo -e "Waiting 5s"
            sleep 5
            pod_status=$(kubectl get pod pv-recycler -ojsonpath={.status.phase})
        done
        kubectl delete pod pv-recycler 
        return_echo "回收pv【$pv】"
        [ $? -ne 0 ] && continue
        #  删除pvc
        kubectl delete pvc pv-recycler
        kubectl patch pv -p '{"spec":{"claimRef":{"apiVersion":"","kind":"","name":"","namespace":"","resourceVersion":"","uid":""}}}' \
            $pv
        kubectl get pv $pv -oyaml --export > /tmp/.pv.yaml
        sed '/claimRef/d' -i /tmp/.pv.yaml
        kubectl replace -f /tmp/.pv.yaml
    done
}


recycle_pv
exit 0
