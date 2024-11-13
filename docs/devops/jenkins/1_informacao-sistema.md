# Informações sobre o jenkis

> **“Entrega sob Qualidade.”**

## **O que é**

Jenkins é uma ferramenta de automação open-source que permite a **integração contínua** (CI) e a **entrega contínua** (CD) de software. Uma ferramenta que cria automações auditáveis dos processos repetitivos no desenvolvimente como compilação, testes e implatações das nossas aplicações.

## **Funcionalidades**

Jenkins é uma das ferramentas mais populares para CI/CD, devido à sua flexibilidade e facilidade de uso. Com ele, você pode configurar pipelines automatizados que são responsáveis por:

- :material-code-braces: **Compilar o código** sempre que novas mudanças são feitas.
- :material-play-circle: **Executar testes automatizados** para garantir que o código funciona corretamente.
- :material-cloud-upload: **Implantar o software** em diferentes ambientes de produção ou desenvolvimento.

  Nota(1):man_raising_hand:
  { .annotate }

1.  :man_raising_hand: A compilação e implatação automática por pull request, ou webhooks, não é implementada em nenhum processo pipeline, sendo a única fase da esteira de produção de software!

# Principais Usos do Jenkins

### 1. **Integração Contínua (CI)**

Jenkins permite integrar código constantemente em um repositório compartilhado, garantindo que a base de código esteja sempre em um estado funcional. Isso reduz o risco de falhas no software e melhora a colaboração entre as equipes.

> **Nota:** A integração contínua ajuda a detectar problemas mais cedo, promovendo maior estabilidade na aplicação.

### 2. **Entrega Contínua (CD)**

Além de compilar e testar o código, Jenkins pode ser configurado para automaticamente implantar a aplicação em ambientes de teste ou produção.

> **Nota:** O CD reduz o tempo entre as alterações no código e sua disponibilidade para o usuário final.

### 3. **Automação de Testes**

Com Jenkins, é possível configurar a execução de testes automatizados toda vez que o código é alterado. Isso assegura que novos bugs sejam detectados rapidamente.

> **Nota:** A automação de testes reduz erros manuais e melhora a qualidade do código.

### 4. **Automação de Build**

Jenkins pode ser integrado com sistemas de build, como Maven ou Gradle, para automatizar a criação de pacotes executáveis a partir do código-fonte.

> **Nota:** A automação de builds permite uma produção mais eficiente e confiável.

### 5. **Monitoramento de Builds**

Com a interface de usuário do Jenkins, é possível monitorar o status dos builds e pipelines, identificar falhas e acompanhar o progresso das tarefas.

> **Aviso:** Fique atento às falhas e erros de logs dos builds para evitar problemas posteriores em produção.

## Exemplo Prático

### **Pipeline de construção do ambiente de homologação de uma das aplicações do sebrae**

Nota (1)
{.annotate}

1.  :man_raising_hand: A construção desse pipeline e suas peculiariedade estão documentadas na sessão Pipeline->Projeto facilita!

```groovy
pipeline {
    agent { label 'RRSRVWORKER' }

    parameters {
        text(name: 'NEW_DOCKER_TAG', defaultValue: '', description: 'Tag da imagem que será criada para o push no projeto harbor')
        text(name: 'OLD_DOCKER_TAG', defaultValue: '', description: 'Tag antiga, é necessário informá-la para alterar a sua label para {Deprecated} no harbor')
    }

    environment {
        ARGOCD_SERVER = 'argocd.rr.sebrae.com.br'  // Substitua pelo seu servidor ArgoCD
    }

    stages {
        stage('Validando parâmetros'){
             steps {
                script {

                    def versionPattern = /^v\d+\.\d+\.\d+$/

                    if (!params.NEW_DOCKER_TAG?.trim()) {
                        error "O parâmetro NEW_DOCKER_TAG é obrigatório e não foi preenchido."
                    } else if (!params.NEW_DOCKER_TAG.trim().matches(versionPattern)) {
                        error "O parâmetro NEW_DOCKER_TAG deve seguir o formato v*.*.* (exemplo: v1.0.0)."
                    }
                }
            }
        }

        stage('Clonando Repositório') {
            steps {
                git branch: 'dev', url: 'https://github.com/rodrigolacan/FACILITA.git'
            }
        }

        stage('Instalando Dependências') {
            steps {
                script {
                    sh 'composer install --no-interaction'
                }
            }
        }

        stage('Testes PHP UNIT') {
            steps {
                script {
                    try {
                        sh 'php artisan test'
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        throw e
                    }
                }
            }
        }

        stage('Realizando push da imagem Docker'){
            steps{
               script{
                    sh "bash -c 'docker buildx build -t facilita:${params.NEW_DOCKER_TAG} .'"
                    sh "bash -c 'docker tag facilita:${params.NEW_DOCKER_TAG} harbor.rr.sebrae.com.br/sebrae.rr.facilita.homolog/facilita:${params.NEW_DOCKER_TAG}'"
                    sh "bash -c 'docker push harbor.rr.sebrae.com.br/sebrae.rr.facilita.homolog/facilita:${params.NEW_DOCKER_TAG}'"
                    sh "bash -c 'docker rmi -f facilita:${params.DOCKER_TAG}'"
                    sh "bash -c 'docker rmi -f harbor.rr.sebrae.com.br/sebrae.rr.facilita.homolog/facilita:${params.NEW_DOCKER_TAG} '"
                    sh "bash -c 'docker image prune -f'"

                    // Definindo o comando curl
                    // Comando que define a label de Last Stable Version para a NOVA versão da imagem docker

                    def newTagDocker = """
                        curl -k -X POST "https://harbor.rr.sebrae.com.br/api/v2.0/projects/sebrae.rr.facilita.homolog/repositories/facilita/artifacts/${params.NEW_DOCKER_TAG}/labels" \\
                        -H "Authorization: Basic a1g12hazxF1239Aaja131Adfavb==" \\
                        -H "Content-Type: application/json" \\
                        -d '
                            {
                                "color": "#1D5100",
                                "creation_time": "2024-11-06T17:50:39.818Z",
                                "description": "última versão estável em homologação",
                                "id": 18,
                                "name": "Last Stable Version Homolog",
                                "scope": "g",
                                "update_time": "2024-11-06T17:50:39.818Z"
                            }'
                    """
                        // Executando o comando curl
                        def response1 = sh(script: newTagDocker, returnStdout: true).trim()

                        // Exibindo a resposta
                        echo "Response: ${response1}"

                    if(params.OLD_DOCKER_TAG?.trim()){

                        // Definindo o comando curl
                        // Comando que define a label de Deprecated para a antiga versão da imagem docker
                        def oldTagDocker = """
                            curl -k -X POST "https://harbor.rr.sebrae.com.br/api/v2.0/projects/sebrae.rr.facilita.homolog/repositories/facilita/artifacts/${params.OLD_DOCKER_TAG}/labels" \\
                            -H "Authorization: Basic a1g12hazxF1239Aaja131Adfavb==" \\
                            -H "Content-Type: application/json" \\
                            -d '{
                                    "color": "#FF5501",
                                    "creation_time": "2024-11-06T18:00:22.441Z",
                                    "description": "Versão funcional mas que não está atualmente em homologação",
                                    "id": 21,
                                    "name": " Deprecated Version Homolog",
                                    "scope": "g",
                                    "update_time": "2024-11-06T18:00:22.441Z"
                                }'
                            """

                        // Executando o comando curl
                        def response2 = sh(script: oldTagDocker, returnStdout: true).trim()

                        // Exibindo a resposta
                        echo "Response: ${response2}"
                    }
                    cleanWs()
               }
            }
        }

        stage('Alterar versão da imagem no Argocd'){
            steps{
                script{
                    git branch: 'dev', url: 'git@github.com:rodrigolacan/Argocd.git', credentialsId: 'argocd-ssh-github'

                    sh 'git reset --hard'
                    sh 'git fetch origin'
                    sh 'git branch --set-upstream-to=origin/dev dev'
                    sh 'git pull'


                    def deploymentFilePath = 'RR.SEBRAE.CLUSTER/facilita-homolog/deployment.yaml'

                    // Comando sed para atualizar a versão da imagem
                    sh """
                    sed -i 's|image: harbor\\.rr\\.sebrae\\.com\\.br/sebrae\\.rr\\.facilita\\.homolog/facilita:v.*|image: harbor.rr.sebrae.com.br/sebrae.rr.facilita.homolog/facilita:${params.NEW_DOCKER_TAG}|' ${deploymentFilePath}
                    """

                    // Exibe o arquivo modificado
                    sh "cat ${deploymentFilePath}"

                    sh 'git add .'
                    sh 'git commit -m "jenkins-deploy: Subindo nova imagem docker para homologação"'
                    sh 'git push origin dev'

                    sh 'git checkout main'
                    sh 'git merge dev'
                    sh 'git push origin main'

                    cleanWs()
                }
            }
        }

        stage('Sincronizando application no kubernetes'){
            steps{
                script{

                    withCredentials([usernamePassword(credentialsId: 'argocd-credentials-login', usernameVariable: 'ARGOCD_USERNAME', passwordVariable: 'ARGOCD_PASSWORD')]) {

                        sh """
                            argocd login $ARGOCD_SERVER --username $ARGOCD_USERNAME --password \$ARGOCD_PASSWORD --insecure
                            argocd app sync facilita-homologacao --grpc-web
                        """
                    }
                    cleanWs()
                }
            }
        }


    }

    post {
        always {
            echo 'Pipeline Finalizado'
        }
        failure {
            echo 'Falha na construção do Pipeline'
        }
    }
}


```
