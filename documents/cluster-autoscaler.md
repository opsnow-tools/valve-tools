# Cluster Autoscaler

Cluster autoscaler 는 stable helm 차트를 사용해서 설치합니다.
https://github.com/helm/charts/tree/master/stable/cluster-autoscaler

다음 서비스와 연계하여 워커 노드의 스케일을 자동으로 조절합니다.
* AWS autoscaling group(ASG)
* Spotinst Elastigroup


Nginx ingress 설치 옵션은 다음 위치에 있습니다.
./charts/kube-system/cluster-autoscaler.yaml
```yaml
# chart-repo: stable/cluster-autoscaler
# chart-version: 0.12.1
# chart-node: master

nameOverride: cluster-autoscaler

# podAnnotations:
#   cluster-autoscaler.kubernetes.io/safe-to-evict: "true"

autoDiscovery:
  enabled: true
  clusterName: CLUSTER_NAME

awsRegion: AWS_REGION

extraArgs:
  v: 4
  stderrthreshold: info
  logtostderr: true
  expander: random
  scale-down-enabled: true
  scale-down-utilization-threshold: 0.75
  skip-nodes-with-local-storage: false
  skip-nodes-with-system-pods: false

# This option is for running the cluster autoscaler on the master node.
#:MASTER:nodeSelector:
#:MASTER:  kubernetes.io/role: master

#:MASTER:tolerations:
#:MASTER:  - effect: NoSchedule
#:MASTER:    key: node-role.kubernetes.io/master

sslCertPath: /etc/ssl/certs/ca-bundle.crt

rbac:
  create: true
  pspEnabled: true
```

### Options
* chart-repo
* chart-version
* chart-ingress
* chart-pdb
* MASTER
  * `kops`로 클러스터 구성할 경우 cluster-autoscaler를 마스터 노드에 운영하기 위한 옵션 입니다.

### Parameters
* CLUSTER_NAME
* AWS_REGION