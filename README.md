# valve-tools
쿠버네티스 클러스터에 DevOps 툴 체인 설치를 돕는 CUI 도구입니다.
DevOps 팀은 valve-tools를 사용하여 쿠버네티스 클러스터에 DevOps 툴 체인을 빠르게 구성하고 애플리케이션의 생명주기를 관리할 수 있습니다.

[DevOps 툴 체인](https://ko.wikipedia.org/wiki/%EB%8D%B0%EB%B8%8C%EC%98%B5%EC%8A%A4)은 다음과 같은 단계로 구성됩니다. 각 단계별로 요구 사항을 만족시키지 위한 하나 이상의 도구가 필요합니다.
1. 코드 - 코드 개발 및 검토, 버전 관리 도구, 코드 병합
1. 빌드 - 지속적 통합(CI) 도구, 빌드 상태
1. 테스트 - 테스트 및 결과가 성능을 결정
1. 패키지 - 애플리케이션 디플로이 이전 단계
1. 릴리즈 - 변경사항 관리, 릴리스 승인, 릴리스 자동화
1. 구성 - 인프라스트럭처 구성 및 관리, IaC(Infrastructure as Code) 도구
1. 모니터링 - 애플리케이션 성능 모니터링, 최종 사용자 경험.

## 밸브 DevOps 툴 체인 
괄호로 표기된 도구는 쿠버네티스에 설치되어 동작하지 않지만 연동되어 동작하는 도구 입니다. 여기에 표기된 도구는 툴 체인의 주요 도구만 기술하였습니다.
단계 | 툴 체인
--- | -----
코드 | (Bitbucket)
빌드 | Jenkins
테스트 | Sonarqube
패키지 | Sonatype Nexus, Helm, ChartMuseum, Docker Registry, Docker
릴리즈 | Jenkins, (Kubernetes), ClusterAutoscaler
구성 | (Terraform)
모니터링 | Prometheus, Grafana, Jaeger, Fluentd, (AWS Elasticsearch, Kibana), (OpsNow AlertNow)


## 설치 및 실행
깃을 클론 받고 valve-tools 구동을 위한 스크립트를 실행합니다.
```bash
$ git clone https://github.com/opsnow-tools/valve-tools.git
$ cd valve-tools
$ ./run.sh
```



DevOps 툴 체인은 일반적으로 다음과 같은 요구 사항을 만족시켜야 합니다.
* CI/CD 파이프라인
* 모니터링
* 로깅
* AutoScaling
* 보안 (인증, 인가, 네트워크)
* 대시보드



쿠버네티스를 기업에서 사용하기 위해서는 좀 더 다양한 요구 사항을 만족시켜야 합니다.
* CI/CD 파이프라인
* 모니터링
* 로깅
* AutoScaling
* 보안 (인증, 인가, 네트워크)
* 대시보드
이러한 요구 사항은 쿠버네티스 위에 이를 지원하는 도구를 설치하여 만족 시킬 수 있습니다. valve-tools는 이런 다양한 요구 사항을 만족시킬 수 있는 다양한 툴 설치를 지원합니다.

도구를 설치하기 위한 템플릿은 대부분 [stable helm chart](https://github.com/helm/charts/tree/master/stable)를 사용하지만 일부 차트는 incubator 또는 벤더 제공 helm chart를 사용합니다. 

해당 프로젝트는 [kops-cui](https://github.com/opsnow/kops-cui)의 도구 설치 구현을 분리해서 진행하는 프로젝트입니다. kops 기반 클러스터 외에 모든 쿠버네티스 클러스터에 범용적인 DevOps 툴체인 설치 도구로 사용하기 위해서 입니다.

* Support Cloud
  * AWS
* Support OS
  * MacOS
  * Linux (centos, ubuntu ...)


> <주의 사항><br/>툴은 valve 도구를 통해 만든 쿠버네티스 클러스터에 적합하게 설정되어 있습니다.

## Tools
다음과 같은 툴을 설치할 수 있습니다.
* DevOps Tools
  * jenkins
  * argocd
  * sonarqube
  * sonatype-nexus
  * chartmuseum
  * docker-registry
* Network Tools
  * external-dns
  * nginx-ingress
  * cert-manager
* Kubernetes Operation Tools
  * cluster-autoscaler
  * heapster
  * k8s-spot-termination-handler
  * kube-state-metrics
  * kubernetes-dashboard
  * metrics-server
* Security
  * aws-iam-authenticator
* Monitoring
  * prometheus
  * grafana
  * jaeger
  * datadog
  * newrelic-infrastructure
* Logging
  * fluentd-elasticsearch
* Storage
  * efs-provisioner
* Service Mesh
  * istio

## 사용 방법

### 실행
```bash
$ git clone https://github.com/opsnow-tools/valve-tools
$ ./run.sh
```
### 도구 설치
#### 설정 파일 위치 및 공통 사항
각 도구를 설치하기 위한 helm chart의 입력 설정값은 chart/\<namespace>/\<chartname>.yaml 에 정의되어 있습니다. 

##### 템플릿 설정 변경
chart/\<namespace>/\<chartname>.yaml 파일의 상단에는 매니페스트를 생성하기 위한 몇 가지 조건을 설정할 수 있습니다. 여기에서 차트의 버전, 차트 레포지토리, 인그레스 생성 여부, PVC 사용 여부 등을 명시할 수 있습니다.
```yaml
# chart-repo: stable/jenkins
# chart-version: 0.28.10
# chart-ingress: true
# chart-pvc: jenkins ReadWriteOnce 8Gi
```
##### helm chart 설정 변경
chart/\<namespace>/\<chartname>.yaml 파일은 기본적인 애플리케이션의 속성을 포함하고 있습니다. 해당 값을 변경해서 애플리케이션의 기동 조건을 변경할 수 있습니다.

#### 설치 순서
각 도구는 설치 순서에 따라 다른 형상으로 만들어 질 수 있습니다. 
helm은 K8S 서버에 tiller를 설치해줍니다. 이를 통해서 helm으로 다른 도구를 설치할 수 있습니다. 그러므로 가장 먼저 설치되어야 합니다.
efs-provisioner는 efs 스토리지를 생성하고 이후 생성되는 PV를 EFS에 생성하도록 동작합니다. 만약 EFS를 사용해야하는 어플리케이션이 있다면 반드시 그 어플리케이션 보다 먼저 설치되어야 합니다.
nginx-ingress 는 다양한 서비스의 인그레스 설정을 반영해 라우팅 룰을 결정합니다. 따라서 우선 설치되어야 하는 도구 입니다.

이와 같이 설치 순서는 도구의 정상 동작에 영향을 미칠 수 있기 때문에 도구간의 상호 관계를 이해하고 설치 순서를 결정해야 합니다.

* helm
* efs-provisioner (efs 사용시)
  * EFS를 사용하지 않을 경우 EBS가 기동된 가용 영역(AZ)에 따라서 파드 재기동시 스토리지를 찾지 못하는 이슈가 있을 수 있습니다. 가용 영역을 지정해서 파드를 기동하거나, EFS를 사용해 이슈를 해결할 수 있습니다.
* nginx-ingress
* cluster-autoscaler
* heapster
* kube-state-metrics
* metrics-server
* kubernetes-dashboard
* prometheus
* grafana

#### 도구별 설치 가이드
* Network
  * [nginx-ingress](./documents/nginx-ingress.md)
* Kubernetes System
  * [cluster-autoscaler](./documents/cluster-autoscaler.md)
  * [heapster](./documents/heapster.md)
  * [kube-state-metrics](./documents/kube-state-metrics.md)
  * [kubernetes-dashboard](./documents/kubernetes-dashboard.md)
  * [metrics-server](./documents/metrics-server.md)
  * k8s-spot-termination-handler (EKS Only)
* Authorization
  * guard-server
  * aws-iam-authenticator (EKS Only)
* DevOps
  * jenkins
  * argocd
  * sonarqube
  * sonatype nexus
  * chartmuseum
  * docker-registry
  * [prometheus](./documents/prometheus.md)
  * grafana
  * jaeger
  * datadog
  * newrelic-infrastructure
* Logging
  * fluentd-elasticsearch
* Storage
  * efs-provisioner
* ServiceMesh
  * istio

### 도구 삭제
TBD
