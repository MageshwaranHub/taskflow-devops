GitHub webhook CI/CD test
# TaskFlow --- DevOps CI/CD Project

A Flask-based task management application deployed on AWS using Docker,
Kubernetes, Jenkins, Terraform, and Amazon ECR.

The project demonstrates an end-to-end DevOps workflow in which
source-code changes are tested, containerized, published to Amazon ECR,
and automatically deployed to a Kubernetes cluster running on AWS EC2.

## Architecture

``` text
Developer
   |
   v
GitHub
   |
   | Webhook
   v
Jenkins
   |
   +--> Run automated tests
   |
   +--> Build Docker image
   |
   +--> Login to Amazon ECR
   |
   +--> Push image (:BUILD_NUMBER and :latest)
   |
   +--> Refresh Kubernetes ECR pull secret
   |
   +--> Deploy to Kubernetes
   |
   +--> Verify rollout
            |
            v
       AWS EC2
            |
           k3s
            |
            v
       TaskFlow Flask App
            |
            v
       Public HTTP endpoint
```

## Technology Stack

  Area                     Technology
  ------------------------ -------------------
  Application              Python, Flask
  Testing                  Pytest
  Source Control           Git, GitHub
  Containerization         Docker
  CI/CD                    Jenkins
  Container Registry       Amazon ECR
  Cloud                    AWS
  Compute                  Amazon EC2
  Orchestration            Kubernetes / k3s
  Infrastructure as Code   Terraform
  Server OS                Ubuntu
  Webhook                  Cloudflare Tunnel

## Project Structure

``` text
taskflow-devops/
├── app/
│   ├── app.py
│   ├── templates/
│   │   └── index.html
│   └── static/
│       └── style.css
├── tests/
│   └── test_app.py
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── terraform/
│   ├── main.tf
│   └── ...
├── Dockerfile
├── Jenkinsfile
├── requirements.txt
├── .dockerignore
├── .gitignore
└── README.md
```

## Application

TaskFlow is a small Flask web application with:

-   A web interface
-   A health endpoint
-   A tasks API
-   Automated tests

Health endpoint:

``` text
GET /health
```

Expected response:

``` json
{"application":"TaskFlow","status":"healthy"}
```

## Docker

The application is packaged as a Docker image using Python 3.13 slim as
the base image.

Example local build:

``` bash
docker build -t taskflow:local .
```

Run locally:

``` bash
docker run -p 5000:5000 taskflow:local
```

The application is then available at:

``` text
http://localhost:5000
```

## Infrastructure with Terraform

Terraform provisions the AWS infrastructure required for the project,
including:

-   Custom VPC
-   Public subnet
-   Internet Gateway
-   Route table
-   Security group
-   EC2 instance
-   Elastic IP
-   EC2 key pair configuration

The EC2 instance runs Ubuntu and hosts the k3s Kubernetes cluster.

Typical workflow:

``` bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform state and generated provider files are excluded from Git using
`.gitignore`.

## Kubernetes

The application runs on a lightweight k3s Kubernetes cluster on the EC2
instance.

Kubernetes resources include:

-   Deployment
-   ClusterIP Service
-   Ingress
-   ECR image pull secret

The deployment uses Kubernetes rolling updates so the application can
transition from the old version to the new version without manually
stopping the application.

Useful commands:

``` bash
sudo k3s kubectl get nodes
sudo k3s kubectl get deployment taskflow
sudo k3s kubectl get pods -o wide
sudo k3s kubectl get service taskflow
```

## Jenkins CI/CD Pipeline

The Jenkins pipeline performs the following stages:

1.  Checkout source code from GitHub
2.  Install Python dependencies
3.  Run Pytest
4.  Verify project files
5.  Build the Docker image
6.  Authenticate with Amazon ECR
7.  Push the versioned image and `latest`
8.  Refresh the Kubernetes ECR pull secret
9.  Deploy the new image to Kubernetes
10. Wait for the Kubernetes rollout to complete
11. Verify the deployment, pods, and service

Images are tagged using the Jenkins build number:

``` text
taskflow:<BUILD_NUMBER>
```

For example:

``` text
taskflow:16
```

## Successful CI/CD Run

Jenkins Build #16 completed successfully.

Key results:

``` text
3 tests passed
Docker image :16 pushed to Amazon ECR
ECR pull secret refreshed
Kubernetes image updated
Rolling deployment completed
Deployment: 1/1
New pod: 1/1 Running
Pipeline: SUCCESS
```

The deployment changed from the previous pod:

``` text
taskflow-78dd87f467-r99j6
```

to the new pod:

``` text
taskflow-699cd6fd8f-nlrjf
```

This demonstrates an actual automated rolling deployment rather than a
manual container restart.

## AWS Components

The project uses:

-   Amazon EC2 for the Kubernetes host
-   Amazon ECR for Docker image storage
-   VPC networking for the EC2 environment
-   Security groups for network access
-   Elastic IP for the application endpoint
-   IAM credentials for Jenkins-to-ECR authentication

Sensitive credentials and Terraform state are not committed to the
repository.

## Webhook Automation

GitHub can notify Jenkins through a webhook.

For local Jenkins development, a Cloudflare Quick Tunnel can expose
Jenkins temporarily to GitHub:

``` text
GitHub --> Cloudflare Tunnel --> localhost:8080 --> Jenkins
```

The tunnel is intended for development/learning and is not a
production-grade ingress solution.

## Troubleshooting Experience

One of the practical issues encountered during development was SSH
connectivity.

The EC2 SSH service was verified with:

``` bash
sudo systemctl is-active ssh
```

and:

``` bash
sudo ss -lntp | grep ':22'
```

The issue was traced to changing public IP addresses and security-group
access.

The final Jenkins pipeline successfully established SSH access through
the Jenkins SSH Agent credential and completed the deployment.

This was an important part of the project because it demonstrated
real-world troubleshooting rather than only following a happy-path
tutorial.

## Security Notes

This project is a portfolio/learning deployment.

Important production improvements would include:

-   Avoiding long-lived IAM access keys where possible
-   Using AWS IAM roles for workloads
-   Replacing dynamic `/32` SSH rules with a more stable access
    mechanism
-   Using AWS Systems Manager Session Manager or another controlled
    administrative path
-   Moving Jenkins into an appropriate AWS environment or using a
    managed CI/CD service
-   Enabling HTTPS with a proper domain and TLS certificate
-   Adding centralized logging and monitoring
-   Storing secrets in a dedicated secret-management system
-   Using immutable image digests for stronger deployment guarantees

## What This Project Demonstrates

This project demonstrates practical knowledge of:

-   Git-based development workflows
-   Automated testing
-   Docker image creation
-   CI/CD pipeline design
-   Jenkins automation
-   AWS ECR authentication and image publishing
-   Kubernetes deployments and rolling updates
-   Kubernetes health checks
-   Terraform Infrastructure as Code
-   AWS networking and security groups
-   Linux server administration
-   CI/CD troubleshooting

## Future Improvements

Possible next steps:

-   HTTPS with a custom domain
-   Prometheus and Grafana monitoring
-   Centralized application logs
-   Kubernetes resource autoscaling
-   AWS Systems Manager access
-   Remote Terraform state
-   Terraform modules
-   Jenkins running inside AWS
-   Image vulnerability scanning
-   Deployment approvals
-   Blue/green or canary deployment
-   Infrastructure and application monitoring dashboards

## Author

**Mageshwaran**

This project was built as a hands-on DevOps portfolio project to
demonstrate an end-to-end cloud deployment and CI/CD workflow.


