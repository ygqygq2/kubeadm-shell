#!/usr/bin/env bash
##############################################################
# File Name: setup_ssl.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 15:00:46
# Description:
##############################################################

function install_cfssl() {
    #  安装cfssl
    [ -f /usr/local/sbin/cfssl ] && yellow_echo "No need to install cfssl" && return 0 
    wget https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64 -O cfssl_linux_amd64
    wget https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64 -O cfssljson_linux_amd64
    wget https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl-certinfo_1.6.1_linux_amd64 -O cfssl-certinfo_linux_amd64
    chmod +x cfssl_linux_amd64 cfssljson_linux_amd64 cfssl-certinfo_linux_amd64
    \mv cfssl_linux_amd64 /usr/local/sbin/cfssl
    \mv cfssljson_linux_amd64 /usr/local/sbin/cfssljson
    \mv cfssl-certinfo_linux_amd64 /usr/local/sbin/cfssl-certinfo
    echo '安装cfssl done! '>>${install_log}
}

function generate_cert() {
    # 生成有效期为10年CA证书
    cd /etc/kubernetes
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
  ],
  "ca": {
    "expiry": "876000h"
  }
}
EOF

    cfssl gencert -initca ca-csr.json -config ca-config.json| cfssljson -bare ca - 
    return_error_exit "cfssl生成自定义CA"
    [ -d /etc/kubernetes/pki ] && mv /etc/kubernetes/pki /etc/kubernetes/pki.bak
    mkdir -p /etc/kubernetes/pki/etcd
    rsync -avz ca.pem /etc/kubernetes/pki/etcd/ca.crt
    rsync -avz ca-key.pem /etc/kubernetes/pki/etcd/ca.key
    rsync -avz ca.pem /etc/kubernetes/pki/ca.crt
    rsync -avz ca-key.pem /etc/kubernetes/pki/ca.key

    echo '安装k8s证书 done! '>>${install_log}
}
