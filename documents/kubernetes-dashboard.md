# Kubernetes Dashboard
## Stable chart
https://github.com/helm/charts/tree/master/stable/kubernetes-dashboard
## Values.yaml
[/charts/kube-system/kubernetes-dashboard.yaml](../charts/kube-system/kubernetes-dashboard.yaml)
```yaml
# chart-repo: stable/kubernetes-dashboard
# chart-version: 1.10.1
# chart-ingress: true
# chart-pdb: N 1

## https://github.com/helm/charts/tree/master/stable/kubernetes-dashboard

nameOverride: kubernetes-dashboard

# podAnnotations:
#   cluster-autoscaler.kubernetes.io/safe-to-evict: "true"

image:
  repository: k8s.gcr.io/kubernetes-dashboard-amd64
  tag: v1.10.1

## Enable possibility to skip login
enableSkipLogin: false
## Serve application over HTTP without TLS
enableInsecureLogin: true

service:
  type: SERVICE_TYPE
  externalPort: 9090

#resources:
  #limits:
    #cpu: 100m
    #memory: 100Mi
  #requests:
    #cpu: 100m
    #memory: 100Mi
    
ingress:
  enabled: INGRESS_ENABLED
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  ## Kubernetes Dashboard Ingress hostnames Must be provided if Ingress is enabled
  hosts:
    - INGRESS_DOMAIN
```
## Description
* 이미지와 테그이름을 명시적으로 설정하도록 했습니다.
* 리소스 설정을 주석처리하여 두었습니다. 필요에 따라 사용하면 됩니다.
* enableSkipLogin 설정을 true로 하면 로그인 없이 접속 가능합니다.
* enableInsecureLogin 값을 true로 설정하여 HTTPS 연결 안하도록 설정했습니다.  
HTTPS는 ALB에서 처리하도록 valve-eks에서 설정되어 있기 때문입니다.
## Parameters
* SERVICE_TYPE : 서비스 타입, valve-tools에서 세팅 해줌, ex) ClusterIP
* INGRESS_ENABLED : Ingress 사용 여부, valve-tools에서 세팅 해줌, 기본값 : true
* INGRESS_DOMAIN : Dashboard 접속 도메인, valve-tools에서 세팅 해줌 ex) kubernetes-dashboard-kube-system.dev.opsnow.io
## Challenges
* N/A
