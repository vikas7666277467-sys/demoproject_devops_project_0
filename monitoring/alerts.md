# Alerting guide

`platform-alerts.yaml` defines durable Prometheus rules for sustained CPU above
80%, memory above 85%, disk above 90%, node exporter down, and frequent pod
restarts. The `for` interval avoids paging on harmless spikes. Verify with:

```bash
kubectl -n monitoring get prometheusrules
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
curl -fsS http://127.0.0.1:9090/api/v1/rules | jq '.data.groups[].rules[] | .name'
```

Prometheus evaluates rules and sends firing events to Alertmanager.
Alertmanager groups, deduplicates, silences, inhibits, and routes them to email,
Slack, PagerDuty, or another receiver. Grafana-managed alerts are useful when a
rule depends on multiple Grafana data sources or is owned with a dashboard.
Prometheus/Alertmanager rules are preferable for infrastructure alerts because
they continue evaluating when Grafana is unavailable and are portable YAML.

Configure receivers through a secret, not Git. A production route normally
sends `severity=critical` to on-call paging and warnings to a team channel.
Always test a receiver with a temporary, explicitly labeled alert and remove it
after delivery is confirmed.
