# Grafana dashboards

The Helm chart automatically provisions Prometheus as Grafana's default data
source and installs Kubernetes mixin dashboards. The custom dashboard in this
repository is discovered by the Grafana sidecar from its labeled ConfigMap.

To import community dashboards, open **Dashboards → New → Import**, enter an ID,
select the Prometheus data source, inspect every query, and save into a managed
folder. Suggested teaching examples are 1860, 315, 15757, 15759, and 15760.
Community dashboards can change or assume different metric labels; treat the
IDs as discovery aids rather than production-controlled artifacts. Export any
accepted dashboard JSON into source control.

The included `DEMO Project / Cluster Overview` covers cluster health, ready
nodes, running pods, deployments, namespaces, CPU, memory, filesystem, and
network throughput. The installer generates the Grafana administrator password
into a Kubernetes Secret. Production environments should source it from their
approved external secret manager and rotate it on schedule.
