# Heapster

## Stable chart
* https://github.com/helm/charts/tree/master/stable/heapster


## Values.yaml
* ./charts/kube-system/heapster.yaml
```yaml
# chart-repo: stable/heapster
# chart-version: 0.3.2
# chart-pdb: N 1

nameOverride: heapster
```

### Options
* chart-repo
* chart-version
* chart-pdb

## References
* https://arisu1000.tistory.com/27854
  * 1.11 버전에서 deprecated 
  * 1.13 버전에서 완전히 제거될 예정 
  * metrics-server가 이를 대체
  * cpu, memory 등의 사용량 정보를 보여 줌, 대시보드와 연동에서 보여주기 위한 용도