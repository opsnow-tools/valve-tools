#!/bin/bash

SHELL_DIR=$(dirname $0)

PARENT_DIR=$(dirname $(dirname ${SHELL_DIR}))

. ${PARENT_DIR}/default.sh
. ${PARENT_DIR}/common.sh

################################################################################
_debug "job.sh 스크립트 시작"

CHART=${1:-${PARENT_DIR}/build/${THIS_NAME}-jenkins.yaml}
CHART_TMP=${PARENT_DIR}/build/${THIS_NAME}-jenkins-tmp.yaml
TMP_DIR=${PARENT_DIR}/build/${THIS_NAME}-jenkins
_debug "CHART=${CHART}"
_debug "CHART_TMP=${CHART_TMP}"
_debug "TMP_DIR=${TMP_DIR}"

rm -rf ${TMP_DIR} ${CHART_TMP} && mkdir -p ${TMP_DIR}

# job list
JOB_LIST=${PARENT_DIR}/build/${THIS_NAME}-jenkins-job-list
ls ${SHELL_DIR}/jobs/ > ${JOB_LIST}
_debug "JOB_LIST=${JOB_LIST}"
_debug_cat ${JOB_LIST}

while read JOB; do
    _debug "--------------------------------------------------"
    mkdir -p ${TMP_DIR}/${JOB}
    _debug "mkdir -p ${TMP_DIR}/${JOB}"

    ORIGIN=${SHELL_DIR}/jobs/${JOB}/Jenkinsfile
    TARGET=${TMP_DIR}/${JOB}/Jenkinsfile
    CONFIG=${TMP_DIR}/${JOB}/config.xml
    _debug "ORIGIN=${ORIGIN}"
    _debug "TARGET=${TARGET}"
    _debug "CONFIG=${CONFIG}"

    # Jenkinsfile
    if [ -f ${ORIGIN} ]; then
        cp -rf ${ORIGIN} ${TARGET}
        _replace "s/\"/\&quot;/g" ${TARGET}
        _replace "s/</\&lt;/g" ${TARGET}
        _replace "s/>/\&gt;/g" ${TARGET}
    else
        touch ${TARGET}
    fi

    # Jenkinsfile >> config.xml
    while read LINE; do
        if [ "${LINE}" == "REPLACE" ]; then
            cat ${TARGET} >> ${CONFIG}
        else
            echo "${LINE}" >> ${CONFIG}
        fi
    done < ${SHELL_DIR}/jobs/${JOB}/config.xml
done < ${JOB_LIST}

# config.yaml >> jenkins.yaml
POS=$(grep -n "jenkins-jobs -- start" ${CHART} | cut -d':' -f1)

sed "${POS}q" ${CHART} >> ${CHART_TMP}

echo
echo "  Jobs:" >> ${CHART_TMP}

while read JOB; do
    echo "> ${JOB}"
    echo "    ${JOB}: |-" >> ${CHART_TMP}

    sed -e "s/^/      /" ${TMP_DIR}/${JOB}/config.xml >> ${CHART_TMP}
done < ${JOB_LIST}

sed "1,${POS}d" ${CHART} >> ${CHART_TMP}

# done
cp -rf ${CHART_TMP} ${CHART}

_debug "job.sh 스크립트 끝"