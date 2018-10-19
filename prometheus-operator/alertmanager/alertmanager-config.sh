#!/bin/bash
alertmanager_yaml=`base64 --wrap=0 alertmanager.conf`
default_tmpl=`base64 --wrap=0 alertmanager-templates-default.conf`

cat << EOF > alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-main
  namespace: monitoring
data:
  alertmanager.yaml: ${alertmanager_yaml}
  default.tmpl: ${default_tmpl}
EOF
