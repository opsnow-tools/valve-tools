# kubernetes-dashboard

## Stable chart
* https://github.com/helm/charts/tree/master/stable/kubernetes-dashboard


## Values.yaml
* ./charts/kube-system/kubernetes-dashboard.yaml
```yaml
# chart-repo: stable/kubernetes-dashboard
# chart-version: 1.4.0
# chart-ingress: true
# chart-pdb: N 1

nameOverride: kubernetes-dashboard

# podAnnotations:
#   cluster-autoscaler.kubernetes.io/safe-to-evict: "true"

enableInsecureLogin: true

service:
  type: SERVICE_TYPE
  externalPort: 9090

ingress:
  enabled: INGRESS_ENABLED
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - INGRESS_DOMAIN
```

### Options
* chart-repo
* chart-version
* chart-ingress
* chart-pdb

### Parameters
* SERVICE_TYPE
* INGRESS_ENABLED
* INGRESS_DOMAIN

## Challenges

## References
