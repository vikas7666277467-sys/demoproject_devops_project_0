# Part 5 - Building and Containerizing the Python Flask Application

In this section, we will develop a simple Python Flask web application, test it locally, containerize it using Docker, and publish the Docker image to Docker Hub.

This application will later be deployed to the Kubernetes cluster using the Jenkins CI/CD Pipeline.

---

# Learning Objectives

After completing this section, you will be able to:

- Create a Python Flask application
- Understand Flask project structure
- Install Python dependencies
- Test the application locally
- Create a Dockerfile
- Build a Docker image
- Push the image to Docker Hub
- Verify the Docker image
- Prepare the application for Kubernetes deployment

---

# Application Architecture

```
                    Browser
                       │
                       ▼
                Flask Application
                       │
              Python Flask Server
                       │
                 Docker Container
                       │
                Docker Image
                       │
                  Docker Hub
                       │
                  Kubernetes
```

---

# Project Structure

Inside your GitHub repository create the following structure.

```text
demoproject_devops_project2/

application/

├── app.py
├── requirements.txt
├── Dockerfile
├── .dockerignore
├── templates/
│     └── index.html
└── static/
```

---

# Step 1 - Create the Application Directory

```bash
mkdir application

cd application
```

---

# Step 2 - Install Python

Amazon Linux

```bash
sudo dnf install python3 python3-pip -y
```

Verify

```bash
python3 --version

pip3 --version
```

Expected

```text
Python 3.x.x

pip xx.x
```

---

# Step 3 - Create app.py

Create the application.

```bash
vi app.py
```

Paste the following code.

```python
from flask import Flask
from flask import render_template
from datetime import datetime
import socket
import os

app = Flask(__name__)

VERSION = "Version 1.0"

@app.route("/")
def home():

    return render_template(
        "index.html",
        hostname=socket.gethostname(),
        version=VERSION,
        current_time=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    )

@app.route("/health")
def health():

    return {
        "status":"UP"
    }

@app.route("/version")
def version():

    return {
        "application":"DevOps Demo Project",
        "version":VERSION
    }

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000
    )
```

Save the file.

---

# Application Endpoints

| URL | Purpose |
|------|----------|
| / | Home Page |
| /health | Health Check |
| /version | Version Information |

---

# Step 4 - Create Templates Directory

```bash
mkdir templates
```

---

# Step 5 - Create index.html

```bash
vi templates/index.html
```

Paste the following HTML.

```html
<!DOCTYPE html>

<html>

<head>

<title>DevOps Demo Project</title>

<style>

body{

font-family:Arial;

background:#f5f5f5;

text-align:center;

margin-top:100px;

}

.container{

background:white;

padding:40px;

border-radius:10px;

width:700px;

margin:auto;

box-shadow:0 0 15px gray;

}

h1{

color:#1565C0;

}

h2{

color:green;

}

</style>

</head>

<body>

<div class="container">

<h1>Welcome to DEMO Project</h1>

<h2>Running on Kubernetes</h2>

<p>{{ version }}</p>

<p>Hostname :</p>

<b>{{ hostname }}</b>

<br><br>

<p>Current Time</p>

<b>{{ current_time }}</b>

</div>

</body>

</html>
```

Save the file.

---

# Step 6 - Create requirements.txt

```bash
vi requirements.txt
```

Add

```text
Flask==3.0.3
gunicorn==22.0.0
```

---

# Step 7 - Create .dockerignore

```bash
vi .dockerignore
```

```text
.git

.gitignore

README.md

__pycache__

*.pyc

*.pyo

*.swp
```

---

# Step 8 - Create Dockerfile

```bash
vi Dockerfile
```

Paste

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python","app.py"]
```

---

# Dockerfile Explanation

| Instruction | Purpose |
|------------|----------|
| FROM | Base Image |
| WORKDIR | Working Directory |
| COPY | Copy Files |
| RUN | Install Packages |
| EXPOSE | Application Port |
| CMD | Start Flask |

---

# Step 9 - Install Dependencies

```bash
pip3 install -r requirements.txt
```

---

# Step 10 - Run the Application

```bash
python3 app.py
```

Expected

```text
Running on

http://0.0.0.0:5000
```

---

# Step 11 - Verify the Application

Open

```
http://localhost:5000
```

You should see

```
Welcome to DEMO Project

Running on Kubernetes

Version 1.0
```

---

# Step 12 - Test the Health Endpoint

```bash
curl http://localhost:5000/health
```

Expected

```json
{
  "status":"UP"
}
```

---

# Step 13 - Test the Version Endpoint

```bash
curl http://localhost:5000/version
```

Expected

```json
{
    "application":"DevOps Demo Project",
    "version":"Version 1.0"
}
```

---

# Step 14 - Build the Docker Image

```bash
docker build -t demoproject/flask-app:1 .
```

---

# Step 15 - Verify the Docker Image

```bash
docker images
```

Expected

```text
demoproject/flask-app

1
```

---

# Step 16 - Run the Docker Container

```bash
docker run -d \
--name flask-app \
-p 5000:5000 \
demoproject/flask-app:1
```

---

# Step 17 - Verify Running Containers

```bash
docker ps
```

Expected

```text
CONTAINER ID

IMAGE

STATUS

PORTS
```

---

# Step 18 - Access the Application

Open

```
http://localhost:5000
```

You should see the welcome page.

---

# Step 19 - View Container Logs

```bash
docker logs flask-app
```

---

# Step 20 - Stop the Container

```bash
docker stop flask-app
```

---

# Step 21 - Remove the Container

```bash
docker rm flask-app
```

---

# Step 22 - Login to Docker Hub

```bash
docker login
```

Enter

- Username
- Password (or Access Token)

Expected

```text
Login Succeeded
```

---

# Step 23 - Tag the Image

```bash
docker tag demoproject/flask-app:1 \
demoproject/flask-app:latest
```

---

# Step 24 - Push to Docker Hub

Push versioned image.

```bash
docker push demoproject/flask-app:1
```

Push latest image.

```bash
docker push demoproject/flask-app:latest
```

---

# Step 25 - Verify Docker Hub

Open Docker Hub.

Verify the repository.

```
demoproject/flask-app
```

Expected Tags

```
1

latest
```

---

# Verification Checklist

Verify the following:

- Python Installed
- Flask Installed
- Application Running
- Home Page Working
- Health Endpoint Working
- Version Endpoint Working
- Docker Image Built
- Docker Container Running
- Docker Image Pushed
- Docker Hub Repository Updated

---

# Common Troubleshooting

## Python Command Not Found

```bash
python3 --version
```

Install Python if required.

---

## Flask Module Not Found

```bash
pip3 install -r requirements.txt
```

---

## Port 5000 Already in Use

Check.

```bash
sudo ss -tulpn | grep 5000
```

Stop the existing process.

---

## Docker Build Failed

Verify

- Dockerfile exists
- requirements.txt exists
- Docker service is running

---

## Docker Push Access Denied

Verify

```bash
docker login
```

Ensure the repository exists and you have permission to push.

---

# Best Practices

- Keep application code separate from infrastructure code.
- Pin dependency versions in `requirements.txt`.
- Use a `.dockerignore` file to reduce image size.
- Tag images with immutable version numbers and `latest` only for convenience.
- Test the application locally before pushing images.
- Store Docker Hub credentials securely (for example, in Jenkins Credentials).

---

# Learning Outcomes

After completing this section, you have successfully:

- Built a Python Flask application
- Created a responsive HTML interface
- Implemented health and version endpoints
- Containerized the application using Docker
- Tested the container locally
- Published the Docker image to Docker Hub
- Prepared the application for Kubernetes deployment

---

# Next Section we will deploy the Flask application to Kubernetes by creating:

- namespace.yaml
- deployment.yaml
- service.yaml

We will also configure:

- Replica Count
- Rolling Update Strategy
- Resource Requests
- Resource Limits
- Liveness Probe
- Readiness Probe
- NodePort Service

Finally, we will verify that the application is accessible from the Kubernetes cluster.


# Part 5B-1 - Deploying the Flask Application to Kubernetes

In this section, we will deploy the Dockerized Flask application to the Kubernetes cluster created using **kubeadm**.

The deployment will use Kubernetes best practices including:

- Namespace
- Deployment
- ReplicaSets
- Rolling Updates
- Labels & Selectors
- Resource Requests
- Resource Limits
- Liveness Probe
- Readiness Probe
- NodePort Service

By the end of this section, the Flask application will be ready to run on the Kubernetes cluster.

---

# Kubernetes Deployment Architecture

```text
                         Internet
                             │
                             ▼
                     Worker Node IP
                             │
                      NodePort Service
                     Port 30080 (Example)
                             │
                             ▼
                      Kubernetes Service
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
        Flask Pod 1                  Flask Pod 2
              │                             │
              └──────────────┬──────────────┘
                             ▼
                        Deployment
                             │
                             ▼
                        ReplicaSet
                             │
                             ▼
                          Namespace
```

---

# Kubernetes Directory Structure

Inside the project repository create the following directory.

```text
kubernetes/

├── namespace.yaml
├── deployment.yaml
└── service.yaml
```

---

# Step 1 - Create Kubernetes Directory

```bash
mkdir kubernetes

cd kubernetes
```

---

# Step 2 - Create Namespace

Create the namespace manifest.

```bash
vi namespace.yaml
```

Paste the following content.

```yaml
apiVersion: v1
kind: Namespace

metadata:
  name: demo
```

Save the file.

---

# Namespace Explanation

| Field | Description |
|--------|-------------|
| apiVersion | Kubernetes API Version |
| kind | Resource Type |
| metadata | Object Information |
| name | Namespace Name |

---

# Step 3 - Create Deployment Manifest

```bash
vi deployment.yaml
```

Paste the following manifest.

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:
  name: flask-deployment
  namespace: demo

spec:
  replicas: 2

  strategy:
    type: RollingUpdate

    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  selector:
    matchLabels:
      app: flask

  template:

    metadata:

      labels:
        app: flask

    spec:

      containers:

      - name: flask

        image: demoproject/flask-app:latest

        imagePullPolicy: Always

        ports:

        - containerPort: 5000

        resources:

          requests:
            cpu: "100m"
            memory: "128Mi"

          limits:
            cpu: "500m"
            memory: "512Mi"

        livenessProbe:

          httpGet:

            path: /health

            port: 5000

          initialDelaySeconds: 30

          periodSeconds: 10

        readinessProbe:

          httpGet:

            path: /health

            port: 5000

          initialDelaySeconds: 10

          periodSeconds: 5
```

Save the file.

---

# Deployment Overview

This Deployment creates:

- 2 Flask Pods
- 1 ReplicaSet
- Rolling Updates
- Self-Healing
- Health Monitoring

---

# Deployment Manifest Explanation

## apiVersion

```yaml
apiVersion: apps/v1
```

Specifies the Kubernetes Deployment API.

---

## Kind

```yaml
kind: Deployment
```

Creates a Deployment object.

---

## Metadata

```yaml
metadata:
  name: flask-deployment
```

Deployment name.

---

## Namespace

```yaml
namespace: demo
```

Deploys the application into the **demo** namespace.

---

## Replicas

```yaml
replicas: 2
```

Two application Pods will always be running.

If one Pod fails, Kubernetes automatically creates another.

---

## Rolling Update Strategy

```yaml
strategy:
  type: RollingUpdate
```

Updates Pods one at a time.

Benefits

- Zero Downtime
- No Service Interruption
- Safe Deployment

---

## Labels

```yaml
labels:

  app: flask
```

Labels identify the Pods.

---

## Selector

```yaml
selector:

  matchLabels:

    app: flask
```

Connects the Deployment to its Pods.

---

## Container Name

```yaml
containers:

- name: flask
```

Creates one container inside each Pod.

---

## Docker Image

```yaml
image: demoproject/flask-app:latest
```

Image downloaded from Docker Hub.

Later, Jenkins will update this image automatically.

Example

```
demoproject/flask-app:21
```

---

## Image Pull Policy

```yaml
imagePullPolicy: Always
```

Always downloads the newest image.

Recommended for CI/CD labs.

---

## Container Port

```yaml
containerPort: 5000
```

Flask listens on Port **5000**.

---

# Resource Requests

```yaml
requests:

  cpu: 100m

  memory: 128Mi
```

Guaranteed resources.

---

# Resource Limits

```yaml
limits:

  cpu: 500m

  memory: 512Mi
```

Maximum resources.

Prevents one Pod from consuming all cluster resources.

---

# Liveness Probe

```yaml
livenessProbe:
```

Checks whether the application is alive.

If the probe fails repeatedly,

Kubernetes automatically restarts the container.

---

Health Check

```
/health
```

---

# Readiness Probe

```yaml
readinessProbe:
```

Checks whether the application is ready to receive traffic.

If the probe fails,

the Pod is removed from the Service until it becomes healthy again.

---

# Step 4 - Create Service Manifest

```bash
vi service.yaml
```

Paste the following.

```yaml
apiVersion: v1

kind: Service

metadata:

  name: flask-service

  namespace: demo

spec:

  type: NodePort

  selector:

    app: flask

  ports:

  - protocol: TCP

    port: 80

    targetPort: 5000

    nodePort: 30080
```

Save the file.

---

# Service Overview

This Service exposes the Flask application outside the Kubernetes cluster.

Users can access the application using:

```
http://Worker-IP:30080
```

---

# Service Explanation

## Service Type

```yaml
type: NodePort
```

Exposes the application on every Kubernetes node.

---

## Target Port

```yaml
targetPort: 5000
```

Traffic reaches the Flask container.

---

## Service Port

```yaml
port: 80
```

Internal Service Port.

---

## NodePort

```yaml
nodePort: 30080
```

External access port.

---

# Labels and Selectors

Pods

```yaml
labels:

  app: flask
```

Service

```yaml
selector:

  app: flask
```

The Service forwards traffic only to Pods with this label.

---

# Deployment Strategy

The application uses:

```
Rolling Update
```

Configuration

```yaml
maxSurge: 1

maxUnavailable: 0
```

Meaning

- One additional Pod may be created during an update.
- Existing Pods remain available until replacements are ready.
- Ensures zero downtime during deployments.

---

# Kubernetes Resources Created

| Resource | Quantity |
|-----------|----------|
| Namespace | 1 |
| Deployment | 1 |
| ReplicaSet | 1 |
| Pods | 2 |
| Service | 1 |

---

# Verification Checklist

Before deploying the application, verify:

- `namespace.yaml` created
- `deployment.yaml` created
- `service.yaml` created
- Image name matches the Docker Hub repository
- Replica count is set to **2**
- Rolling Update strategy configured
- Liveness Probe configured
- Readiness Probe configured
- Resource Requests configured
- Resource Limits configured
- NodePort configured

---

# Common Troubleshooting

## Invalid YAML

Validate the syntax.

```bash
kubectl apply --dry-run=client -f deployment.yaml
```

---

## Incorrect Image Name

Ensure the image matches the Docker Hub repository.

Example

```yaml
image: demoproject/flask-app:latest
```

---

## Probe Failures

Verify the application responds to:

```text
/health
```

Expected Response

```json
{
  "status":"UP"
}
```

---

## NodePort Already in Use

Choose another NodePort within the range:

```
30000-32767
```

---

# Best Practices

- Use dedicated namespaces for applications.
- Configure resource requests and limits for every container.
- Enable liveness and readiness probes.
- Use Rolling Updates to minimize downtime.
- Match labels and selectors carefully.
- Keep Kubernetes manifests under version control.

---

# Learning Outcomes

After completing this section, you have successfully:

- Created a Kubernetes Namespace
- Created a Deployment
- Created a NodePort Service
- Configured ReplicaSets
- Configured Rolling Updates
- Added Liveness Probes
- Added Readiness Probes
- Configured Resource Requests and Limits
- Prepared the application for deployment

---

# Next Section : we will:

- Deploy the manifests to the Kubernetes cluster
- Verify the Namespace
- Verify the Deployment
- Verify the ReplicaSet
- Verify the Pods
- Verify the Service
- Access the application through the NodePort
- Scale the Deployment
- Demonstrate Rolling Updates
- Perform Rollback
- Troubleshoot common deployment issues

# Part 5B-2 - Deploying the Flask Application to Kubernetes

In this section, we will deploy the Flask application to the Kubernetes cluster and verify that it is running successfully.

After completing this section, you will learn how to:

- Deploy an application
- Verify Kubernetes resources
- Access the application
- Scale the application
- Perform Rolling Updates
- Rollback a deployment
- Troubleshoot deployments

---

# Deployment Workflow

```text
            Kubernetes YAML Files
                     │
                     ▼
             kubectl apply
                     │
                     ▼
                Namespace Created
                     │
                     ▼
             Deployment Created
                     │
                     ▼
              ReplicaSet Created
                     │
                     ▼
                  Pods Created
                     │
                     ▼
               Service Created
                     │
                     ▼
          Access Application
                     │
                     ▼
           Scale / Update / Rollback
```

---

# Step 1 - Verify the Kubernetes Cluster

Login to the Control Plane.

```bash
kubectl get nodes
```

Expected Output

```text
NAME                  STATUS   ROLES

k8s-control-plane     Ready    control-plane

k8s-worker1           Ready

k8s-worker2           Ready
```

---

# Step 2 - Navigate to Kubernetes Directory

```bash
cd kubernetes
```

Verify the files.

```bash
ls -lrt
```

Expected

```text
namespace.yaml

deployment.yaml

service.yaml
```

---

# Step 3 - Create the Namespace

```bash
kubectl apply -f namespace.yaml
```

Expected

```text
namespace/demo created
```

Verify

```bash
kubectl get ns
```

Expected

```text
NAME

default

demo

kube-system

kube-public
```

---

# Step 4 - Deploy the Application

```bash
kubectl apply -f deployment.yaml
```

Expected

```text
deployment.apps/flask-deployment created
```

---

# Step 5 - Create the Service

```bash
kubectl apply -f service.yaml
```

Expected

```text
service/flask-service created
```

---

# Step 6 - Verify the Deployment

```bash
kubectl get deployment -n demo
```

Expected

```text
NAME

flask-deployment

READY

2/2

AVAILABLE

2
```

---

# Step 7 - Verify ReplicaSet

```bash
kubectl get rs -n demo
```

Expected

```text
NAME

flask-deployment-xxxxxxxx

DESIRED

2

CURRENT

2

READY

2
```

---

# Step 8 - Verify Pods

```bash
kubectl get pods -n demo -o wide
```

Expected

```text
NAME

flask-deployment-xxxxx

Running

flask-deployment-yyyyy

Running
```

Notice the Pods are scheduled across Worker Nodes.

---

# Step 9 - Verify the Service

```bash
kubectl get svc -n demo
```

Expected

```text
NAME

flask-service

TYPE

NodePort

PORT(S)

80:30080/TCP
```

---

# Step 10 - Describe the Deployment

```bash
kubectl describe deployment flask-deployment -n demo
```

Verify

- Image
- Replicas
- Rolling Update Strategy
- Events

---

# Step 11 - Describe a Pod

```bash
kubectl describe pod <pod-name> -n demo
```

Useful Information

- Events
- Restart Count
- Image
- Node
- Resources
- Probes

---

# Step 12 - Verify the Running Image

```bash
kubectl describe deployment flask-deployment -n demo | grep Image
```

Expected

```text
Image:

demoproject/flask-app:latest
```

---

# Step 13 - Access the Application

Find the Worker Node IP.

```bash
kubectl get nodes -o wide
```

Open

```
http://<Worker-IP>:30080
```

Example

```
http://18.xx.xx.xx:30080
```

Expected

```
Welcome to DEMO Project

Running on Kubernetes

Version 1.0
```

---

# Step 14 - Test Health Endpoint

```bash
curl http://<Worker-IP>:30080/health
```

Expected

```json
{
  "status":"UP"
}
```

---

# Step 15 - Test Version Endpoint

```bash
curl http://<Worker-IP>:30080/version
```

Expected

```json
{
  "application":"DevOps Demo Project",
  "version":"Version 1.0"
}
```

---

# Step 16 - Scale the Deployment

Increase the replicas.

```bash
kubectl scale deployment flask-deployment \
--replicas=5 \
-n demo
```

Verify

```bash
kubectl get deployment -n demo
```

Expected

```text
READY

5/5
```

---

# Step 17 - Verify Pod Distribution

```bash
kubectl get pods -o wide -n demo
```

Pods should now be distributed across both Worker Nodes.

Explain to students

Kubernetes Scheduler automatically distributes Pods to available Worker Nodes.

---

# Step 18 - Demonstrate Self-Healing

Delete one Pod.

```bash
kubectl delete pod <pod-name> -n demo
```

Immediately verify.

```bash
kubectl get pods -w -n demo
```

Students will observe

Old Pod Deleted

↓

New Pod Created Automatically

This demonstrates Kubernetes Self-Healing.

Press

```
CTRL + C
```

to stop watching.

---

# Step 19 - Demonstrate Rolling Update

Update the Docker image.

Example

```
Version 2
```

Push the image using Jenkins.

Watch Pods.

```bash
watch kubectl get pods -n demo -o wide
```

Students will observe

Old Pods

↓

New Pods Created

↓

Traffic Shifted

↓

Old Pods Deleted

No downtime occurs.

---

# Step 20 - Verify Rollout Status

```bash
kubectl rollout status deployment/flask-deployment \
-n demo
```

Expected

```text
deployment successfully rolled out
```

---

# Step 21 - View Rollout History

```bash
kubectl rollout history deployment/flask-deployment \
-n demo
```

Example

```text
REVISION

1

2

3
```

---

# Step 22 - Rollback

Rollback to the previous version.

```bash
kubectl rollout undo deployment/flask-deployment \
-n demo
```

Verify

```bash
kubectl rollout history deployment/flask-deployment \
-n demo
```

Refresh the browser.

Students should now see the previous application version.

---

# Step 23 - Verify Resource Usage

View resource requests and limits.

```bash
kubectl describe pod <pod-name> -n demo
```

Locate

```
Requests

Limits
```

Explain how Kubernetes reserves CPU and Memory.

---

# Step 24 - View Logs

```bash
kubectl logs <pod-name> -n demo
```

View logs continuously.

```bash
kubectl logs -f <pod-name> -n demo
```

---

# Step 25 - Execute Commands Inside the Pod

```bash
kubectl exec -it <pod-name> -n demo -- sh
```

Examples

```bash
pwd

ls

env
```

Exit

```bash
exit
```

---

# Step 26 - Delete the Deployment

```bash
kubectl delete deployment flask-deployment -n demo
```

Verify

```bash
kubectl get deployment -n demo
```

---

# Step 27 - Delete the Service

```bash
kubectl delete svc flask-service -n demo
```

---

# Step 28 - Delete the Namespace

```bash
kubectl delete namespace demo
```

Verify

```bash
kubectl get ns
```

---

# Classroom Demonstration

## Demo 1 – Deployment

Deploy the application.

```bash
kubectl apply -f .
```

Observe

Pods

ReplicaSet

Deployment

---

## Demo 2 – Scaling

```bash
kubectl scale deployment flask-deployment \
--replicas=5
```

Observe new Pods being created.

---

## Demo 3 – Self-Healing

Delete one Pod.

Observe automatic recreation.

---

## Demo 4 – Rolling Update

Push a new Docker image through Jenkins.

Watch

```bash
watch kubectl get pods -o wide -n demo
```

---

## Demo 5 – Rollback

```bash
kubectl rollout undo deployment/flask-deployment
```

Refresh the application.

Students will observe the previous version.

---

# Verification Commands

Nodes

```bash
kubectl get nodes
```

Namespaces

```bash
kubectl get ns
```

Deployments

```bash
kubectl get deployment -A
```

ReplicaSets

```bash
kubectl get rs -A
```

Pods

```bash
kubectl get pods -o wide -A
```

Services

```bash
kubectl get svc -A
```

Events

```bash
kubectl get events -n demo --sort-by=.metadata.creationTimestamp
```

Logs

```bash
kubectl logs <pod-name> -n demo
```

Describe Pod

```bash
kubectl describe pod <pod-name> -n demo
```

Rollout History

```bash
kubectl rollout history deployment/flask-deployment -n demo
```

---

# Common Troubleshooting

## ImagePullBackOff

Verify

```bash
docker pull demoproject/flask-app:latest
```

Ensure the repository exists and the image is accessible.

---

## CrashLoopBackOff

Check logs.

```bash
kubectl logs <pod-name> -n demo
```

---

## Liveness Probe Failed

Verify

```text
/health
```

returns HTTP 200.

---

## Readiness Probe Failed

Ensure the application has fully started before accepting traffic.

---

## Service Not Accessible

Verify

```bash
kubectl get svc -n demo
```

Confirm the NodePort matches the URL you are using and that the AWS Security Group allows the selected NodePort (for example, **30080/TCP**).

---

## Pod Pending

Describe the Pod.

```bash
kubectl describe pod <pod-name> -n demo
```

Look for scheduling events such as insufficient CPU, memory, or node taints.

---

# Best Practices

- Deploy applications into dedicated namespaces.
- Use immutable image tags for production deployments.
- Define resource requests and limits for every workload.
- Configure liveness and readiness probes.
- Use rolling updates to minimize downtime.
- Monitor deployments using Prometheus and Grafana.
- Keep all Kubernetes manifests under version control.

---

# Learning Outcomes

After completing this section, you have successfully:

- Deployed a Flask application to Kubernetes
- Verified Deployments, ReplicaSets, Pods, and Services
- Accessed the application using a NodePort Service
- Scaled the application
- Demonstrated Kubernetes self-healing
- Performed rolling updates
- Rolled back a deployment
- Collected logs and inspected running Pods
- Prepared the application for monitoring

---

# Next Section : we will install the **kube-prometheus-stack** using **Helm**.

The monitoring stack will include:

- Prometheus
- Grafana
- Alertmanager
- Prometheus Operator
- Node Exporter
- kube-state-metrics

We will then configure Grafana, import dashboards, and begin monitoring the Kubernetes cluster and EC2 instances.


