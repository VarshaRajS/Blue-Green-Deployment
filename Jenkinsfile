pipeline {
    agent any
    
    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'DOCKER_TAG', choices: ['blue', 'green'], description: 'Choose the Docker image tag for the deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }
    
    environment {
        IMAGE_NAME = "adijaiswal/bankapp"
        TAG = "${params.DOCKER_TAG}"
        KUBE_NAMESPACE = 'bluegreen-webapps'
        SCANNER_HOME= tool 'sonar-scanner'
    }

    stages {
        
        // Stage 1: Checkout the latest code from the Git repository
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/jaiswaladi246/3-Tier-NodeJS-MySql-Docker.git'
            }
        }
        
        // Stage 2: Run SonarQube static code analysis
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=nodejsmysql -Dsonar.projectName=nodejsmysql"
                }
            }
        }
        
        // Stage 3: Scan the application file system for vulnerabilities using Trivy
        stage('Trivy FS Scan') {
            steps {
                sh "trivy fs --format table -o fs.html ."
            }
        }
        
        // Stage 4: Build the Docker image
        stage('Docker build') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker build -t ${IMAGE_NAME}:${TAG} ."
                    }
                }
            }
        }
        
        // Stage 5: Scan Docker image for vulnerabilities with Trivy
        stage('Trivy Image Scan') {
            steps {
                sh "trivy image --format table -o image.html ${IMAGE_NAME}:${TAG}"
            }
        }
        
        // Stage 6: Push the Docker image to the registry
        stage('Docker Push Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                    }
                }
            }
        }
        
        // Stage 7: Deploy MySQL database deployment and service
        stage('Deploy MySQL Deployment and Service') {
            steps {
                script {
                    withKubeConfig(
                        caCertificate: '',
                        clusterName: 'bluegreen-cluster',
                        contextName: '',
                        credentialsId: 'k8-token',
                        namespace: 'bluegreen-webapps',
                        restrictKubeConfigAccess: false,
                        serverUrl: 'https://46743932FDE6B34C74566F392E30CABA.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh "kubectl apply -f mysql-bluegreen-ds.yml -n ${KUBE_NAMESPACE}"
                    }
                }
            }
        }
        
        // Stage 8: Deploy application service if it doesn't already exist
        stage('Deploy Application Service') {
            steps {
                script {
                    withKubeConfig(
                        caCertificate: '',
                        clusterName: 'bluegreen-cluster',
                        contextName: '',
                        credentialsId: 'k8-token',
                        namespace: 'bluegreen-webapps',
                        restrictKubeConfigAccess: false,
                        serverUrl: 'https://46743932FDE6B34C74566F392E30CABA.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh """ if ! kubectl get svc bankapp-bluegreen-service -n ${KUBE_NAMESPACE}; then
                                kubectl apply -f bankapp-bluegreen-service.yml -n ${KUBE_NAMESPACE}
                              fi
                        """
                    }
                }
            }
        }
        
        // Stage 9: Deploy the application to Kubernetes in blue/green environment
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def deploymentFile = ""
                    if (params.DEPLOY_ENV == 'blue') {
                        deploymentFile = 'bankapp-deployment-bluegreen-blue.yml'
                    } else {
                        deploymentFile = 'bankapp-deployment-bluegreen-green.yml'
                    }

                    withKubeConfig(
                        caCertificate: '',
                        clusterName: 'bluegreen-cluster',
                        contextName: '',
                        credentialsId: 'k8-token',
                        namespace: 'bluegreen-webapps',
                        restrictKubeConfigAccess: false,
                        serverUrl: 'https://46743932FDE6B34C74566F392E30CABA.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh "kubectl apply -f ${deploymentFile} -n ${KUBE_NAMESPACE}"
                    }
                }
            }
        }
        
        // Stage 10: Allow traffic switching between Blue and Green environments
        stage('Switch Traffic Between Blue & Green Environment') {
            when {
                expression { return params.SWITCH_TRAFFIC }
            }
            steps {
                script {
                    def newEnv = params.DEPLOY_ENV

                    withKubeConfig(
                        caCertificate: '',
                        clusterName: 'bluegreen-cluster',
                        contextName: '',
                        credentialsId: 'k8-token',
                        namespace: 'bluegreen-webapps',
                        restrictKubeConfigAccess: false,
                        serverUrl: 'https://46743932FDE6B34C74566F392E30CABA.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh '''
                            kubectl patch service bankapp-bluegreen-service -p "{\\"spec\\": {\\"selector\\": {\\"app\\": \\"bankapp\\", \\"version\\": \\"''' + newEnv + '''\\"}}}" -n ${KUBE_NAMESPACE}
                        '''
                    }
                    echo "Traffic has been switched to the ${newEnv} environment."
                }
            }
        }
        
        // Stage 11: Verify the deployment status
        stage('Verify Deployment') {
            steps {
                script {
                    def verifyEnv = params.DEPLOY_ENV
                    withKubeConfig(
                        caCertificate: '',
                        clusterName: 'bluegreen-cluster',
                        contextName: '',
                        credentialsId: 'k8-token',
                        namespace: 'bluegreen-webapps',
                        restrictKubeConfigAccess: false,
                        serverUrl: 'https://46743932FDE6B34C74566F392E30CABA.gr7.ap-south-1.eks.amazonaws.com'
                    ) {
                        sh """
                        kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                        kubectl get svc bankapp-bluegreen-service -n ${KUBE_NAMESPACE}
                        """
                    }
                }
            }
        }
    }
}
