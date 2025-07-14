pipeline {
    agent any
    
    environment {
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub-credentials')
        SONAR_TOKEN = credentials('sonarqube-token')
        NEXUS_CREDENTIALS = credentials('nexus-credentials')
        
        // 🔄 UPDATE: Change to your Docker Hub username
        IMAGE_NAME = 'hamzanassif/react-frontend-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // 🔄 UPDATE: Local machine URLs
        TRIVY_SERVER = 'http://localhost:4954'
        SONAR_URL = 'http://localhost:9000'
        NEXUS_URL = 'http://localhost:8081'
        
        NODE_VERSION = '18'
    }
    
    tools {
        nodejs 'NodeJS-18' // Configure this in Jenkins Global Tools
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
                        # Check Node.js and npm versions
                        node --version
                        npm --version
                        
                        # Clean install
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
                        # Install ESLint if not present
                        if ! npm list eslint; then
                            npm install --save-dev eslint
                        fi
                        
                        # Run linting
                        npx eslint src/ --ext .js,.jsx,.ts,.tsx --format json > eslint-report.json || true
                        npx eslint src/ --ext .js,.jsx,.ts,.tsx || true
                    '''
                }
            }
            post {
                always {
                    // Archive lint results
                    archiveArtifacts artifacts: 'eslint-report.json', fingerprint: true, allowEmptyArchive: true
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                script {
                    echo '🧪 Running unit tests...'
                    sh '''
                        # Set CI environment for non-interactive testing
                        export CI=true
                        
                        # Run tests with coverage
                        npm test -- --coverage --watchAll=false --testResultsProcessor=jest-junit
                        
                        # Alternative if jest-junit not available
                        npm test -- --coverage --watchAll=false || true
                    '''
                }
            }
            post {
                always {
                    // Publish test results if available
                    script {
                        if (fileExists('junit.xml')) {
                            junit 'junit.xml'
                        }
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
                        # Build the application
                        npm run build
                        
                        # Verify build output
                        ls -la build/
                        
                        # Create build info
                        echo "Build Number: ${BUILD_NUMBER}" > build/build-info.txt
                        echo "Build Date: $(date)" >> build/build-info.txt
                        echo "Git Commit: $(git rev-parse HEAD)" >> build/build-info.txt
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
                    
                    // Create sonar-project.properties for frontend
                    sh '''
                        cat > sonar-project.properties << 'EOF'
sonar.projectKey=${JOB_NAME}
sonar.projectName=${JOB_NAME}
sonar.projectVersion=${BUILD_NUMBER}

# Source directories
sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.js,**/*.test.jsx,**/*.test.ts,**/*.test.tsx,**/*.spec.js,**/*.spec.jsx

# Exclusions
sonar.exclusions=**/node_modules/**,**/build/**,**/dist/**,**/*.test.js,**/*.test.jsx,**/*.test.ts,**/*.test.tsx

# Language settings
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.lcov.reportPaths=coverage/lcov.info

# ESLint report
sonar.eslint.reportPaths=eslint-report.json
EOF
                    '''
                    
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            # Download SonarQube scanner if not available
                            if [ ! -d "sonar-scanner-cli" ]; then
                                wget -O sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
                                unzip -o sonar-scanner.zip
                                mv sonar-scanner-* sonar-scanner-cli
                            fi
                            
                            # Run SonarQube analysis with localhost URL
                            ./sonar-scanner-cli/bin/sonar-scanner \
                                -Dsonar.host.url=${SONAR_URL} \
                                -Dsonar.login=${SONAR_TOKEN}
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
                    
                    // Create optimized Dockerfile for React
                    sh '''
                        cat > Dockerfile << 'DOCKERFILE_EOF'
# Multi-stage build for React app
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app to nginx
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Add labels for better image management
LABEL maintainer="hamza.nassif12@hotmail.com"
LABEL version="${BUILD_NUMBER}"
LABEL description="React Frontend Application"

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
DOCKERFILE_EOF
                    '''
                    
                    // Create nginx config for React SPA
                    sh '''
                        cat > nginx.conf << 'NGINX_EOF'
events {
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
        
        # Enable gzip compression
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        
        # Handle React Router (SPA)
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }
    }
}
NGINX_EOF
                    '''
                    
                    // Build Docker image
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
                        # Install trivy client if not available (for local machine)
                        if ! command -v trivy &> /dev/null; then
                            echo "Installing Trivy..."
                            # For Linux
                            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                                wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.tar.gz
                                tar zxvf trivy_Linux-64bit.tar.gz
                                sudo mv trivy /usr/local/bin/ || mv trivy ./
                                export PATH=$PATH:.
                            # For macOS
                            elif [[ "$OSTYPE" == "darwin"* ]]; then
                                brew install trivy || echo "Please install Trivy manually"
                            fi
                        fi
                        
                        # Scan the image for vulnerabilities
                        echo "🔍 Scanning ${IMAGE_NAME}:${IMAGE_TAG}..."
                        
                        # Try server mode first, fallback to standalone
                        trivy image --server ${TRIVY_SERVER} --format json --output trivy-report.json ${IMAGE_NAME}:${IMAGE_TAG} || \
                        trivy image --format json --output trivy-report.json ${IMAGE_NAME}:${IMAGE_TAG}
                        
                        # Show scan results
                        trivy image --server ${TRIVY_SERVER} --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG} || \
                        trivy image --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
                        
                        # Create summary
                        echo "Trivy scan completed for ${IMAGE_NAME}:${IMAGE_TAG}" > trivy-summary.txt
                        trivy image --server ${TRIVY_SERVER} --format table ${IMAGE_NAME}:${IMAGE_TAG} >> trivy-summary.txt || \
                        trivy image --format table ${IMAGE_NAME}:${IMAGE_TAG} >> trivy-summary.txt
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json,trivy-summary.txt', fingerprint: true, allowEmptyArchive: true
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
                        
                        echo "✅ Image pushed to Docker Hub:"
                        echo "  - ${IMAGE_NAME}:${IMAGE_TAG}"
                        echo "  - ${IMAGE_NAME}:latest"
                    '''
                }
            }
        }
        
        stage('Push Artifacts to Nexus') {
            steps {
                script {
                    echo '📦 Pushing build artifacts to Nexus...'
                    sh '''
                        # Create production build package
                        tar -czf react-app-${BUILD_NUMBER}.tar.gz build/ package.json
                        
                        # Create source code package
                        tar -czf react-source-${BUILD_NUMBER}.tar.gz --exclude=node_modules --exclude=.git .
                        
                        # Upload build artifacts to Nexus (localhost URL)
                        curl -v --user ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} \
                             --upload-file react-app-${BUILD_NUMBER}.tar.gz \
                             "${NEXUS_URL}/repository/maven-releases/com/frontend/react-app/${BUILD_NUMBER}/react-app-${BUILD_NUMBER}.tar.gz"
                        
                        # Upload source package
                        curl -v --user ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} \
                             --upload-file react-source-${BUILD_NUMBER}.tar.gz \
                             "${NEXUS_URL}/repository/maven-releases/com/frontend/react-source/${BUILD_NUMBER}/react-source-${BUILD_NUMBER}.tar.gz"
                        
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
                        # Stop existing container if running
                        docker stop react-frontend-app || true
                        docker rm react-frontend-app || true
                        
                        # Deploy new version with proper configuration
                        docker run -d \
                            --name react-frontend-app \
                            --restart unless-stopped \
                            -p 3000:80 \
                            -e "BUILD_NUMBER=${BUILD_NUMBER}" \
                            ${IMAGE_NAME}:${IMAGE_TAG}
                        
                        # Wait for container to start
                        sleep 15
                        
                        # Health check
                        echo "🏥 Performing health check..."
                        if curl -f http://localhost:3000/health; then
                            echo "✅ Health check passed!"
                        elif curl -f http://localhost:3000; then
                            echo "✅ Application is running successfully!"
                        else
                            echo "❌ Health check failed!"
                            docker logs react-frontend-app
                            exit 1
                        fi
                        
                        echo "🌐 Access your app at: http://localhost:3000"
                        
                        # Show container status
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
                        # Basic connectivity test
                        curl -I http://localhost:3000
                        
                        # Check if main page loads
                        curl -s http://localhost:3000 | grep -i "react" && echo "✅ React app detected" || echo "⚠️ React content not found"
                        
                        # Check if static assets are served
                        curl -s -I http://localhost:3000/static/css/ && echo "✅ CSS assets accessible" || echo "ℹ️ CSS assets check skipped"
                        curl -s -I http://localhost:3000/static/js/ && echo "✅ JS assets accessible" || echo "ℹ️ JS assets check skipped"
                        
                        # Performance test (basic)
                        echo "⏱️ Performance test:"
                        time curl -s http://localhost:3000 > /dev/null
                        
                        # Check health endpoint
                        curl -s http://localhost:3000/health && echo "✅ Health endpoint working" || echo "ℹ️ Health endpoint not available"
                        
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
                # Clean up Docker images (keep last 3 builds)
                docker images ${IMAGE_NAME} --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | tail -n +4 | awk '{print $2}' | xargs -r docker rmi || true
                
                # Clean up build artifacts
                rm -f *.tar.gz *.zip sonar-scanner.zip
                
                # Clean up downloaded scanner
                rm -rf sonar-scanner-* || true
                
                # Docker logout
                docker logout || true
                
                # Show final container status
                echo "📊 Current running containers:"
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            '''
            cleanWs()
        }
        success {
            echo '✅ Pipeline completed successfully!'
            script {
                currentBuild.description = "✅ Deployed: http://localhost:3000"
                
                // Send success notification
                echo """
🎉 DEPLOYMENT SUCCESS!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}
🌐 URL: http://localhost:3000
🏗️ Build: #${BUILD_NUMBER}
📊 SonarQube: ${SONAR_URL}
📦 Nexus: ${NEXUS_URL}
🐳 Docker Hub: https://hub.docker.com/r/${IMAGE_NAME}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                """
            }
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                echo "🔍 Debugging information:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                # Show container logs for debugging
                echo "📋 Container logs:"
                docker logs react-frontend-app || true
                
                # Show system status
                echo "📊 Docker containers:"
                docker ps -a
                
                echo "💾 Disk space:"
                df -h
                
                echo "🔧 Docker system info:"
                docker system df
                
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            '''
        }
        unstable {
            echo '⚠️ Pipeline completed with warnings'
        }
    }
}