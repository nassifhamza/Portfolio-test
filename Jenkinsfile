pipeline {
    agent any
    
    environment {
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub-credentials')
        SONAR_TOKEN = credentials('sonarqube-token')
        NEXUS_CREDENTIALS = credentials('nexus-user')
        
        // Update with your Docker Hub username
        IMAGE_NAME = 'hamzanassif/react-frontend-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Local machine URLs
        TRIVY_SERVER = 'http://localhost:4954'
        SONAR_URL = 'http://localhost:9000'
        NEXUS_URL = 'http://localhost:8081'
        
        NODE_VERSION = '18'
    }
    
    tools {
        nodejs 'NodeJS-18'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo '📦 Code checked out successfully'
                sh 'ls -la'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    echo '📥 Installing dependencies...'
                    sh '''
                        node --version
                        npm --version
                        npm ci --only=production
                        npm install --only=dev
                    '''
                }
            }
        }
        
        stage('Code Linting') {
            steps {
                script {
                    echo '🔍 Running ESLint...'
                    sh '''
                        if ! npm list eslint; then
                            npm install --save-dev eslint
                        fi
                        npx eslint src/ --ext .js,.jsx,.ts,.tsx --format json > eslint-report.json || true
                        npx eslint src/ --ext .js,.jsx,.ts,.tsx || true
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'eslint-report.json', fingerprint: true, allowEmptyArchive: true
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                script {
                    echo '🧪 Running unit tests...'
                    sh '''
                        export CI=true
                        npm test -- --coverage --watchAll=false || true
                    '''
                }
            }
            post {
                always {
                    script {
                        if (fileExists('coverage/lcov-report/index.html')) {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'coverage/lcov-report',
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    echo '🏗️ Building React application...'
                    sh '''
                        npm run build
                        ls -la build/
                        echo "Build Number: ${BUILD_NUMBER}" > build/build-info.txt
                        echo "Build Date: $(date)" >> build/build-info.txt
                    '''
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'build/**', fingerprint: true
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    echo '📊 Running SonarQube analysis...'
                    
                    writeFile file: 'sonar-project.properties', text: '''sonar.projectKey=${JOB_NAME}
sonar.projectName=${JOB_NAME}
sonar.projectVersion=${BUILD_NUMBER}
sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.js,**/*.test.jsx
sonar.exclusions=**/node_modules/**,**/build/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.eslint.reportPaths=eslint-report.json'''
                    
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            if [ ! -d "sonar-scanner-cli" ]; then
                                wget -O sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
                                unzip -o sonar-scanner.zip
                                mv sonar-scanner-* sonar-scanner-cli
                            fi
                            ./sonar-scanner-cli/bin/sonar-scanner -Dsonar.host.url=${SONAR_URL} -Dsonar.login=${SONAR_TOKEN}
                        '''
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo '🐳 Building Docker image...'
                    
                    writeFile file: 'Dockerfile', text: '''FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
LABEL maintainer="hamza.nassif12@hotmail.com"
LABEL version="${BUILD_NUMBER}"
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]'''
                    
                    writeFile file: 'nginx.conf', text: '''events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        gzip on;
        location / {
            try_files $uri $uri/ /index.html;
        }
        location /health {
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }
    }
}'''
                    
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
                    
                    echo "✅ Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('Security Scan with Trivy') {
            steps {
                script {
                    echo '🔒 Scanning image for vulnerabilities...'
                    sh '''
                        if ! command -v trivy &> /dev/null; then
                            echo "Installing Trivy..."
                            wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.tar.gz
                            tar zxvf trivy_Linux-64bit.tar.gz
                            sudo mv trivy /usr/local/bin/ || mv trivy ./
                            export PATH=$PATH:.
                        fi
                        
                        trivy image --format json --output trivy-report.json ${IMAGE_NAME}:${IMAGE_TAG} || true
                        trivy image --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG} || true
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true, allowEmptyArchive: true
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    echo '📤 Pushing image to Docker Hub...'
                    sh '''
                        echo ${DOCKER_HUB_CREDENTIALS_PSW} | docker login -u ${DOCKER_HUB_CREDENTIALS_USR} --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                        echo "✅ Image pushed to Docker Hub"
                    '''
                }
            }
        }
        
        stage('Push Artifacts to Nexus') {
            steps {
                script {
                    echo '📦 Pushing build artifacts to Nexus...'
                    sh '''
                        tar -czf react-app-${BUILD_NUMBER}.tar.gz build/ package.json
                        curl -v --user ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} --upload-file react-app-${BUILD_NUMBER}.tar.gz "${NEXUS_URL}/repository/maven-releases/com/frontend/react-app/${BUILD_NUMBER}/react-app-${BUILD_NUMBER}.tar.gz"
                        echo "✅ Artifacts uploaded to Nexus"
                    '''
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    echo '🚀 Deploying React application...'
                    sh '''
                        docker stop react-frontend-app || true
                        docker rm react-frontend-app || true
                        docker run -d --name react-frontend-app --restart unless-stopped -p 3000:80 -e "BUILD_NUMBER=${BUILD_NUMBER}" ${IMAGE_NAME}:${IMAGE_TAG}
                        sleep 15
                        
                        if curl -f http://localhost:3000; then
                            echo "✅ Application is running successfully!"
                            echo "🌐 Access your app at: http://localhost:3000"
                        else
                            echo "❌ Health check failed!"
                            docker logs react-frontend-app
                            exit 1
                        fi
                        
                        docker ps | grep react-frontend-app
                    '''
                }
            }
        }
        
        stage('Post-Deploy Tests') {
            steps {
                script {
                    echo '🧪 Running post-deployment tests...'
                    sh '''
                        curl -I http://localhost:3000
                        curl -s http://localhost:3000 | grep -i "react" && echo "✅ React app detected" || echo "⚠️ React content not found"
                        time curl -s http://localhost:3000 > /dev/null
                        echo "✅ Post-deployment tests completed"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo '🧹 Cleaning up...'
            sh '''
                docker images ${IMAGE_NAME} --format "table {{.Repository}}:{{.Tag}}\\t{{.ID}}" | tail -n +4 | awk '{print $2}' | xargs -r docker rmi || true
                rm -f *.tar.gz *.zip || true
                docker logout || true
            '''
            cleanWs()
        }
        success {
            echo '✅ Pipeline completed successfully!'
            script {
                currentBuild.description = "✅ Deployed: http://localhost:3000"
            }
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                docker logs react-frontend-app || true
                docker ps -a || true
            '''
        }
    }
}
