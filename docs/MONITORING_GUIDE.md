# Monitoring guide

## Components

The kube-prometheus-stack chart combines the Prometheus Operator with curated
Kubernetes monitoring. The operator watches custom resources and generates
runtime configuration. Prometheus scrapes and stores time series. Alertmanager
routes alerts. Grafana visualizes queries. node-exporter exposes host metrics,
and kube-state-metrics exposes Kubernetes object state.

## Installation verification

```bash
helm -n monitoring status kube-prometheus-stack
kubectl -n monitoring get pods -o wide
kubectl -n monitoring get prometheus,alertmanager
kubectl -n monitoring get servicemonitor,podmonitor,prometheusrule
```

Every container should be Ready. A CrashLoopBackOff is not an installation
delay; inspect its previous log and events. A Pending Prometheus pod commonly
means no default StorageClass can satisfy its PVC. Choose and document a
StorageClass appropriate to the environment rather than silently removing
persistence.

## Four golden signals

- Latency: instrument request duration in the application before alerting on it.
- Traffic: measure request rate at an ingress, service mesh, or application.
- Errors: use HTTP status counters and failed workload state.
- Saturation: CPU, memory, disk, connection pools, and scheduler constraints.

The current Flask app exposes health, not application metrics. Platform metrics
are complete for this lab; production application SLOs require a Prometheus
client, request counters/histograms, a `/metrics` endpoint, and ServiceMonitor.

## PromQL method

Start with a metric name, inspect its labels, narrow the selector, choose a
range suitable for `rate` or `increase`, aggregate only the labels needed by the
question, and set the correct Grafana unit. Avoid high-cardinality labels such
as request IDs. Test queries in Prometheus before embedding them in dashboards
or alerts. The catalog in `monitoring/prometheus_queries.md` covers nodes,
containers, pods, deployments, and namespaces.

## Dashboard operation

Dashboards answer a question; they should not be a wall of unrelated graphs.
The included overview starts with health counts and then shows resource trends.
Use six-hour and 24-hour windows for incident orientation, then zoom in. Add
annotations for deployments so resource changes align with releases. Store
approved JSON in Git and review it like code.

## Alert quality

An alert must be actionable, owned, and tested. Thresholds include a `for`
duration to suppress transient noise. Each annotation names the affected
resource and suggests urgency. Route warning and critical severities
differently. Pair paging alerts with a runbook URL in a real environment.

CPU and memory percentages signal saturation but need workload context. Disk
alerts must exclude pseudo filesystems. A node-down alert based on exporter
reachability can also mean a scrape-network failure. A pod restart alert should
be tuned for applications whose restart behavior is understood.

## Capacity and retention

Fifteen days and 20 GiB are teaching defaults, not universal sizing. Measure
samples ingested per second, bytes per sample, series cardinality, query load,
and growth. Set retention below available storage capacity with headroom.
Monitor Prometheus itself. For durable multi-cluster history, evaluate remote
write and a long-term metrics platform.

## Backup and change management

Dashboard and rule definitions already live in Git. Back up persistent volumes
only with a storage-aware, tested method. Before chart upgrades, read upstream
release notes and CRD changes, render the diff in a nonproduction cluster, and
retain the prior values/chart version. Never assume `helm rollback` reverses a
CRD schema migration.

