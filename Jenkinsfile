pipeline{
    agent any
    stages{
        stage('Lint HTML, Docker'){
            steps{
              sh  'tidy -q -e *.html'
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
                 sh 'npm run test'
             }   
        }

        stage('Build React App'){
             steps{
                 sh 'npm run build'
             }   
        }

        stage('Build & Push Docker'){
             steps{
                 GIT_COMMIT_ID = sh (script: 'git log -1 --pretty=%H',returnStdout: true).trim()
                 TIMESTAMP = sh (script: 'date +%Y%m%d%H%M%S',returnStdout: true).trim()
                 echo "Git commit id: ${GIT_COMMIT_ID}"
                 IMAGETAG="${GIT_COMMIT_ID}-${TIMESTAMP}"
                 sh 'docker build -t ujjwaldocker/hello-react:${IMAGETAG} .'
                 sh 'docker push ujjwaldocker/hello-react:${IMAGETAG}'
             }   
        }

        stage('Create K8s cluster') {
            steps {
               sh 'kops version'
               sh 'export KOPS_GREEN_CLUSTER_NAME=greencluster.k8s.local'
               sh 'export DEPLOYMENT_NAME=react-app-kubernetes'
               sh 'export KOPS_STATE_STORE=s3://greencluster-for-reactapp-state-store'
               sh 'kops create cluster --node-count=1 --master-size=t2.small  --node-size=t2.small --zones=us-east-1a --name=${KOPS_GREEN_CLUSTER_NAME}'
               sh 'kops update cluster --name ${KOPS_GREEN_CLUSTER_NAME} --yes'
            }
        }
        
        stage('Validating K8s cluster') {
            options {
                timeout(time: 10, unit: 'MINUTES') 
            }            
            steps {
                sh "kops validate cluster"
            }
        }

        stage('Deploy on AWS'){
            steps{
               sh 'kubectl create deployment ${DEPLOYMENT_NAME} --image=docker.io/ujjwaldocker/hello-react:${IMAGETAG}'
               sh 'kubectl expose deployment/${DEPLOYMENT_NAME} --type="NodePort" --port 8080'
               sh 'export NODE_PORT=$(kubectl get services/${DEPLOYMENT_NAME} -o go-template="{{(index .spec.ports 0).nodePort}}")'
               sh 'echo NODE_PORT=$NODE_PORT'
            }            
        }


        stage('Update Blue with New Release'){
            if (userInput['DEPLOY_TO_PROD'] == true) {
               sh 'kops version'
               sh 'kubectl config use-context bluecluster.k8s.local'
               sh 'kubectl set image deployments/${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}=docker.io/ujjwaldocker/hello-react:${IMAGETAG}'
               sh 'kubectl rollout status deployments/kubernetes-bootcamp'
               echo "Deleting Green Environment..."
               sh 'kops delete cluster --name ${KOPS_GREEN_CLUSTER_NAME} --yes '
            }
        }
    }
    def userInput
        try {
            timeout(time: 60, unit: 'SECONDS') {
            userInput = input message: 'Proceed to Production?', parameters: [booleanParam(defaultValue: false, description: 'Ticking this box will do a deployment on Prod', name: 'DEPLOY_TO_PROD'),
                                                                        booleanParam(defaultValue: false, description: 'First Deployment on Prod?', name: 'PROD_BLUE_DEPLOYMENT')]}
        }
        catch (err) {
            def user = err.getCauses()[0].getUser()
            echo "Aborted by:\n ${user}"
            currentBuild.result = "SUCCESS"
            return
        }
}