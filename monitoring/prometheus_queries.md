# Prometheus queries

Use **Prometheus → Graph** or Grafana Explore. Begin with a broad selector, then
add labels such as `namespace="demo"` or `instance="10.20.1.10:9100"`.

| Concern | PromQL |
|---|---|
| Node CPU % | `100 * (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))` |
| Node memory % | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` |
| Disk used % | `100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs\|overlay\|squashfs"} / node_filesystem_size_bytes{fstype!~"tmpfs\|overlay\|squashfs"})` |
| Network receive | `sum by(instance) (rate(node_network_receive_bytes_total{device!="lo"}[5m]))` |
| Network transmit | `sum by(instance) (rate(node_network_transmit_bytes_total{device!="lo"}[5m]))` |
| Running pods | `sum by(namespace) (kube_pod_status_phase{phase="Running"})` |
| Desired deployment replicas | `sum by(namespace,deployment) (kube_deployment_spec_replicas)` |
| Ready deployment replicas | `sum by(namespace,deployment) (kube_deployment_status_replicas_available)` |
| Ready nodes | `sum(kube_node_status_condition{condition="Ready",status="true"})` |
| Namespace count | `count(kube_namespace_created)` |
| Restarts in 1h | `sum by(namespace,pod,container) (increase(kube_pod_container_status_restarts_total[1h]))` |
| Container CPU | `sum by(namespace,pod) (rate(container_cpu_usage_seconds_total{container!="",image!=""}[5m]))` |
| Container memory | `sum by(namespace,pod) (container_memory_working_set_bytes{container!="",image!=""})` |

Check target health with `up == 0`; the result must be empty during normal
operation. In **Status → Targets**, investigate scrape errors before trusting a
dashboard. Metrics availability depends on healthy node-exporter,
kube-state-metrics, kubelet, API server, and operator-managed ServiceMonitors.

