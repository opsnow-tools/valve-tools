#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}')"

SHELL_DIR=$(dirname $0)

RUN_PATH="."

CMD=${1:-$CIRCLE_JOB}

PARAM=${2}

USERNAME=${CIRCLE_PROJECT_USERNAME}
REPONAME=${CIRCLE_PROJECT_REPONAME}

BRANCH=${CIRCLE_BRANCH:-master}

# PR_NUM=${CIRCLE_PR_NUMBER}
PR_URL=${CIRCLE_PULL_REQUEST}

DOCKER_USER=${DOCKER_USER:-$USERNAME}
DOCKER_PASS=${DOCKER_PASS}
DOCKER_IMAGE="${DOCKER_IMAGE:-$DOCKER_USER/$REPONAME}"

CIRCLE_BUILDER=${CIRCLE_BUILDER}

# CIRCLE_BUILDER=
# DOCKER_USER=
# DOCKER_PASS=
# GITHUB_TOKEN=
# PERSONAL_TOKEN=
# PUBLISH_PATH=
# SLACK_TOKEN=

################################################################################

# command -v tput > /dev/null && TPUT=true
TPUT=

_echo() {
    if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
        echo -e "$(tput setaf $2)$1$(tput sgr0)"
    else
        echo -e "$1"
    fi
}

_result() {
    echo
    _echo "# $@" 4
}

_command() {
    echo
    _echo "$ $@" 3
}

_success() {
    echo
    _echo "+ $@" 2
    exit 0
}

_error() {
    echo
    _echo "- $@" 1
    exit 1
}

_replace() {
    if [ "${OS_NAME}" == "darwin" ]; then
        sed -i "" -e "$1" $2
    else
        sed -i -e "$1" $2
    fi
}

_prepare() {
    # target
    mkdir -p ${RUN_PATH}/target/publish
    mkdir -p ${RUN_PATH}/target/release

    if [ -f ${RUN_PATH}/target/circleci-stop ]; then
        _success "circleci-stop"
    fi
}

_package() {
    if [ ! -f ${RUN_PATH}/VERSION ]; then
        _error "not found VERSION"
    fi

    _result "BRANCH=${BRANCH}"

    # release version
    MAJOR=$(cat ${RUN_PATH}/VERSION | xargs | cut -d'.' -f1)
    MINOR=$(cat ${RUN_PATH}/VERSION | xargs | cut -d'.' -f2)
    BUILD=$(cat ${RUN_PATH}/VERSION | xargs | cut -d'.' -f3)

    if [ "${BUILD}" != "x" ]; then
        VERSION="${MAJOR}.${MINOR}.${BUILD}"
        printf "${VERSION}" > ${RUN_PATH}/target/VERSION
    else
        # latest versions
        GITHUB="https://api.github.com/repos/${USERNAME}/${REPONAME}/releases"
        VERSION=$(curl -s ${GITHUB} | grep "tag_name" | grep "${MAJOR}.${MINOR}." | head -1 | cut -d'"' -f4 | cut -d'-' -f1)

        if [ -z ${VERSION} ]; then
            VERSION="${MAJOR}.${MINOR}.0"
        fi

        _result "VERSION=${VERSION}"

        # new version
        if [ "${BRANCH}" == "master" ]; then
            VERSION=$(echo ${VERSION} | perl -pe 's/^(([v\d]+\.)*)(\d+)(.*)$/$1.($3+1).$4/e')
            printf "${VERSION}" > ${RUN_PATH}/target/VERSION
        else
            PR=$(echo "${BRANCH}" | cut -d'/' -f1)

            if [ "${PR_NUM}" != "" ] || [ "${PR_URL}" != "" ] || [ "${PR}" == "pull" ]; then
                printf "${PR}" > ${RUN_PATH}/target/PR

                if [ "${PR_NUM}" == "" ] && [ "${PR_URL}" != "" ]; then
                    PR_NUM=$(echo "${PR_URL}" | cut -d'/' -f7)
                fi
                if [ "${PR_NUM}" == "" ]; then
                    PR_NUM=$(echo "${BRANCH}" | cut -d'/' -f2)
                fi
                if [ "${PR_NUM}" == "" ]; then
                    PR_NUM=${CIRCLE_BUILD_NUM}
                fi

                if [ "${PR_NUM}" != "" ]; then
                    VERSION="${VERSION}-${PR_NUM}"
                    printf "${VERSION}" > ${RUN_PATH}/target/VERSION
                else
                    VERSION=
                fi
            else
                VERSION=
            fi
        fi
    fi

    _result "PR_NUM=${PR_NUM}"
    _result "PR_URL=${PR_URL}"

    _result "VERSION=${VERSION}"
}

_publish() {
    if [ "${BRANCH}" != "master" ]; then
        _result "BRANCH : ${BRANCH}"
        return
    fi
    if [ -z ${PUBLISH_PATH} ]; then
        _result "PUBLISH_PATH : ${PUBLISH_PATH}"
        return
    fi
    if [ ! -f ${RUN_PATH}/target/VERSION ]; then
        _result "${RUN_PATH}/target/VERSION"
        return
    fi
    if [ -f ${RUN_PATH}/target/PR ]; then
        _result "${RUN_PATH}/target/PR"
        return
    fi

    BUCKET="$(echo "${PUBLISH_PATH}" | cut -d'/' -f1)"

    # aws s3 sync
    _command "aws s3 sync ${RUN_PATH}/target/publish/ s3://${PUBLISH_PATH}/ --acl public-read"
    aws s3 sync ${RUN_PATH}/target/publish/ s3://${PUBLISH_PATH}/ --acl public-read

    # aws cf reset
    CFID=$(aws cloudfront list-distributions --query "DistributionList.Items[].{Id:Id,Origin:Origins.Items[0].DomainName}[?contains(Origin,'${BUCKET}')] | [0]" | grep 'Id' | cut -d'"' -f4)
    if [ "${CFID}" != "" ]; then
        aws cloudfront create-invalidation --distribution-id ${CFID} --paths "/*"
    fi
}

_release() {
    if [ -z ${GITHUB_TOKEN} ]; then
        return
    fi
    if [ ! -f ${RUN_PATH}/target/VERSION ]; then
        return
    fi

    VERSION=$(cat ${RUN_PATH}/target/VERSION | xargs)
    _result "VERSION=${VERSION}"

    printf "${VERSION}" > ${RUN_PATH}/target/release/${VERSION}

    if [ -f ${RUN_PATH}/target/PR ]; then
        GHR_PARAM="-delete -prerelease"
    else
        GHR_PARAM="-delete"
    fi

    _command "go get github.com/tcnksm/ghr"
    go get github.com/tcnksm/ghr

    # github release
    _command "ghr -t ${GITHUB_TOKEN:-EMPTY} -u ${USERNAME} -r ${REPONAME} -c ${CIRCLE_SHA1} ${GHR_PARAM} ${VERSION} ${RUN_PATH}/target/release/"
    ghr -t ${GITHUB_TOKEN:-EMPTY} \
        -u ${USERNAME} \
        -r ${REPONAME} \
        -c ${CIRCLE_SHA1} \
        ${GHR_PARAM} \
        ${VERSION} ${RUN_PATH}/target/release/
}

_docker() {
    if [ -z ${DOCKER_PASS} ]; then
        return
    fi
    if [ ! -f ${RUN_PATH}/target/VERSION ]; then
        return
    fi

    VERSION=$(cat ${RUN_PATH}/target/VERSION | xargs)
    _result "VERSION=${VERSION}"

    _command "docker login -u $DOCKER_USER"
    docker login -u $DOCKER_USER -p $DOCKER_PASS

    _command "docker build -t ${DOCKER_IMAGE}:${VERSION} ."
    docker build -f ${PARAM:-Dockerfile} -t ${DOCKER_IMAGE}:${VERSION} .

    _command "docker push ${DOCKER_IMAGE}:${VERSION}"
    docker push ${DOCKER_IMAGE}:${VERSION}

    _command "docker logout"
    docker logout
}

_trigger() {
    if [ -z ${CIRCLE_BUILDER} ]; then
        return
    fi
    if [ -z ${PERSONAL_TOKEN} ]; then
        return
    fi
    if [ ! -f ${RUN_PATH}/target/VERSION ]; then
        return
    fi

    VERSION=$(cat ${RUN_PATH}/target/VERSION | xargs)
    _result "VERSION=${VERSION}"

    CIRCLE_API="https://circleci.com/api/v1.1/project/github/${CIRCLE_BUILDER}"
    CIRCLE_URL="${CIRCLE_API}?circle-token=${PERSONAL_TOKEN}"

    PAYLOAD="{\"build_parameters\":{"
    PAYLOAD="${PAYLOAD}\"TG_USERNAME\":\"${USERNAME}\","
    PAYLOAD="${PAYLOAD}\"TG_PROJECT\":\"${REPONAME}\","
    PAYLOAD="${PAYLOAD}\"TG_VERSION\":\"${VERSION}\""
    PAYLOAD="${PAYLOAD}}}"

    curl -X POST \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}" "${CIRCLE_URL}"
}

_slack() {
    if [ -z ${SLACK_TOKEN} ]; then
        return
    fi
    if [ ! -f ${RUN_PATH}/target/VERSION ]; then
        return
    fi

    VERSION=$(cat ${RUN_PATH}/target/VERSION | xargs)
    _result "VERSION=${VERSION}"

    # send slack
    curl -sL opspresso.com/tools/slack | bash -s -- \
        --token="${SLACK_TOKEN}" --username="${USERNAME}" \
        --footer="<https://github.com/${USERNAME}/${REPONAME}/releases/tag/${VERSION}|${USERNAME}/${REPONAME}>" \
        --footer_icon="https://repo.opspresso.com/favicon/github.png" \
        --color="good" --title="${REPONAME}" "\`${VERSION}\`"
}

################################################################################

_prepare

case ${CMD} in
    build|package)
        _package
        ;;
    publish)
        _publish
        ;;
    release)
        _release
        ;;
    docker)
        _docker
        ;;
    trigger)
        _trigger
        ;;
    slack)
        _slack
        ;;
esac

_success
