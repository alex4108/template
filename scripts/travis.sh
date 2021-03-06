#!/usr/bin/env bash
set -e
set -o pipefail
set -x

export PROJECT_NAME=""

if [[ "${PROJECT_NAME}" == "" ]]; then
    echo "D'oh!  Set the name fool!"
fi

DOCKER_PLATFORMS="linux/amd64,linux/arm/v7,linux/arm/v8"

# Test the code
cd ${TRAVIS_BUILD_DIR}/src
pip3 install -r requirements.txt
python3 bot.py

# Build the container
cd ${TRAVIS_BUILD_DIR}
docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}

if [[ "${TRAVIS_PULL_REQUEST}" == "false" && "${TRAVIS_BRANCH}" == "main" ]]; then # This is a push to master
    export ENV=LIVE
elif [[ "${TRAVIS_PULL_REQUEST}" == "false" ]]; then
    export ENV=TEST
else 
    echo "Exiting early because I don't deploy pull requests"
    exit 0
fi

DOCKER_TAG="${DOCKER_USER}/${PROJECT_NAME}:v2-${TRAVIS_COMMIT}"
docker buildx create --use
docker buildx build --platform ${DOCKER_PLATFORMS} -t ${DOCKER_TAG} . --push


# Deploy to k8s
cd ${TRAVIS_BUILD_DIR}/kube
bash deploy.sh
