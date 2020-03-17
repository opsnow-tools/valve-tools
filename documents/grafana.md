# Grafana
## Stable chart
https://github.com/helm/charts/tree/master/stable/grafana
## Values.yaml
[/charts/monitor/grafana.yaml](../charts/monitor/grafana.yaml)
```yaml
# chart-repo: stable/grafana
# chart-version: 5.0.1
# chart-ingress: true
# chart-pvc: grafana ReadWriteOnce 5Gi
# chart-pdb: N 1

## https://github.com/helm/charts/tree/master/stable/grafana

nameOverride: grafana

image:
  repository: grafana/grafana
  tag: 6.6.1

#resources:
  #limits:
    #cpu: 200m
    #memory: 256Mi
  #requests:
    #cpu: 200m
    #memory: 256Mi

adminUser: admin
adminPassword: PASSWORD

# podAnnotations:
#   cluster-autoscaler.kubernetes.io/safe-to-evict: "true"

service:
  type: SERVICE_TYPE

ingress:
  enabled: INGRESS_ENABLED
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - INGRESS_DOMAIN

env:
  GF_SERVER_ROOT_URL: https://INGRESS_DOMAIN
#:G_AUTH:  GF_AUTH_GOOGLE_ENABLED: true
#:G_AUTH:  GF_AUTH_GOOGLE_CLIENT_ID: "G_CLIENT_ID"
#:G_AUTH:  GF_AUTH_GOOGLE_CLIENT_SECRET: "G_CLIENT_SECRET"
#:G_AUTH:  GF_AUTH_GOOGLE_ALLOWED_DOMAINS: "G_ALLOWED_DOMAINS"

# extraSecretMounts:
#   - name: grafana-custom
#     mountPath: /usr/share/grafana/conf/custom.ini
#     secretName: grafana-custom
#     readOnly: true

#:LDAP:grafana.ini:
#:LDAP:  auth.ldap:
#:LDAP:    enabled: true
#:LDAP:    allow_sign_up: true
#:LDAP:    config_file: /etc/grafana/ldap.toml

#:LDAP:ldap:
#:LDAP:  existingSecret: "GRAFANA_LDAP"

persistence:
  enabled: true
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  #:EFS:storageClassName: "efs"
  existingClaim: grafana

## Configure grafana datasources
## ref: http://docs.grafana.org/administration/provisioning/#datasources
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server
        access: proxy
        isDefault: true

## Configure grafana dashboard providers
## ref: http://docs.grafana.org/administration/provisioning/#dashboards
## `path` must be /var/lib/grafana/dashboards/<provider_name>
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default

## Configure grafana dashboard to import
## NOTE: To use dashboards you must also enable/configure dashboardProviders
## ref: https://grafana.com/dashboards
## dashboards per provider, use provider name as key.
dashboards:
  default:
    kube-cluster:
      ## https://grafana.com/dashboards/10512
      gnetId: 10512
      revision: 1
      datasource: Prometheus
    cluster-monitoring-for-kubernetes:
      ## https://grafana.com/grafana/dashboards/10000
      gnetId: 10000
      revision: 1
      datasource: Prometheus
    kubernetes-deployment-statefulset-daemonset-metrics:
      ## https://grafana.com/grafana/dashboards/8588
      gnetId: 8588
      revision: 1
      datasource: Prometheus
    k8s-cluster-summary:
      ## https://grafana.com/grafana/dashboards/8685
      gnetId: 8685
      revision: 1
      datasource: Prometheus
    kubernetes-horizontal-pod-autoscaler:
      ## https://grafana.com/grafana/dashboards/10257
      gnetId: 10257
      revision: 1
      datasource: Prometheus
    kubernetes-app-metrics:
      ## https://grafana.com/grafana/dashboards/1471
      gnetId: 1471
      revision: 1
      datasource: Prometheus
    nginx-ingress:
      ## K8s에서 제공하는 대시보드 가져다 사용함
      ## https://github.com/kubernetes/ingress-nginx/blob/master/deploy/grafana/dashboards/nginx.json
      url: https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/grafana/dashboards/nginx.json
      ## 아래 설정은 K8s에서 제공하는 대시보드 설정을 그라파나 대시보드 사이트에 업로드 해서 사용하는거 같음
      ## https://grafana.com/grafana/dashboards/10516
      #gnetId: 10516
      #revision: 1
      #datasource: Prometheus
    kube-deployment:
      ## https://grafana.com/dashboards/10515
      gnetId: 10515
      revision: 1
      datasource: Prometheus
```
## Description
* 이미지와 테그이름을 명시적으로 설정하도록 했습니다.
* 리소스 설정을 주석처리하여 두었습니다. 필요에 따라 사용하면 됩니다.
* Prometheus 데이터 소스를 미리 설정해 두었습니다.
* Dashboards 8개를 미리 설정해 두었습니다.
  * nginx-ingress
  * kube-cluster
  * kube-deployment
  * cluster-monitoring-for-kubernetes (신규)
  * kubernetes-deployment-statefulset-daemonset-metrics (신규)
  * k8s-cluster-summary (신규)
  * kubernetes-horizontal-pod-autoscaler (신규)
  * kubernetes-app-metrics (신규)
## Parameters
* PASSWORD : 로그인 암호
* G_CLIENT_ID
* G_CLIENT_SECRET
* G_ALLOWED_DOMAINS
* GRAFANA_LDAP
