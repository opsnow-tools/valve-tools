# ArgoCD
## Stable chart
https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd
## Values.yaml
[/charts/devops/argocd.yaml](../charts/devops/argocd.yaml)
```yaml
# chart-repo: argo/argo-cd
# chart-version: 1.8.3
# chart-ingress: true

## https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd

global:
  image:
    repository: argoproj/argocd
    tag: v1.4.2

## dex-server
dex:
  enabled: true
  image:
    repository: quay.io/dexidp/dex
    tag: v2.14.0
  #resources:
    #limits:
      #cpu: 50m
      #memory: 64Mi
    #requests:
      #cpu: 10m
      #memory: 32Mi

## Redis
redis:
  enabled: true
  image:
    repository: redis
    tag: 5.0.3
  #resources:
    #limits:
      #cpu: 200m
      #memory: 128Mi
    #requests:
      #cpu: 100m
      #memory: 64Mi

## Server
server:
  replicas: 1
  #autoscaling:
    #enabled: false
    #minReplicas: 1
    #maxReplicas: 5
    #targetCPUUtilizationPercentage: 50
    #targetMemoryUtilizationPercentage: 50
  image:
    repository: argoproj/argocd
    tag: v1.4.2  
  ## Additional command line arguments to pass to argocd-server
  ## key: value
  extraArgs:
    insecure: true
  #resources:
    #limits:
      #cpu: 100m
      #memory: 128Mi
    #requests:
      #cpu: 50m
      #memory: 64Mi
  ## Server metrics service configuration
  #metrics:
    #enabled: false
    #service:
      #annotations: {}
      #labels: {}
      #servicePort: 8083
    #serviceMonitor:
      #enabled: false
  ingress:
    enabled: INGRESS_ENABLED
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    ## Argo Ingress.
    ## Hostnames must be provided if Ingress is enabled.
    ## Secrets must be manually created in the namespace
    hosts:
      - INGRESS_DOMAIN
  
  ## ArgoCD config
  ## reference https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/argocd-cm.yaml
  config:
    ## Argo CD's externally facing base URL (optional). Required when configuring SSO
    url: https://INGRESS_DOMAIN
    ## the URL for getting chat help, this will typically be your Slack channel for support
    help.chatUrl: 'https://bespin-valve.slack.com/'
    ## the text for getting chat help, defaults to "Chat now!"
    help.chatText: 'Chat with bespinglobal SRE team!'
    ## Git repositories configure Argo CD with (optional).
    ## This list is updated when configuring/removing repos from the UI/CLI
    ## Note: 'type: helm' field is supported in v1.3+. Use 'helm.repositories' for older versions.
    repositories: |
      - type: helm
        url: https://chartmuseum-devops.BASE_DOMAIN
        name: bespinglobal.com
      ## 테스트를 위한 개인용 github, 공개되어 있기 때문에 secret 설정 필요 없음
      - url: https://github.com/ounju/andyredis
        #passwordSecret:
          ## 시크릿 이름을 지정, 시크릿이 없으면 argocd 화면에서 에러 발생함.
          ## 이 차트에서 생성하는 시크릿(argocd-secret)을 사용하고 configs.secret.extra 항목에 설정함.
          ## 공개된 github 이라도 잘못된 로그인 정보를 설정하면 에러 발생함. 설정 하려면 올바른 로그인 정보를 설정해야함.
          ## 공개된 github 이면 로그인 정보 설정 안해야 함.
          #name: argocd-secret
          #key: github-password
        #usernameSecret:
          #name: argocd-secret
          #key: github-username
        #sshPrivateKeySecret:
          #name: argocd-secret
          #key: github-sshPrivateKey

    ## A dex connector configuration (optional). See SSO configuration documentation:
    ## https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/sso
    ## https://github.com/dexidp/dex/tree/master/Documentation/connectors
    #:GITHUB:dex.config: |
    #:GITHUB:  connectors:
    #:GITHUB:  - type: github
    #:GITHUB:    id: github
    #:GITHUB:    name: GitHub
    #:GITHUB:    config:
    #:GITHUB:      clientID: GITHUB_CLIENT_ID
    #:GITHUB:      clientSecret: GITHUB_CLIENT_SECRET
    #:GITHUB:      orgs:
    #:GITHUB:      - name: GITHUB_ORG

  ## ArgoCD rbac config
  ## reference https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/rbac.md
  rbacConfig:
    policy.default: role:readonly
  #:GITHUB:  policy.csv: |
  #:GITHUB:    p, role:org-admin, applications, *, */*, allow
  #:GITHUB:    p, role:org-admin, repositories, *, *, allow
  #:GITHUB:    p, role:org-admin, projects, *, *, allow
  #:GITHUB:    p, role:org-admin, clusters, *, *, allow
  #:GITHUB:    g, GITHUB_ORG:admin, role:org-admin
  #:GITHUB:    g, GITHUB_ORG:sre-lab, role:org-sre

## Repo Server
repoServer:
  replicas: 1
  #autoscaling:
    #enabled: false
    #minReplicas: 1
    #maxReplicas: 5
    #targetCPUUtilizationPercentage: 50
    #targetMemoryUtilizationPercentage: 50
  image:
    repository: argoproj/argocd
    tag: v1.4.2
  #resources:
    #limits:
      #cpu: 50m
      #memory: 128Mi
    #requests:
      #cpu: 10m
      #memory: 64Mi

## Argo Configs
configs:
  secret:
    createSecret: true
    
    ## Webhook Configs
    #githubSecret: ""
    #gitlabSecret: ""
    #bitbucketServerSecret: ""
    #bitbucketUUÌD: ""
    #gogsSecret: ""

    ## Custom secrets. Useful for injecting SSO secrets into environment variables.
    ## Ref: https://argoproj.github.io/argo-cd/operator-manual/sso/
    ## Note that all values must be non-empty.
    #extra:
      #github-username: "myname"
      #github-password: "mypassword"
      #github-sshPrivateKey: "mysshprivatekey"

    ## Argo expects the password in the secret to be bcrypt hashed. You can create this hash with
    ## `htpasswd -nbBC 10 "" $ARGO_PWD | tr -d ':\n' | sed 's/$2y/$2a/'`
    ## 임시 암호를 "1111"로 설정함. 운영 환경 설치할때는 변경해야 함!!!
    argocdServerAdminPassword: "$2a$10$z6DA5uGyaEdG0fwxn1HLWe.YX4Yj/EZ873qu3xxBjzRk1AEPZx8ZW"
```
## Description
* 이미지와 테그이름을 명시적으로 설정하도록 했습니다.
* 리소스 설정을 주석처리하여 두었습니다. 필요에 따라 사용하면 됩니다.
* Autoscaling 설정을 주석처리하여 두었습니다. 필요에 따라 사용하면 됩니다. 기본설정은 false 입니다.
## Parameters
* GITHUB_ORG : github organization name, ex) opsnow-tools
* GITHUB_CLIENT_ID
* GITHUB_CLIENT_SECRET
## Challenges
### admin 암호 설정
argocdServerAdminPassword 속성에 admin 사용자 암호를 설정합니다.  
기본으로 "1111"을 설정해 두었습니다.  
htpasswd 명령어를 사용해 "1111"에 대한 hash 값을 구해서 설정합니다.  
```bash
htpasswd -nbBC 10 "" 1111 | tr -d ':\n' | sed 's/$2y/$2a/
```
이와 같은 방법으로 암호를 변경하여 설치 바랍니다.  
