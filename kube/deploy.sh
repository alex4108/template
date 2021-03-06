#!/usr/bin/env bash
set -u
set -x

chkErr() { 
    if [[ "$?" -gt "0" ]]; then
        echo "Error occured!"
        exit 1
    fi
}


kube_env=$(echo "${ENV}" | awk '{print tolower($0)}')
chkErr
K8S_DEPLOYMENT_NAME="${PROJECT_NAME}-${ENV}"
chkErr
runDocker="docker run -v ${TRAVIS_BUILD_DIR}/kube:/kube bitnami/kubectl:latest"
chkErr
kubeFlags="--kubeconfig /kube/kubeconfig --insecure-skip-tls-verify=true"
kubectl="${runDocker} ${kubeFlags}"
chkErr


sed -i -e "s|ENVIRONMENT|${ENV}|g" deployment.yml
sed -i -e "s|environment|${kube_env}|g" deployment.yml
sed -i -e "s|COMMIT|${TRAVIS_COMMIT}|g" deployment.yml
sed -i -e "s|PROJECT_NAME|${PROJECT_NAME}|g" deployment.yml
sed -i -e 's|DEPLOYMENT_NAME|'"${K8S_DEPLOYMENT_NAME}"'|g' deployment.yml
sed -i -e 's|DOCKER_USER|'"${DOCKER_USER}"'|g' deployment.yml
sed -i -e 's|KUBE_CA_CERT|'"${KUBE_CA_CERT}"'|g' kubeconfig
sed -i -e 's|KUBE_ENDPOINT|'"${KUBE_ENDPOINT}"'|g' kubeconfig
sed -i -e 's|KUBE_ADMIN_CERT|'"${KUBE_ADMIN_CERT}"'|g' kubeconfig
sed -i -e 's|KUBE_ADMIN_KEY|'"${KUBE_ADMIN_KEY}"'|g' kubeconfig
chkErr

kubeFlags="--kubeconfig /kube/kubeconfig --insecure-skip-tls-verify=true"

${kubectl} delete secret ${K8S_DEPLOYMENT_NAME}-docker
${kubectl} delete secret ${K8S_DEPLOYMENT_NAME}-discord
${kubectl} create secret docker-registry ${K8S_DEPLOYMENT_NAME}-docker --docker-server=https://index.docker.io/v2/ --docker-username=${DOCKER_USER} --docker-password=\"${DOCKER_PASS}\" --docker-email=${DOCKER_EMAIL} 
chkErr
${kubectl} create secret generic ${K8S_DEPLOYMENT_NAME}-${kube_env}-discord --from-literal=username="discord" --from-literal=password="${BOT_TOKEN}"
chkErr
${kubectl} apply -f /kube/deployment.yml
chkErr

${kubectl} rollout status deployment ${K8S_DEPLOYMENT_NAME}


if ! ${kubectl} rollout status deployment ${K8S_DEPLOYMENT_NAME}; then
    ${kubectl} rollout undo deployment ${K8S_DEPLOYMENT_NAME}
    ${kubectl} rollout status deployment ${K8S_DEPLOYMENT_NAME}
    exit 1
fi
