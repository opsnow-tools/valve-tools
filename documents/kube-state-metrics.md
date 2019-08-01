# kube-state-metrics

## Stable chart
* https://github.com/helm/charts/tree/master/stable/kube-state-metrics


## Values.yamlN
* ./charts/kube-system/kube-state-metrics.yaml
```yaml
# chart-repo: stable/kube-state-metrics
# chart-version: 0.16.0

nameOverride: kube-state-metrics
```
### Options
* chart-repo
* chart-version

## References
* [kubernetes/kube-state-metrics](https:/https://github.com/kubernetes/kube-state-metrics)
  * kube-state-metrics vs. metrics-server
    * The metrics-server is a project that has been inspired by Heapster and is implemented to serve the goals of core metrics pipelines in Kubernetes monitoring architecture.
    * kube-state-metrics is focused on generating completely new metrics from Kubernetes' object state (e.g. metrics based on deployments, replica sets, etc.). 