# Prometheus

## Stable chart
* https://github.com/helm/charts/tree/master/stable/prometheus


## Values.yaml
* ./charts/monitor/promethus.yaml
```yaml
# chart-repo: stable/prometheus
# chart-version: 8.9.1
# chart-ingress: false
# chart-pvc: prometheus-server ReadWriteOnce 8Gi
# chart-pvc: prometheus-alertmanager ReadWriteOnce 2Gi

nameOverride: prometheus

server:
  #:ING:service:
  #:ING:  type: SERVICE_TYPE
  #:ING:ingress:
  #:ING:  enabled: INGRESS_ENABLED
  #:ING:  annotations:
  #:ING:    kubernetes.io/ingress.class: nginx
  #:ING:    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  #:ING:  hosts:
  #:ING:    - INGRESS_DOMAIN
  persistentVolume:
    enabled: true
    accessModes:
      - ReadWriteOnce
    size: 8Gi
    #:EFS:storageClass: "efs"
    existingClaim: prometheus-server

alertmanager:
  #:ING:service:
  #:ING:  type: SERVICE_TYPE
  #:ING:ingress:
  #:ING:  enabled: INGRESS_ENABLED
  #:ING:  annotations:
  #:ING:    kubernetes.io/ingress.class: nginx
  #:ING:    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  #:ING:  hosts:
  #:ING:    - alertmanager-INGRESS_DOMAIN
  persistentVolume:
    enabled: true
    accessModes:
      - ReadWriteOnce
    size: 2Gi
    #:EFS:storageClass: "efs"
    existingClaim: prometheus-alertmanager

kubeStateMetrics:
  ## If false, kube-state-metrics will not be installed
  ##
  enabled: KUBE_STATE_METRICS


serverFiles:
  ## Alerts configuration
  ## Ref: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
  alerts:
    groups:
      - name: InstanceCountChanged
        rules:
          - alert: InstanceCountChanged
            expr: count (kube_node_labels{node=~"^.*$"}) - count (kube_node_labels{node=~"^.*$"} offset 2m) != 0
            labels:
              severity: Warning
              cluster: CLUSTER_NAME
            annotations:
              summary: 'Instance Count Changed'
              description: 'The number of instances changed. (delta: {{ $value }})'
      - name: InstanceDown
        rules:
          - alert: InstanceDown
            expr: up{job="kubernetes-nodes"} == 0
            labels:
              severity: Warning
              cluster: CLUSTER_NAME
            annotations:
              summary: 'Instance Down'
              description: 'The instance({{ $labels.instance }}) is down.'
      - name: HighCpuUsage
        rules:
          - alert: HighCpuUsage
            expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{job="kubernetes-service-endpoints",mode="idle"}[5m])) * 100) > 70
            for: 5m
            labels:
              severity: Warning
              cluster: CLUSTER_NAME
            annotations:
              summary: 'High CPU Usage(> 70%)'
              description: 'The CPU usage of the instance({{ $labels.instance }}) has exceeded 70 percent for more than 5 minutes.'
      - name: HighMemoryUsage
        rules:
          - alert: HighMemoryUsage
            expr: (node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes) / node_memory_MemTotal_bytes * 100 > 90
            for: 5m
            labels:
              severity: Warning
              cluster: CLUSTER_NAME
            annotations:
              summary: 'High Memory Usage(> 90%)'
              description: 'The memory usage of the instance({{ $labels.instance }}) has exceeds 90 percent for more than 5 minutes.'

      - name: PodCrashingLooping
        rules:
          - alert: PodCrashingLooping
            expr: round(increase(kube_pod_container_status_restarts_total[30m])) > 0
            for: 5m
            labels:
              severity: Critical
              cluster: CLUSTER_NAME
            annotations:
              summary: "Pod Crash Looping(> 30m)"
              description: 'Namespace : {{ $labels.namespace }} Pod : {{ $labels.pod }} -- crash {{ $value }} times'

      - name: KubeNodeNotReady
        rules:
          - alert: KubeNodeNotReady
            expr: kube_node_status_condition{job="kubernetes-service-endpoints",condition="Ready",status="true"} == 0
            for: 5m
            labels:
              severity: Critical
              cluster: CLUSTER_NAME
            annotations:
              summary: "Kube Node Fail :  {{ $labels.condition }}"
              description: "Node {{ $labels.node }} is failed. Check node!!"

      - name: AvgResponseTime
        rules:
          - alert: AvgResponseTime
            expr: (sum(rate(nginx_ingress_controller_response_duration_seconds_sum[5m])) by (host) !=0) / (sum(rate(nginx_ingress_controller_response_duration_seconds_count[5m])) by (host) !=0) > 5
            for: 5m
            labels:
              severity: Warning
              cluster: CLUSTER_NAME
            annotations:
              summary: "Average Response Time(> 5s)"
              description: "{{ $labels.host }}'s Average Response Time is over 5sec"

      - name: HPAMaxUsage
        rules:
          - alert: HPAMaxUsage
            expr: (kube_hpa_status_current_replicas ) / (kube_hpa_spec_max_replicas != 1) < 1
            for: 5m
            labels:
              severity: Warning
              cluster: CLUSTER_NAME
            annotations:
              summary: "HPA Max Usage"
              description: "{{ $labels.hpa }} is using HPA Max."

alertmanagerFiles:
  alertmanager.yml:
    global:
      slack_api_url: 'https://hooks.slack.com/services/SLACK_TOKEN'

    receivers:
      - name: default-receiver
        slack_configs:
          - channel: '#alerts'
            send_resolved: true
            username: '{{ template "slack.default.username" . }}'
            color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
            title: '{{ template "slack.default.title" . }}'
            title_link: '{{ template "slack.default.titlelink" . }}'
            pretext: '{{ .CommonAnnotations.summary }}'
            text: |-
              {{ range .Alerts }}
                *Cluster:* {{ .Labels.cluster }}
                *Alert:* {{ .Annotations.summary }} - `{{ .Labels.severity }}`
                *Description:* {{ .Annotations.description }}
                *Details:*
                {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
                {{ end }}
              {{ end }}
            fallback: '{{ template "slack.default.fallback" . }}'
            icon_emoji: '{{ template "slack.default.iconemoji" . }}'
            icon_url: '{{ template "slack.default.iconurl" }}'

    route:
      group_wait: 10s
      group_interval: 1m
      receiver: default-receiver
      repeat_interval: 8h

```

### Options
* chart-repo
* chart-version
* chart-ingress
* chart-pvc

### Parameters
* KUBE_STATE_METRICS
* CLUSTER_NAME
* SLACK_TOKEN

## Challenges
* prometheus alert rule 추가 및 검증
  `prometheus`는 쿠버네티스 클러스터의 성능 메트릭을 수집뿐만아니라 alert rule 설정을 통해 임계치에 도달했을 때 알람을 발생시킵니다. 따라서, 운영 환경에 맞게 알람 발생 조건을 수정할 필요가 있습니다. alert rule 추가나 수정이 필요하다면 `serverFiles.alert` 부분을 수정하세요.

  * 현재 정의된 alert rule
    * InstanceCountChanged
    * InstanceDown
    * HighCpuUsage
    * HighMemoryUsage
    * PodCrashingLooping
    * KubeNodeNotReady
    * AvgResponseTime
    * HPAMaxUsage
* alertmanager receiver 설정 변경
  `receiver`는 프로메테우스가 실시간 데이터 확인을 통해 발생하는 alert을 수신할 대상과 포맷을 결정합니다. 현재는 슬랙으로 alert을 전송하도록 설정되어 있습니다. 다른 수신 수단이 필요하면 `alertmanagerFiles.alertmanager.yml.receivers` 부분을 수정하세요.
