pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REGISTRY = '884686184497.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_REPOSITORY = 'taskflow'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Run Tests') {
            steps {
                sh '''
                    python3 -m pip install --break-system-packages --no-cache-dir -r requirements.txt
                    python3 -m pytest -v
                '''
            }
        }

        stage('Verify Files') {
            steps {
                sh '''
                    echo "Current directory:"
                    pwd

                    echo "Project files:"
                    ls -la

                    echo "Dockerfile:"
                    ls -l Dockerfile
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                      -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} \
                      -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest \
                      .
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-ecr']
                ]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} \
                        | docker login \
                          --username AWS \
                          --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                '''
            }
        }

        stage('Refresh ECR Pull Secret') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-ecr']
                ]) {
                    sshagent(credentials: ['taskflow-ec2-ssh']) {
                        sh '''
                            set +x

                            ECR_PASSWORD="$(aws ecr get-login-password --region ${AWS_REGION})"
                            export ECR_PASSWORD

                            python3 - <<'PY' | ssh -o StrictHostKeyChecking=no ubuntu@65.1.41.93 "sudo k3s kubectl apply -f -"
import os
import json
import base64

registry = os.environ["ECR_REGISTRY"]
password = os.environ["ECR_PASSWORD"]

auth = base64.b64encode(
    f"AWS:{password}".encode()
).decode()

docker_config = {
    "auths": {
        registry: {
            "username": "AWS",
            "password": password,
            "auth": auth
        }
    }
}

docker_config_json = json.dumps(
    docker_config,
    separators=(",", ":")
)

docker_config_b64 = base64.b64encode(
    docker_config_json.encode()
).decode()

print(f"""apiVersion: v1
kind: Secret
metadata:
  name: ecr-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {docker_config_b64}
""")
PY

                            unset ECR_PASSWORD
                            set -x
                        '''
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sshagent(credentials: ['taskflow-ec2-ssh']) {
                    sh '''
                        scp -o StrictHostKeyChecking=no \
                            k8s/deployment.yaml \
                            ubuntu@65.1.41.93:/home/ubuntu/deployment.yaml

                        ssh -o StrictHostKeyChecking=no ubuntu@65.1.41.93 "
                            sudo k3s kubectl apply -f /home/ubuntu/deployment.yaml &&
                            sudo k3s kubectl set image deployment/taskflow \
                            taskflow=${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} &&
                            sudo k3s kubectl rollout status deployment/taskflow
                        "
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sshagent(credentials: ['taskflow-ec2-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ubuntu@65.1.41.93 "
                            echo '=== Deployment ===' &&
                            sudo k3s kubectl get deployment taskflow &&
                            echo '=== Pods ===' &&
                            sudo k3s kubectl get pods -o wide &&
                            echo '=== Service ===' &&
                            sudo k3s kubectl get service taskflow
                        "
                    '''
                }
            }
        }
    }

    post {

        success {
            echo '========================================'
            echo 'TaskFlow CI/CD completed successfully!'
            echo '========================================'
        }

        failure {
            echo 'TaskFlow CI/CD pipeline failed.'
        }

        always {
            sh 'docker image prune -f || true'
        }
    }
}