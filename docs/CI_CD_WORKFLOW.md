# CI/CD workflow

## Jenkins pipeline diagram

```text
+----------+   +-------+   +-----+   +------+   +----------+
| Checkout |-->| Build |-->| Tag |-->| Push |-->| API check|
+----------+   +-------+   +-----+   +------+   +-----+----+
                                                        |
+--------+   +--------+   +---------+   +--------+       |
| Verify |<--| Status |<--| Rolling |<--| Apply  |<------+
+--------+   +--------+   +---------+   +--------+
    | failure
    +--------------------------> rollout undo + diagnostics
```

## Trigger and checkout

GitHub emits a push event to `/github-webhook/`. The Jenkins GitHub plugin maps
the repository to a Pipeline job and schedules a build. `checkout scm` checks
out the exact webhook revision; Jenkins records the commit in build metadata.
Protect `main`, require review, and prevent direct force pushes so a webhook
cannot bypass the human control point.

## Build and publish

Docker builds from `application/`, pulls current base metadata, and tags the
result with Jenkins `BUILD_NUMBER`. That immutable identifier supports forensic
mapping from cluster to build logs and source revision. The convenience tag
`latest` is published but never relied on for rollout history.

The credentials-binding plugin exposes the Docker Hub token only during the
login step; `set +x` prevents command echo. Jenkins logs out after publishing.
Build agents are still a sensitive boundary: a malicious build can read agent-
available secrets, so only reviewed trusted code should run with production
credentials. Mature systems separate untrusted PR tests from release agents.

## Deploy and roll out

The baseline manifests are applied before `kubectl set image` and `set env`.
This keeps desired structure versioned while substituting a build-time image
tag. The rolling strategy starts one new pod, waits for readiness, and only then
terminates an old pod. `rollout status` converts an asynchronous Kubernetes
operation into a pipeline success or failure.

An unsuccessful pipeline invokes `rollout undo`. This is a useful safety net,
not a substitute for progressive delivery. Database migrations, incompatible
APIs, and external side effects may not be reversible by changing an image.
Production releases need compatibility planning and, where risk warrants,
canary or blue/green controls.

## GitHub integration checklist

1. Use HTTPS with a trusted certificate in front of Jenkins.
2. Configure the canonical Jenkins URL and proxy headers.
3. Use push events only unless the job needs additional events.
4. Set and validate a high-entropy webhook secret.
5. Check recent-delivery request/response details when a hook fails.
6. Restrict repository credentials and rotate them on schedule.
7. Protect the Jenkinsfile through CODEOWNERS and branch rules.

## Pipeline observability

Retain a bounded number of builds, preserve failed logs, and record build,
commit, image digest, and deployment revision. Useful diagnostics are:

```bash
kubectl -n demo rollout history deployment/flask-app
kubectl -n demo get deployment flask-app -o jsonpath='{.spec.template.spec.containers[0].image}'
docker buildx imagetools inspect demoproject/flask-app:BUILD_NUMBER
```

For stronger immutability, resolve and deploy the registry digest
`repository@sha256:...`; tags can be overwritten even when organizational
policy says they should not be.

