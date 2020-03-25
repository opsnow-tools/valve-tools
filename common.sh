#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}')"

L_PAD=""

command -v fzf > /dev/null && FZF=true
command -v tput > /dev/null && TPUT=true

## Color     #define           Value  RGB
## black     COLOR_BLACK       0      0, 0, 0
## red       COLOR_RED         1      max,0,0
## green     COLOR_GREEN       2      0,max,0
## yellow    COLOR_YELLOW      3      max,max,0
## blue      COLOR_BLUE        4      0,0,max
## magenta   COLOR_MAGENTA     5      max,0,max
## cyan      COLOR_CYAN        6      0,max,max
## white     COLOR_WHITE       7      max,max,max
_echo() {
    if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
        echo -e "${L_PAD}$(tput setaf $2)$1$(tput sgr0)"
    else
        echo -e "${L_PAD}$1"
    fi
}

_read() {
    echo
    if [ "${3}" == "S" ]; then
        if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
            read -s -p "${L_PAD}$(tput setaf $2)$1$(tput sgr0)" ANSWER
        else
            read -s -p "${L_PAD}$1" ANSWER
        fi
    else
        if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
            read -p "${L_PAD}$(tput setaf $2)$1$(tput sgr0)" ANSWER
        else
            read -p "${L_PAD}$1" ANSWER
        fi
    fi
}

_replace() {
    if [ "${OS_NAME}" == "darwin" ]; then
        sed -i "" -e "$1" $2
    else
        sed -i -e "$1" $2
    fi
}

_warn() {
    _echo "# $@" 5
}

_debug() {
    if [ "${DEBUG_MODE}" == "true" ]; then
        echo "DEBUG)" $@
    fi
}

_debug_cat() {
    if [ "${DEBUG_MODE}" == "true" ]; then
        echo "DEBUG) 파일 경로 :" $@
        echo "DEBUG) ---------------------------------------------------------------------------"
        cat $@
        echo "DEBUG) ---------------------------------------------------------------------------"
    fi
}

_result() {
    _echo "# $@" 4
}

_command() {
    _echo "$ $@" 3
}

_success() {
    _echo "+ $@" 2
    _exit 0
}

_error() {
    _echo "- $@" 1
    _exit 1
}

_exit() {
    exit $1
}

question() {
    _read "${1:-"Enter your choice : "}" 6

    if [ ! -z ${2} ]; then
        if ! [[ ${ANSWER} =~ ${2} ]]; then
            ANSWER=
        fi
    fi
}

password() {
    _read "${1:-"Enter your password : "}" 6 S
}

select_one() {
    OPT=$1
    _debug "OPT="${OPT}

    SELECTED=

    CNT=$(cat ${LIST} | wc -l | xargs)
    if [ "x${CNT}" == "x0" ]; then
        return
    fi

    if [ "${OPT}" != "" ] && [ "x${CNT}" == "x1" ]; then
        SELECTED="$(cat ${LIST} | xargs)"
    else
        # if [ "${FZF}" != "" ]; then
        #     SELECTED=$(cat ${LIST} | fzf --reverse --no-mouse --height=10 --bind=left:page-up,right:page-down)
        # else
            echo

            IDX=0
            while read VAL; do
                IDX=$(( ${IDX} + 1 ))
                printf "%3s. %s\n" "${IDX}" "${VAL}"
            done < ${LIST}

            if [ "${CNT}" != "1" ]; then
                CNT="1-${CNT}"
            fi

            _read "Please select one. (${CNT}) : " 6

            if [ -z ${ANSWER} ]; then
                return
            fi
            TEST='^[0-9]+$'
            if ! [[ ${ANSWER} =~ ${TEST} ]]; then
                return
            fi
            SELECTED=$(sed -n ${ANSWER}p ${LIST})
        # fi
    fi
    _debug "SELECTED="${SELECTED}
}

progress() {
    if [ "$1" == "start" ]; then
        printf '%2s'
    elif [ "$1" == "end" ]; then
        printf '.\n'
    else
        printf '.'
        sleep 2
    fi
}

waiting() {
    SEC=${1:-2}

    echo
    progress start

    IDX=0
    while true; do
        if [ "${IDX}" == "${SEC}" ]; then
            break
        fi
        IDX=$(( ${IDX} + 1 ))
        progress ${IDX}
    done

    progress end
    echo
}

get_az_list() {
    if [ -z ${AZ_LIST} ]; then
        AZ_LIST="$(aws ec2 describe-availability-zones | jq -r '.AvailabilityZones[].ZoneName' | head -3 | tr -s '\r\n' ',' | sed 's/.$//')"
    fi
}

get_master_zones() {
    if [ "${master_count}" == "1" ]; then
        master_zones=$(echo "${AZ_LIST}" | cut -d',' -f1)
    else
        master_zones="${AZ_LIST}"
    fi
}

get_node_zones() {
    if [ "${node_count}" == "1" ]; then
        zones=$(echo "${AZ_LIST}" | cut -d',' -f1)
    else
        zones="${AZ_LIST}"
    fi
}

get_template() {
    _debug "템플릿으로 사용할 차트 파일을 복사 또는 github에서 다운로드 받는다."
    __FROM=${SHELL_DIR}/${1}
    __DIST=${2}
    _debug "__FROM="${__FROM}
    _debug "__DIST="${__DIST}

    _debug "mkdir -p ${SHELL_DIR}/build/${THIS_NAME}"
    mkdir -p ${SHELL_DIR}/build/${THIS_NAME}
    _debug "rm -rf ${__DIST}"
    rm -rf ${__DIST}

    _debug "소스 파일이 존재하고 정상이면 복사하고, 아니면 github(https://raw.githubusercontent.com/opsnow/valve-tools)에서 다운로드 받는다."
    _debug "공식 차트 사이트에서 제공하는 values.yaml이 아님!!! valve-tools에서 커스텀하게 작성한 파일입니다."
    _debug "참고 : curl -sL https://raw.githubusercontent.com/${THIS_REPO}/${THIS_NAME}/master/${1} > ${__DIST}"
    if [ -f ${__FROM} ]; then
        _debug "cat ${__FROM} > ${__DIST}"
        cat ${__FROM} > ${__DIST}
    else
        # 이 코드 블럭은 방어 코드로 보임, 소스 파일이 없다는거는 최신 버전의 valve-tools가 아니라는 의미인데...
        # 이때는 valve-tools를 최신 버전으로 받으라고 하고 프로그램을 종료시키는게 좋은 방법인거 같음.
        _debug "curl -sL https://raw.githubusercontent.com/${THIS_REPO}/${THIS_NAME}/master/${1} > ${__DIST}"
        curl -sL https://raw.githubusercontent.com/${THIS_REPO}/${THIS_NAME}/master/${1} > ${__DIST}
    fi

    if [ ! -f ${__DIST} ]; then
        _error "Template does not exists. [${1}]"
    fi
}

update_tools() {
    ${SHELL_DIR}/tools.sh

    _success "Please restart!"
}

update_self() {
    pushd ${SHELL_DIR}
    git pull
    popd

    _success "Please restart!"
}

logo() {
    if [ "${TPUT}" != "" ]; then
        # 화면 초기화
        tput clear
        # 노란색으로 출력
        tput setaf 3
    fi

cat << `EOF`
================================================================================
            _                 _              _     
__   ____ _| |_   _____      | |_ ___   ___ | |___ 
\ \ / / _` | \ \ / / _ \_____| __/ _ \ / _ \| / __|
 \ V / (_| | |\ V /  __/_____| || (_) | (_) | \__ \
  \_/ \__,_|_| \_/ \___|      \__\___/ \___/|_|___/
================================================================================
`EOF`

    if [ "${TPUT}" != "" ]; then
        # 모든 속성을 초기화
        tput sgr0
    fi

    if [ "${DEBUG_MODE}" == "true" ]; then
        _echo  "Running debug mode" 4
    fi
}

config_load() {
    _debug "kubectl get pod -n kube-system | wc -l | xargs"
    COUNT=$(kubectl get pod -n kube-system | wc -l | xargs)
    _debug "COUNT="${COUNT}

    if [ "x${COUNT}" == "x0" ]; then
        _error "Unable to connect to the cluster."
    fi

    _debug "kubectl get secret -n default | grep ${THIS_NAME}-config  | wc -l | xargs"
    COUNT=$(kubectl get secret -n default | grep ${THIS_NAME}-config  | wc -l | xargs)
    _debug "COUNT="${COUNT}

    if [ "x${COUNT}" != "x0" ]; then
        _command "mkdir -p ${SHELL_DIR}/build/${CLUSTER_NAME}"
        mkdir -p ${SHELL_DIR}/build/${CLUSTER_NAME}

        CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/config.sh

        _command "kubectl get secret ${THIS_NAME}-config -n default -o json | jq -r '.data.text' | base64 --decode > ${CONFIG}"
        kubectl get secret ${THIS_NAME}-config -n default -o json | jq -r '.data.text' | base64 --decode > ${CONFIG}

        _command "load ${THIS_NAME}-config"
        _debug_cat ${CONFIG}
        _echo "$(cat ${CONFIG})" 4

        _debug "${CONFIG} bash 파일을 실행한다."
        . ${CONFIG}
    fi
}

config_save() {
    _debug "config_save() 함수 시작"

    _debug "CONFIG_SAVE="${CONFIG_SAVE}
    if [ "${CONFIG_SAVE}" == "" ]; then
        _debug "CONFIG_SAVE 변수에 값이 없어 더이상 실행 안함."
        return
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/config.sh

    echo "# ${THIS_NAME} config" > ${CONFIG}
    echo "CLUSTER_NAME=${CLUSTER_NAME}" >> ${CONFIG}
    echo "ROOT_DOMAIN=${ROOT_DOMAIN}" >> ${CONFIG}
    echo "BASE_DOMAIN=${BASE_DOMAIN}" >> ${CONFIG}
    echo "ISTIO_DOMAIN=${ISTIO_DOMAIN}" >> ${CONFIG}
    echo "CERT_MAN=${CERT_MAN}" >> ${CONFIG}
    echo "EFS_ID=${EFS_ID}" >> ${CONFIG}
    echo "ISTIO=${ISTIO}" >> ${CONFIG}
    echo "CLUSTER_TYPE=${CLUSTER_TYPE}" >> ${CONFIG}

    _command "save ${THIS_NAME}-config"
    _echo "$(cat ${CONFIG})" 4

    ENCODED=${SHELL_DIR}/build/${CLUSTER_NAME}/config.txt

    if [ "${OS_NAME}" == "darwin" ]; then
        cat ${CONFIG} | base64 > ${ENCODED}
    else
        cat ${CONFIG} | base64 -w 0 > ${ENCODED}
    fi
    _debug "${CONFIG} 파일을 읽어서 base64 인코딩한 다음 ${ENCODED} 파일에 저장한다."
    _debug_cat ${ENCODED}

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/config.yaml

    get_template templates/config.yaml ${CONFIG}
    _debug "templates/config.yaml 파일을 ${CONFIG} 파일에 복사한다."
    _debug_cat ${CONFIG}

    _replace "s/REPLACE-ME/${THIS_NAME}-config/" ${CONFIG}
    _debug "REPLACE-ME 문자열을 ${THIS_NAME}-config 문자열로 변경한다."
    _debug_cat ${CONFIG}

    _debug "base64 인코딩된 파일(${ENCODED})에서 탭을 공백4개로 변환한 다음 ${CONFIG} 파일 뒤에 덧붙인다."
    sed "s/^/    /" ${ENCODED} >> ${CONFIG}
    _debug_cat ${CONFIG}

    _debug "config 설정을 default 네임스페이스에 설치한다."
    _command "kubectl apply -f ${CONFIG} -n default"
    TEMP_FILE=${SHELL_DIR}/build/${THIS_NAME}/temp
    kubectl apply -f ${CONFIG} -n default > ${TEMP_FILE}
    _result "$(cat ${TEMP_FILE})"

    # 변수를 초기화 한다. 다른 곳에서 이 변수에 값을 세팅하고 이 함수를 호출하면 동작하게 하기 위해서이다.
    CONFIG_SAVE=

    _debug "config_save() 함수 끝"
}

variables_domain() {
    __KEY=${1}
    __VAL=$(kubectl get ing --all-namespaces | grep devops | grep ${__KEY} | awk '{print $3}' | cut -d',' -f1)

    echo "@Field" >> ${CONFIG}
    echo "def ${__KEY} = \"${__VAL}\"" >> ${CONFIG}
}

variables_save() {
    _debug "variables_save() 함수 시작"
    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.groovy

    echo "#!/usr/bin/groovy" > ${CONFIG}
    echo "import groovy.transform.Field" >> ${CONFIG}

    echo "@Field" >> ${CONFIG}
    echo "def root_domain = \"${ROOT_DOMAIN}\"" >> ${CONFIG}

    echo "@Field" >> ${CONFIG}
    echo "def base_domain = \"${BASE_DOMAIN}\"" >> ${CONFIG}

    if [ "${CLUSTER_TYPE}" == "target-cluster" ]; then
        echo "@Field" >> ${CONFIG}
        echo "def cluster = \"${CLUSTER_NAME}\"" >> ${CONFIG}
    else
        echo "@Field" >> ${CONFIG}
        echo "def cluster = \"devops\"" >> ${CONFIG}

        variables_domain "chartmuseum"
        variables_domain "registry"
        variables_domain "jenkins"
        variables_domain "sonarqube"
        variables_domain "nexus"
        variables_domain "harbor"

        echo "@Field" >> ${CONFIG}
        echo "def harbor_project = \"${HARBOR_PROJECT}\"" >> ${CONFIG}
    fi

    echo "@Field" >> ${CONFIG}
    echo "def slack_token = \"\"" >> ${CONFIG}

    echo "return this" >> ${CONFIG}
    _debug_cat ${CONFIG}

    ENCODED=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.txt

    if [ "${OS_NAME}" == "darwin" ]; then
        cat ${CONFIG} | base64 > ${ENCODED}
    else
        cat ${CONFIG} | base64 -w 0 > ${ENCODED}
    fi

    CONFIG=${SHELL_DIR}/build/${CLUSTER_NAME}/variables.yaml
    get_template templates/groovy.yaml ${CONFIG}

    _replace "s/REPLACE-ME/groovy-variables/" ${CONFIG}

    sed "s/^/    /" ${ENCODED} >> ${CONFIG}
    _debug_cat ${CONFIG}

    _command "kubectl apply -f ${CONFIG} -n default"
    TEMP_FILE=${SHELL_DIR}/build/${THIS_NAME}/temp
    kubectl apply -f ${CONFIG} -n default > ${TEMP_FILE}
    _result "$(cat ${TEMP_FILE})"

    _debug "variables_save() 함수 끝"
}
