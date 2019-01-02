# mysql-servicemonitor - Prometheus Operator with nginx ingress controller 

[mysql-servicemonitor](https://)是什么

## Introduction

This chart bootstraps prometheus servicemonitor on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.6+
- PV provisioner support in the underlying infrastructure

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
$ helm install --name my-release ./mysql-servicemonitor
```

The command deploys ceph-exporter cluster on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

### Uninstall

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```

## Configuration

The following table lists the configurable parameters of the FastDFS-Nginx chart and their default values.

| Parameter                  | Description                         | Default                                |
| -----------------------    | ----------------------------------- | -------------------------------------- |
| `namespaceSelector`        | nginx ingress deploy namespace      | `nginx-ingress`
| `schedulerPort`            | nginx ingress metrics port          | 9913
| `scheme`                   | metrics web scheme                  | `http`
| `prometheusRules`          | prometheusRules                | `{}`                                   |
| `additionalServiceMonitorLabels`| one of prometheus operator label| `release: prometheus-operator`|
| `additionalRulesLabels`    | one of prometheus operator label| `release: prometheus-operator`  |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,


