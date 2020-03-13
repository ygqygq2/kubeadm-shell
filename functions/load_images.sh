#!/usr/bin/env bash
##############################################################
# File Name: load_images.sh
# Version: V1.0
# Author: Chinge_Yang
# Blog: https://ygqygq2.blog.51cto.com
# Created Time : 2020-03-12 18:17:14
# Description:
##############################################################

function load_images () {
    cd $images_dir
    ls *.tar | awk '{print "docker load -i " $0}' | sh
}
