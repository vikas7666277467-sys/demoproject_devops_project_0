# Jenkins pipeline configuration

1. Open `http://JENKINS_PUBLIC_IP:8080`, unlock Jenkins with
   `/var/lib/jenkins/secrets/initialAdminPassword`, create the administrator,
   and install the plugins listed in `plugins.txt` using **Manage Plugins**.
2. Create a Username/Password credential named `dockerhub-credentials`. The
   username is the Docker Hub account and the password is a scoped access token.
3. On the control plane, create a dedicated service account using the commands
   in `docs/INSTALLATION_AND_CONFIGURATION.md`. Store its kubeconfig in Jenkins
   as a **Secret file** named `kubernetes-kubeconfig`.
4. Create a Pipeline job, select **Pipeline script from SCM**, choose Git, enter
   the GitHub repository URL, select the GitHub credential when private, set the
   script path to `jenkins/Jenkinsfile`, and enable the GitHub hook trigger.
5. In GitHub, create a webhook targeting
   `http://JENKINS_PUBLIC_IP:8080/github-webhook/`, content type
   `application/json`, a strong secret, and push events only.

The pipeline builds immutable `BUILD_NUMBER` images, also updates `latest`,
waits for a zero-downtime rolling deployment, prints workload state, and rolls
back when a later stage fails. Protect the default branch and rotate both
Docker Hub and GitHub tokens periodically.
