#!/usr/bin/env bash

exit
kubectl patch pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}' \
  $(kubectl get pv|grep -v NAME|awk '{print $1}')
