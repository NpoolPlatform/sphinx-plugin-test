pipeline {
  agent any
  environment {
    GOPROXY = 'https://goproxy.cn,direct'
  }
  tools {
    go 'go'
  }
  stages {
    stage('Clone sphinx plugin') {
      steps {
        git(url: scm.userRemoteConfigs[0].url, branch: '$BRANCH_NAME', changelog: true, credentialsId: 'KK-github-key', poll: true)
      }
    }

    stage('Build sphinx plugin image') {
      when {
        expression { BUILD_TARGET == 'true' }
      }
      steps {
        sh(returnStdout: true, script: '''
          images=`docker images | grep entropypool | grep sphinx-plugin | awk '{ print $3 }'`
          for image in $images; do
            docker rmi $image -f
          done
        '''.stripIndent())
        sh 'docker build -t $DOCKER_REGISTRY/entropypool/sphinx-plugin:latest . --build-arg=ALL_PROXY=$all_proxy'
      }
    }

    stage('Release sphinx plugin image') {
      when {
        expression { RELEASE_TARGET == 'true' }
      }
      steps {
        sh(returnStdout: true, script: '''
          set +e
          while true; do
            docker push $DOCKER_REGISTRY/entropypool/sphinx-plugin:latest
            if [ $? -eq 0 ]; then
              break
            fi
          done
          set -e
        '''.stripIndent())
      }
    }

    stage('Deploy sphinx plugin') {
      when {
        expression { DEPLOY_TARGET == 'true' }
      }
      steps {
        sh 'rm -rf /tmp/sphinx-plugin-deployment'
        sh 'git clone https://github.com/NpoolPlatform/sphinx-plugin-deployment.git /tmp/sphinx-plugin-deployment'
        sh 'sed -i \'/\'$COIN_TYPE\'/a\\\'$DEPLOY_IP\'\' /tmp/sphinx-plugin-deployment/hosts'
        sh 'sed -i \'s/=user/=\'$DEPLOY_USER\'/g\' /tmp/sphinx-plugin-deployment/hosts'
        sh 'sed -i \'s/=pass/=\'$DEPLOY_PASS\'/g\' /tmp/sphinx-plugin-deployment/hosts'
        sh 'sed -i \'s/rpcuser/\'$RPC_USER\'/g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'sed -i \'s/rpcpassword/\'$RPC_PASSWORD\'/g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'sed -i \'s/btcversion/\'$BTC_VERSION\'/g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'sed -i \'s/sphinxproxyapi/\'$SPHINX_PROXY_API\'/g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'sed -i \'s/traefikip/\'$TRAEFIK_IP\'/g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'sed -i \'s#datadir#\'$DATADIR\'#g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'sed -i \'s#allproxy#\'$all_proxy\'#g\' /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
        sh 'ansible-playbook -i /tmp/sphinx-plugin-deployment/hosts /tmp/sphinx-plugin-deployment/$COIN_TYPE-config.yml'
      }
    }
  }

  post('Report') {
    fixed {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh fixed')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/success_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
    success {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh successful')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/success_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
    failure {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh failure')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/fail_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
    aborted {
      script {
        sh(script: 'bash $JENKINS_HOME/wechat-templates/send_wxmsg.sh aborted')
     }
      script {
        // env.ForEmailPlugin = env.WORKSPACE
        emailext attachmentsPattern: 'TestResults\\*.trx',
        body: '${FILE,path="$JENKINS_HOME/email-templates/fail_email_tmp.html"}',
        mimeType: 'text/html',
        subject: currentBuild.currentResult + " : " + env.JOB_NAME,
        to: '$DEFAULT_RECIPIENTS'
      }
     }
  }
}
