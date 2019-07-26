# valve-tools

쿠버네티스 클러스터에 DevOps 도구 설치를 돕는 CUI 도구 입니다.

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
chart/\<namespace>/\<chartname>.yaml 파일의 상단에는 매니페스트를 생성하기 위한 몇 가지 조건을 설정할 수 있습니다. 여기에서 차트의 버전, 차트 레포지토리, 인rm레스 생성 여부, PVC 사용 여부 등을 명시할 수 있습니다.
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
  * cluster-autoscaler
  * heapster
  * kube-state-metrics
  * kubernetes-dashboard
  * metric-server
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
  * prometheus
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
