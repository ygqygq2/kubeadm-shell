#!/usr/bin/env bash
##############################################################
# File Name: functions/base.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 11:39:00
# Description:
##############################################################

# 定义ssh参数
ssh_port="22"
ssh_parameters="-o StrictHostKeyChecking=no -o ConnectTimeout=60"
ssh_command="ssh ${ssh_parameters} -p ${ssh_port}"
scp_command="scp ${ssh_parameters} -P ${ssh_port}"

#定义输出颜色函数
function Red_Echo() {
    #用法:  Red_Echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;31m ${what} \e[0m"
}

function Green_Echo() {
    #用法:  Green_Echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;32m ${what} \e[0m"
}

function Yellow_Echo() {
    #用法:  Yellow_Echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;33m ${what} \e[0m"
}

function Blue_Echo() {
    #用法:  Blue_Echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;34m ${what} \e[0m"
}

function Twinkle_Echo() {
    #用法:  Twinkle_Echo $(Red_Echo "内容")  ,此处例子为红色闪烁输出
    local twinkle='\e[05m'
    local what="${twinkle} $*"
    echo -e "$(date +%F-%T) ${what}"
}

function Return_Echo() {
    if [ $? -eq 0 ]; then
        echo -n "$* " && Green_Echo "成功"
        return 0
    else
        echo -n "$* " && Red_Echo "失败"
        return 1
    fi
}

function Return_Error_Exit() {
    [ $? -eq 0 ] && local REVAL="0"
    local what=$*
    if [ "$REVAL" = "0" ]; then
        [ ! -z "$what" ] && { echo -n "$* " && Green_Echo "成功"; }
    else
        Red_Echo "$* 失败，脚本退出"
        exit 1
    fi
}

# 定义确认函数
function User_Verify() {
    while true; do
        echo ""
        read -p "是否确认?[Y/N]:" Y
        case $Y in
        [yY] | [yY][eE][sS])
            echo -e "answer:  \\033[20G [ \e[1;32m是\e[0m ] \033[0m"
            break
            ;;
        [nN] | [nN][oO])
            echo -e "answer:  \\033[20G [ \e[1;32m否\e[0m ] \033[0m"
            exit 1
            ;;
        *)
            continue
            ;;
        esac
    done
}

# 定义跳过函数
function User_Pass() {
    while true; do
        echo ""
        read -p "是否确认?[Y/N]:" Y
        case $Y in
        [yY] | [yY][eE][sS])
            echo -e "answer:  \\033[20G [ \e[1;32m是\e[0m ] \033[0m"
            break
            ;;
        [nN] | [nN][oO])
            echo -e "answer:  \\033[20G [ \e[1;32m否\e[0m ] \033[0m"
            return 1
            ;;
        *)
            continue
            ;;
        esac
    done
}

function Init_Arch() {
    ARCH=$(uname -m)
    case $ARCH in
    armv5*) ARCH="armv5" ;;
    armv6*) ARCH="armv6" ;;
    armv7*) ARCH="arm" ;;
    aarch64) ARCH="arm64" ;;
    x86) ARCH="386" ;;
    x86_64) ARCH="amd64" ;;
    i686) ARCH="386" ;;
    i386) ARCH="386" ;;
    esac
}
