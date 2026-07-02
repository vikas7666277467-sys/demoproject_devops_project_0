# Troubleshooting guide

Use the same loop for every incident: state the symptom, establish scope, check
the most local dependency, read events/logs, change one thing, and verify the
original symptom. Capture timestamps and commands. Do not begin by restarting
everything; that destroys evidence.

## Terraform and EC2

**AMI lookup fails:** confirm the region is enabled and Canonical owner ID is
reachable. Do not remove the owner filter. **Unauthorized operation:** use the
encoded AWS error and CloudTrail to identify the denied API; adjust the caller
role narrowly. **Instance has no software:** inspect cloud-init status and
`/var/log/cloud-init-output.log`. Package repository errors can be temporary or
caused by DNS/egress; retry the idempotent script after correcting the cause.

If a second plan proposes replacement, read the exact force-new attribute.
Never apply a surprise replacement to preserve a teaching session. Back up
state, understand drift, and choose an approved maintenance window.

## kubeadm join failures

From a worker, verify the control-plane private IP and port 6443. Both instances
must carry the shared SG for the self rule. Check time synchronization, token
expiry, and the full CA discovery hash. Generate a fresh command on the control
plane with `sudo kubeadm token create --print-join-command`.

If a failed partial join left state, inspect kubelet logs before cleanup. Only
after understanding the failure, `sudo kubeadm reset` can return that worker to
a pre-join state; it is destructive to node membership and must never run on a
healthy control plane.

## Node NotReady

```bash
kubectl describe node NODE
kubectl -n kube-system get pods -o wide
sudo journalctl -u kubelet --since '20 minutes ago' --no-pager
sudo journalctl -u containerd --since '20 minutes ago' --no-pager
```

Look for CNI not initialized, disk/memory/PID pressure, certificate errors,
container runtime failures, or unreachable API server. Confirm IP forwarding,
loaded modules, swap off, and SystemdCgroup true. Calico pods need node-to-node
networking allowed by the self-referencing SG rule.

## Application failures

**Pending pods:** describe the pod and inspect scheduling events; likely causes
are insufficient CPU/memory, taints, or unavailable nodes. **ImagePullBackOff:**
verify the numbered tag exists, repository visibility, image architecture, and
registry rate limits. **CrashLoopBackOff:** inspect `kubectl logs --previous`.
**Not Ready:** call `/health` from inside the pod and review probe events.

For an unreachable NodePort, trace from the inside out: pod health, Service
selector, EndpointSlices, NodePort listener behavior, worker public IP, security
group rule, and client network. `kubectl -n demo get endpointslices -l
kubernetes.io/service-name=flask-app` must list both ready pod IPs.

## Jenkins failures

**Permission denied on Docker socket:** verify Jenkins is in the docker group
and restart Jenkins after group modification. **Credential not found:** the
credential ID must match the Jenkinsfile exactly and be visible to the job.
**kubectl forbidden:** run `kubectl auth can-i` with the exact Secret-file
kubeconfig. Do not solve RBAC errors by copying cluster-admin credentials.

**Webhook does not trigger:** inspect the GitHub delivery response, Jenkins
canonical URL, plugin logs, proxy/TLS settings, webhook secret, and job trigger.
An HTTP timeout is networking; a 404 is usually URL/proxy; a 403 is usually
authentication, CSRF, or secret validation.

**Rollout times out:** inspect Deployment conditions, ReplicaSets, pods, events,
and image pull status. The post block attempts undo, but verify the previous
ReplicaSet becomes available. Keep the failed Jenkins log for analysis.

## Prometheus and Grafana

**Prometheus Pending:** inspect its PVC and StorageClass. **Target down:** open
the target error, then inspect ServiceMonitor selector, Service endpoints, port
name, TLS/auth settings, and network reachability. **Rule absent:** ensure the
PrometheusRule has the release label expected by the Prometheus selector and
inspect operator logs for rejected configuration.

**Grafana no data:** first run the query in Prometheus, then verify Grafana's
data source, time range, variables, and label assumptions. If Prometheus has no
series, a dashboard change cannot fix the scrape path. Community dashboard IDs
often assume different job labels; adapt queries and commit the resulting JSON.

**Alert firing but not delivered:** inspect Prometheus Alerts, Alertmanager UI,
route label matching, inhibition, silences, receiver credentials, and receiver
logs. Test from the monitoring namespace to separate egress problems from
configuration problems.

## Recovery evidence checklist

Record the UTC start/end time, user impact, affected nodes/pods/builds, relevant
events and logs, the last known good image/build, changes made, verification,
and follow-up action. Rotate any credential exposed during debugging. Convert a
repeated manual fix into reviewed automation or a runbook improvement.
