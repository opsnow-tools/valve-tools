# Metrics server
[Metrics Server](https://github.com/kubernetes-incubator/metrics-server) is a cluster-wide aggregator of resource usage data.

* kubectl top
* [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)


## Stable chart
* https://github.com/helm/charts/tree/master/stable/metrics-server


## Values.yaml
* ./charts/kube-system/metrics-server.yaml
```yaml
# chart-repo: stable/metrics-server
# chart-version: 2.5.1
# chart-pdb: N 1

nameOverride: metrics-server

# https://github.com/kubernetes-incubator/metrics-server#flags
args:
  # - --logtostderr
  # enable this if you have self-signed certificates
  - --kubelet-insecure-tls
  - --kubelet-preferred-address-types=InternalIP,InternalDNS,ExternalDNS,ExternalIP,Hostname
  # - --source=kubernetes.summary_api:''
  # - --source=kubernetes.summary_api:https://kubernetes.default.svc?kubeletHttps=true&kubeletPort=10250&useServiceAccount=true&insecure=true
  # https://github.com/kubernetes/kubernetes/issues/67702
  # - --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem
  # - --enable-aggregator-routing=true
```

### Options
* chart-repo
* chart-version
* chart-pdb

### Parameters


## Challenges
* metrics-server 적용을 위해서는 기동을 위한 옵션(`args`)을 검토할 필요가 있습니다.
* 현재 설정은 `kubelet-insecure-tls`를 사용하고 있습니다. production에 사용하기 위해서는 인증서를 발급하고 관련 옵션을 적용할 필요가 있습니다.  

## References
* [Kubernetes monitoring architecture](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/monitoring_architecture.md)
  ![](https://github.com/kubernetes/community/raw/master/contributors/design-proposals/instrumentation/monitoring_architecture.png?raw=true)