#!/usr/bin/env bash
# 解除pv与pvc绑定关系，使pv状态变成Available用于后续自动分配

#获取脚本所存放目录
cd `dirname $0`
SH_DIR=`pwd`
ME=$0
PARAMETERS=$*
pv="$PARAMETERS"

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

function pathch_pv() {
    if [ -z "$pv" ]; then
        pv=$(kubectl get pv|grep Released|grep -v NAME|awk '{print $1}' )
        if [ -z "$pv" ]; then
            green_echo "No pv need to unbound."
            exit 0
        fi
    fi
    yellow_echo "Clear data for"
    echo $pv|sed 's/ /\n/g'
    user_verify_function
    kubectl patch pv -p '{"spec":{"claimRef":{"apiVersion":"","kind":"","name":"","namespace":"","resourceVersion":"","uid":""}}}' \
        $pv
    kubectl get pv $pv -oyaml> /tmp/.pv.yaml
    sed '/claimRef/d' -i /tmp/.pv.yaml
    kubectl replace -f /tmp/.pv.yaml
}


pathch_pv

exit 0
