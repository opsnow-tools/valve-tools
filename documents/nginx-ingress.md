# Nginx Ingress

Nginx ingress 는 stable helm 차트를 사용해서 설치합니다.
https://github.com/helm/charts/tree/master/stable/nginx-ingress


Nginx ingress 설치 옵션은 다음 위치에 있습니다.
./charts/kube-ingress/nginx-ingress.yaml
```yaml
# chart-repo: stable/nginx-ingress
# chart-version: 1.4.0

nameOverride: nginx-ingress

controller:
  # kind: DaemonSet
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 11
    targetCPUUtilizationPercentage: 60
    targetMemoryUtilizationPercentage: 60
  # podAnnotations:
  #   cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
  config:
    # https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/configmap.md
    use-forwarded-headers: "true"
    # max-worker-connections: "1024"
    # worker-processes: "auto"  
    # max-worker-open-files: 0
    # limit-rate: 0
    # limit-rate-after: 0
    # enable-multi-accept true
  service:
    annotations:
      # AWS L7 ELB with SSL Termination
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: ""
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "3600"
      # ExternalDNS Service configuration
      # external-dns.alpha.kubernetes.io/hostname: "demo.opsnow.com."
      # external-dns.alpha.kubernetes.io/ttl: 300
    targetPorts:
      # AWS L7 ELB with SSL Termination
      http: http
      https: http
  stats:
    enabled: true
  metrics:
    enabled: true
    service:
      annotations:
        # Prometheus Metrics
        prometheus.io/scrape: "true"
        prometheus.io/port: "10254"
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

### Options
* chart-repo
* chart-version


## Challenges
* `controller.config` 에서는 Nginx의 기동 옵션을 정의할 수 있습니다. nginx 기동 조건을 바꾸려면 해당 옵션을 검토할 필요가 있습니다. nginx 기동 옵션은 다음 [페이지](https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/configmap.md)에서 확인할 수 있습니다.