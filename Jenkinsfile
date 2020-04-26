pipeline{
    agent any
    stages{
        stage('Lint HTML, Docker'){
            steps{
              sh  'tidy -q -e public/*.html'
              sh  'hadolint Dockerfile'
            }            
        }

        stage('Install Dependencies'){
             steps{
                 sh 'npm i'
             }   
        }

        stage('Test React App'){
             steps{
                 sh 'npm run test-ci'
             }   
        }

        stage('Build React App'){
             steps{
                 sh 'npm run build'
             }   
        }

        stage('Build & Push Docker'){
             environment{
                    GIT_COMMIT_ID = sh (script: 'git log -1 --pretty=%H',returnStdout: true).trim()
                    TIMESTAMP = sh (script: 'date +%Y%m%d%H%M%S',returnStdout: true).trim()
                    IMAGETAG="${env.GIT_COMMIT_ID}-${TIMESTAMP}"
             }       
            steps{ 
                withCredentials([usernamePassword(credentialsId: 'docker', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    echo "Git commit id: ${env.GIT_COMMIT_ID}"
                    echo "p ${PASSWORD}, u: ${USERNAME}"
                    sh 'docker build -t ujjwaldocker/hello-react:${IMAGETAG} .'

                    sh 'docker login -u ${USERNAME} -p ${PASSWORD} && docker push docker.io/ujjwaldocker/hello-react:${IMAGETAG}'
                }   
            }
        }

        stage('Create K8s cluster') {
            steps {
                withAWS(credentials:'jenkins-aws'){    
                    sh 'kops version'
                    sh 'export KOPS_GREEN_CLUSTER_NAME=greencluster.k8s.local'
                    sh 'export DEPLOYMENT_NAME=react-app-kubernetes'
                    sh 'export KOPS_STATE_STORE=s3://greencluster-for-reactapp-state-store'
                    sh 'kops create cluster --node-count=1 --master-size=t2.small  --node-size=t2.small --zones=us-east-1a --name=${KOPS_GREEN_CLUSTER_NAME}'
                    sh 'kops update cluster --name ${KOPS_GREEN_CLUSTER_NAME} --yes'
                }
            }
        }
        
        stage('Validating K8s cluster') {
            options {
                timeout(time: 10, unit: 'MINUTES') 
            }            
            steps {
                withAWS(credentials:'jenkins-aws'){
                    sh "kops validate cluster"
                }
            }
        }

        stage('Deploy on AWS & Expose service'){
            steps{
               withAWS(credentials:'jenkins-aws'){ 
                    sh 'kubectl create deployment ${DEPLOYMENT_NAME} --image=docker.io/ujjwaldocker/hello-react:${IMAGETAG}'
                    sh 'kubectl expose deployment/${DEPLOYMENT_NAME} --type="NodePort" --port 8080'
                    sh 'export NODE_PORT=$(kubectl get services/${DEPLOYMENT_NAME} -o go-template="{{(index .spec.ports 0).nodePort}}")'
                    sh 'echo NODE_PORT=$NODE_PORT'
               }
            }            
        }


        stage('Update Blue with New Release'){
            steps{
               input message: 'Finished verification? (Click "Proceed" to continue)'
               sh 'kops version'
               sh 'kubectl config use-context bluecluster.k8s.local'
               sh 'kubectl set image deployments/${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}=docker.io/ujjwaldocker/hello-react:${IMAGETAG}'
               sh 'kubectl rollout status deployments/kubernetes-bootcamp'
               echo "Deleting Green Environment..."
               sh 'kops delete cluster --name ${KOPS_GREEN_CLUSTER_NAME} --yes'
            }   
        }
    }
}