# valve-tools
쿠버네티스 클러스터에 DevOps 툴 체인 설치를 돕는 CUI 도구입니다.
DevOps 팀은 `valve-tools`를 사용하여 쿠버네티스 클러스터에 DevOps 툴 체인을 빠르게 구성할 수 있도록 도움을 줍니다.

Helm 차트를 사용해서 쿠버네티스에 애플리케이션을 구동하는 것은 비교적 간단한 작업입니다. 하지만 DevOps 툴 체인을 구성하고 각 툴이 유기적으로 연동하여 동작하기 위해서는 이를 위해 설정이 최적화되어야 합니다. `valve-tools`는 개별 도구들이 밸브 운영 환경에 최적화되어 동작할 수 있도록 애플리케이션의 설정을 제공합니다. 따라서 DevOps 팀은 valve-tools를 사용하여 큰 노력 없이 DevOps 툴 체인을 구성할 수 있습니다.

밸브는 위키피디아 [DevOps 툴 체인](https://ko.wikipedia.org/wiki/%EB%8D%B0%EB%B8%8C%EC%98%B5%EC%8A%A4)에서 정의하고 있는 DevOps 툴 체인 단계별로 필수적인 툴을 제공합니다.
[DevOps 툴 체인](https://ko.wikipedia.org/wiki/%EB%8D%B0%EB%B8%8C%EC%98%B5%EC%8A%A4)은 다음과 같은 단계로 구성됩니다.
1. 코드 - 코드 개발 및 검토, 버전 관리 도구, 코드 병합
1. 빌드 - 지속적 통합(CI) 도구, 빌드 상태
1. 테스트 - 테스트 및 결과가 성능을 결정
1. 패키지 - 애플리케이션 디플로이 이전 단계
1. 릴리즈 - 변경사항 관리, 릴리스 승인, 릴리스 자동화
1. 구성 - 인프라스트럭처 구성 및 관리, IaC(Infrastructure as Code) 도구
1. 모니터링 - 애플리케이션 성능 모니터링, 최종 사용자 경험.

단계별로 밸브가 제공하는 주요 도구는 다음과 같습니다. 기타 운영을 위한 도구는 표를 간단히 하기 위해서 생략하였습니다.
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

### 설치
`valve-tools`는 현재 별도의 설치 방법을 제공하고 있지 않습니다. 소스 코드를 직접 클론 받고 `valve-tools` 구동을 위한 스크립트를 실행합니다.
```bash
$ git clone https://github.com/opsnow-tools/valve-tools.git
$ cd valve-tools
$ ./run.sh
```
#### 지원 범위
* Support Cloud
  * AWS
* Support OS
  * MacOS
  * Linux (centos, ubuntu ...)

### 실행
도구의 설치는 CUI 화면에서 번호를 선택하는 방식으로 동작하기 때문에 직관적으로 처리할 수 있습니다. 다만 도구들이 설치되는 순서에 따라서 설치 성공 여부가 결정될 수 있습니다.

우선 밸브가 제공하는 전체 도구 목록은 다음과 같습니다.

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

필수 도구의 설치 순서는 다음과 같습니다.
* helm
  * tiller가 설치되어야 이후 helm chart를 통해 도구 설치가 가능해집니다. (helm v3.0 이상에서는 tiller 설치가 필요 없습니다. 현재 valve-tools는 helm v3.0 미만의 버전을 지원합니다.)
* efs-provisioner (efs 사용시)
  * AWS에서 쿠버네티스 클러스터를 구성할 때 가용성 증대를 위해서 복수의 가용 영역을 사용할 수 있습니다. 이때 EBS를 PV 생성에 사용한다면 EBS는 특정 가용 영역에 속한 자원으로 이를 사용하는 파드가 다른 가용 영역에 위치한 노드에서 기동된 경우 해당 스토리지를 마운트할 수 없게 됩니다. EFS는 모든 가용 영역에서 참조할 수 있는 네트워크 스토리지를 제공합니다. EFS를 `StorageClass`로 활용하기 원한다면 efs-provisioner를 설치해야 합니다. 주의. EFS 및 보안 그룹 등은 미리 설정되어 있어야 합니다. `valve-eks` 는 이들 리소스를 기본으로 생성합니다.
* nginx-ingress
  * 외부에서 유입되는 요청을 분기해주기 위한 용도입니다. `valve-tools`, valve DevOps 툴 체인을 통해 배포되는 모든 서비스는 고유 서브 도메인을 가지며 nginx-ingress가 이 서브 도메인으로 유입된 요청을 개별 서비스에 분기해주는 임무를 수행합니다.
* cluster-autoscaler
  * 작업 노드는 오토스케일리이 그룹에 속해 있습니다. 클러스터 오토스케일러는 파드 생성에 필요한 자원이 부족한 경우 노드 수를 늘려주고 노드의 CPU 사용률이 지정된 값보다 낮은 경우 노드 수를 줄입니다.

다음은 모니터링 및 관리를 위해 기본으로 필요한 도구의 설치 순서입니다.
* kube-state-metrics
* metrics-server
* kubernetes-dashboard
  * 쿠버네티스에 자원을 관리하기 위한 콘솔 화면을 제공합니다.
* prometheus
  * 쿠버네티스 메트릭을 수집합니다.
* grafana
  * 쿠버네티스 메트릭을 시각화합니다.

그 외의 도구는 필요할 경우 선택적으로 설치를 진행하시면 됩니다.

### 설정 변경
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

#### 도구별 설치 가이드
밸브가 제공하는 설정을 사용하여 DevOps 툴 체인을 구성할 수 있겠지만 DevOps팀은 원하는 형태로 설정을 변경하기 원할 수 있습니다.
다음 문서는 도구별로 밸브의 기본 설정값을 확인하고 필용한 경우 변경할 수 있는 방법을 소개합니다.
* Network
  * [nginx-ingress](./documents/nginx-ingress.md)
* Kubernetes System
  * [cluster-autoscaler](./documents/cluster-autoscaler.md)
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

## 관련 프로젝트
`valve-tools` 은 다음과 같은 밸브 프로젝트와 연동하여 동작합니다.
* [valve-builder](https://github.com/opsnow-tools/valve-builder)
  * 빌드, 배포 도구가 설치된 도커 이미지를 제공합니다.
* [valve-butler](https://github.com/opsnow-tools/valve-butler)
  * Jenkinsfile에 사용할 groovy script를 제공합니다.
* valve-argotools
  * ArgoCD를 통해 GitOps 방식으로 DevOps 툴 체인을 관리하기 위한 프로젝트입니다. 향후 `valve-tools`를 대체할 수 있습니다.

## 라이센스 정보
TBD