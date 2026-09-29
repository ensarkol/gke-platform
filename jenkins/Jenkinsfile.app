pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    USE_GKE_GCLOUD_AUTH_PLUGIN = 'True'
    TG_NON_INTERACTIVE         = 'true'
    TG_DIR                     = 'iac/k8s/app'
    IMAGE_NAME                 = "${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/nodejs-app"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build & Push') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        sh '''
          gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
          docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f app/Dockerfile app/
          docker push "${IMAGE_NAME}:${IMAGE_TAG}"
        '''
      }
    }

    // helm/nodejs-app chart'ı terragrunt (helm_release) ile kurulur; IMAGE_TAG env'den okunur
    stage('Helm Deploy') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        dir("${TG_DIR}") { sh 'terragrunt apply -input=false -auto-approve' }
      }
    }

    stage('Helm Destroy') {
      when { expression { params.ACTION == 'destroy' } }
      steps {
        dir("${TG_DIR}") { sh 'terragrunt destroy -input=false -auto-approve' }
      }
    }
  }
}
