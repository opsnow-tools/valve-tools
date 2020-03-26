#!/bin/bash

SHELL_DIR=$(dirname $0)

. ${SHELL_DIR}/common.sh
. ${SHELL_DIR}/default.sh

################################################################################

title() {
    if [ "${TPUT}" != "" ]; then
        tput clear
    fi
    logo
    #_echo "${THIS_NAME}" 3
    _echo "K8s Cluster Name : ${CLUSTER_NAME}" 4
}

prepare() {
    logo

    mkdir -p ~/.ssh
    mkdir -p ~/.aws
    mkdir -p ${SHELL_DIR}/build/${THIS_NAME}

    NEED_TOOL=
    command -v jq > /dev/null      || export NEED_TOOL=jq
    command -v git > /dev/null     || export NEED_TOOL=git
    command -v aws > /dev/null     || export NEED_TOOL=awscli
    command -v kubectl > /dev/null || export NEED_TOOL=kubectl
    command -v helm > /dev/null    || export NEED_TOOL=helm

    if [ ! -z ${NEED_TOOL} ]; then
        question "Do you want to install the required tools? (awscli,kubectl,helm...) [Y/n] : "

        if [ "${ANSWER:-Y}" == "Y" ]; then
            ${SHELL_DIR}/tools.sh
        else
            _error "Need install tools."
        fi
    fi

    REGION="$(aws configure get region)"
}

# 시작 함수(entry point)
run() {
    prepare
    get_cluster
    config_load
    select_cluster_type
    main_menu
}

press_enter() {
    _result "$(date)"

    _read "Press Enter to continue..." 5
    echo

    case ${1} in
        main)
            main_menu
            ;;
        kube-ingress)
            charts_menu "kube-ingress"
            ;;
        kube-system)
            charts_menu "kube-system"
            ;;
        monitor)
            charts_menu "monitor"
            ;;
        devops)
            charts_menu "devops"
            ;;
        sample)
            charts_menu "sample"
            ;;
        batch)
            charts_menu "batch"
            ;;
        harbor)
            charts_menu "harbor"
            ;;
        istio)
            istio_menu
            ;;
    esac
}

main_menu() {
    title

    echo
    _echo "1. helm init"
    echo
    _echo "2. kube-ingress.."
    _echo "3. kube-system.."
    _echo "4. monitor.."
    _echo "5. devops.."
    _echo "6. sample.."
    _echo "7. batch.."
    _echo "8. harbor.."
    echo
    _echo "i. istio.."
    echo
    _echo "d. remove"
    echo
    _echo "c. check PV"
    _echo "v. save variables"
    echo
    _echo "u. update self"
    _echo "t. update tools"
    echo
    _echo "x. Exit"

    question

    case ${ANSWER} in
        1)
            helm_init
            press_enter main
            ;;
        2)
            charts_menu "kube-ingress"
            ;;
        3)
            charts_menu "kube-system"
            ;;
        4)
            charts_menu "monitor"
            ;;
        5)
            charts_menu "devops"
            ;;
        6)
            charts_menu "sample"
            ;;
        7)
            charts_menu "batch"
            ;;
        8)
            charts_menu "harbor"
            ;;
        i)
            istio_menu
            ;;
        d)
            helm_delete
            press_enter main
            ;;
        c)
            validate_pv
            press_enter main
            ;;
        v)
            variables_save
            press_enter main
            ;;
        u)
            update_self
            press_enter cluster
            ;;
        t)
            update_tools
            press_enter cluster
            ;;
        x)
            _success "Good bye!"
            ;;
        *)
            main_menu
            ;;
    esac
}

listup_ing_rules() {
    SERVICE_NAME="nginx-ingress-private-controller"
    ELB_DNS=$(kubectl -n kube-ingress get svc ${SERVICE_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    ELB_ID=$(echo ${ELB_DNS} | cut -d'-' -f 1)

    SG_ID=$(aws elb describe-load-balancers --load-balancer-name ${ELB_ID} | jq -r '.LoadBalancerDescriptions[] | .SecurityGroups[]')

    _command "aws ec2 describe-security-groups --group-id ${SG_ID} | jq -r '.SecurityGroups[] | .IpPermissions'"
    export SG_INGRESS_RULE=$(aws ec2 describe-security-groups --group-id ${SG_ID} | jq -r '.SecurityGroups[] | .IpPermissions')

    echo $SG_INGRESS_RULE
}

remove_ing_rule() {

    listup_ing_rules
    ALL_RULE=$(echo $SG_INGRESS_RULE | jq -rc . )

    _command "aws ec2 revoke-security-group-ingress --group-id $SG_ID --ip-permissions $ALL_RULE"
    aws ec2 revoke-security-group-ingress --group-id $SG_ID --ip-permissions "${ALL_RULE}"
    listup_ing_rules

}

istio_menu() {
    title

    echo
    _echo "1. install"
    _echo "2. install istio-remote"
    echo
    _echo "3. injection show"
    _echo "4. injection enable"
    _echo "5. injection disable"
    echo
    _echo "6. import config to secret"
    _echo "7. export config"
    _echo "8. show pod IPs"
    echo
    _echo "9. remove"
    echo
    _echo "k. kiali service open"
    _echo "j. jaeger service open"

    question

    case ${ANSWER} in
        1)
            istio_install
            press_enter istio
            ;;
        2)
            istio_remote_install
            press_enter istio
            ;;
        3)
            istio_injection
            press_enter istio
            ;;
        4)
            istio_injection "enable"
            press_enter istio
            ;;
        5)
            istio_injection "disable"
            press_enter istio
            ;;
        6)
            istio_import_config_to_secret
            press_enter istio
            ;;
        7)
            istio_export_config
            press_enter istio
            ;;
        8)
            istio_show_pod_ips
            press_enter istio
            ;;
        9)
            istio_delete
            press_enter istio
            ;;
        k)
            apply_vs_kiali
            press_enter istio
            ;;
        j)
            apply_vs_jaeger
            press_enter istio
            ;;
        *)
            main_menu
            ;;
    esac
}

apply_vs_kiali() {
    
    DEFAULT_ADDR="kiali.${ISTIO_DOMAIN}"
    question "Enter host address for Kiali [${DEFAULT_ADDR}] : "

    KIALI_DOMAIN=${ANSWER:-${DEFAULT_ADDR}}

    CHART=${SHELL_DIR}/build/${CLUSTER_NAME}/istio-${NAME}.yaml
    get_template charts/istio/vs-kiali.yaml ${CHART}

    _replace "s/REPLACE_ME/${KIALI_DOMAIN}/g" ${CHART}


    _command "kubectl apply -f ${CHART}"
    kubectl apply -f ${CHART}

    echo
    _result "Connect - http://${KIALI_DOMAIN}/kiali"
    _result "Default ID/PW : admin/admin"

}

apply_vs_jaeger() {
    
    DEFAULT_ADDR="jaeger.${ISTIO_DOMAIN}"
    question "Enter host address for Jaeger [${DEFAULT_ADDR}] : "

    JAEGER_DOMAIN=${ANSWER:-${DEFAULT_ADDR}}

    CHART=${SHELL_DIR}/build/${CLUSTER_NAME}/istio-${NAME}.yaml
    get_template charts/istio/vs-jaeger.yaml ${CHART}
    
    _replace "s/REPLACE_ME/${JAEGER_DOMAIN}/g" ${CHART}


    _command "kubectl apply -f ${CHART}"
    kubectl apply -f ${CHART}

    echo
    _result "Connect - http://${JAEGER_DOMAIN}"

}

charts_menu() {

    # 상단에 타이틀을 보여줍니다.
    title

    _debug "charts_menu() 함수 시작"

    NAMESPACE=$1
    _debug "NAMESPACE="$NAMESPACE

    LIST=${SHELL_DIR}/build/${CLUSTER_NAME}/charts-list
    _debug "${SHELL_DIR}/charts/${NAMESPACE} 폴더 아래의 파일 목록을 조회해서(파일이름에 backup 문자열이 있으면 제외) 확장자(.yaml)를 삭제한 목록(문자열)을 charts-list 파일에 저장한다."
    ls ${SHELL_DIR}/charts/${NAMESPACE} | grep -v backup | sort | sed 's/.yaml//' > ${LIST}
    _debug_cat ${LIST}

    # select
    select_one
    _debug "SELECTED="${SELECTED}

    # 선택하지 않으면 메인 메뉴 보여줌.
    if [ -z ${SELECTED} ]; then
        main_menu
        return
    fi

    # create_cluster_role_binding admin ${NAMESPACE}

    _debug "선택된 helm chart를 설치한다."
    _debug "helm_install ${SELECTED} ${NAMESPACE}"
    helm_install ${SELECTED} ${NAMESPACE}

    _debug "press_enter ${NAMESPACE}"
    _debug "charts_menu() 함수 끝"

    press_enter ${NAMESPACE}
}

# helm chart를 설치한다. helm을 설치하는게 아님!
helm_install() {
    _debug "helm_install() 함수 실행 시작."

    helm_check

    NAME=${1}
    NAMESPACE=${2}
    _debug "차트이름="$NAME
    _debug "네임스페이스="$NAMESPACE

    _debug "네임스페이스가 없으면 생성해 준다."
    create_namespace ${NAMESPACE}

    EXTRA_VALUES=

    # helm check FAILED
    # COUNT=$(helm ls -a | grep ${NAME} | grep ${NAMESPACE} | grep "FAILED" | wc -l | xargs)
    # if [ "x${COUNT}" != "x0" ]; then
    #     _command "helm delete --purge ${NAME}"
    #     helm delete --purge ${NAME}
    # fi

    # helm chart
    CHART=${SHELL_DIR}/build/${CLUSTER_NAME}/helm-${NAME}.yaml

    _debug "charts/${NAMESPACE}/${NAME}.yaml 파일을 ${CHART} 파일로 복사합니다."
    _debug_cat charts/${NAMESPACE}/${NAME}.yaml

    get_template charts/${NAMESPACE}/${NAME}.yaml ${CHART}
    _debug "chart 파일이 복사되었는지 확인합니다."
    _debug_cat ${CHART}
    
    # yaml 파일에서 chart repo 정보 조회한다.
    REPO=$(cat ${CHART} | grep '# chart-repo:' | awk '{print $3}')
    _debug "REPO="$REPO
    if [ "${REPO}" == "" ]; then
        _debug "yaml 파일에서 chart-repo 정보를 찾을 수 없어서 stable/${NAME} 으로 지정합니다."
        REPO="stable/${NAME}"
    else
        PREFIX="$(echo ${REPO} | cut -d'/' -f1)"
        if [ "${PREFIX}" == "custom" ]; then
            _debug "custom 이므로 custom 폴더를 repo로 설정합니다."
            REPO="${SHELL_DIR}/${REPO}"
        elif [ "${PREFIX}" != "stable" ]; then
            _debug "stable 이므로 helm repo 명령어를 사용해 있는지 확인하고 없으면 등록합니다."
            # helm repo를 등록합니다.
            helm_repo "${PREFIX}"
        fi
    fi
    _debug "REPO="$REPO

    # chart config
    VERSION=$(cat ${CHART} | grep '# chart-version:' | awk '{print $3}')
    INGRESS=$(cat ${CHART} | grep '# chart-ingress:' | awk '{print $3}')
    _debug "VERSION="$VERSION
    _debug "INGRESS="$INGRESS
    _result "Install version: ${REPO} ${VERSION}"

    _debug "helm ls ${NAME} | grep ${NAME} | head -1 | awk '{print $9}'"
    LATEST=$(helm ls ${NAME} | grep ${NAME} | head -1 | awk '{print $9}')
    _debug "LATEST="$LATEST

    if [ "${LATEST}" != "" ]; then
        _result "Installed version: ${REPO} ${LATEST}"
    else
        _result "Installed version: Not installed."
    fi

    _debug "최신 helm chart 버전을 조회한다."
    _debug "helm search ${REPO} | grep ${REPO} | head -1 | awk '{print $2}'"
    LATEST=$(helm search ${REPO} | grep ${REPO} | head -1 | awk '{print $2}')

    # 최신 버전 조회하여 설치할수 있도록 되어 있었으나 최신 버전 정보만 보여주고 차트 파일에 설정된 버전 기준으로 바로 설치하도록 변경함 - 김운주 2020.2.19
    if [ "${LATEST}" != "" ]; then
        _result "Note) Latest helm chart version: ${REPO} ${LATEST}"

        # if [ "${VERSION}" != "" ] && [ "${VERSION}" != "latest" ] && [ "${VERSION}" != "${LATEST}" ]; then
        #     LIST=${SHELL_DIR}/build/${CLUSTER_NAME}/version-list
        #     echo "${VERSION} " > ${LIST}
        #     echo "${LATEST} (latest) " >> ${LIST}
        #     # select
        #     select_one
        #     if [ "${SELECTED}" != "" ]; then
        #         VERSION="$(echo "${SELECTED}" | cut -d' ' -f1)"
        #     fi
        #     _result "${VERSION}"
        # fi
        # if [ "${VERSION}" == "" ] || [ "${VERSION}" == "latest" ]; then
        #     _replace "s/chart-version:.*/chart-version: ${LATEST}/g" ${CHART}
        # fi
    fi

    ### RULE : docker image repository GLOBAL -> CHINA
    # quay.io -> quay.azk8s.cn
    # gcr.io -> gcr.azk8s.cn
    # k8s.gcr.io -> gcr.azk8s.cn/google_containers
    # docker.io -> dockerhub.azk8s.cn
    if [ "${IS_CHINA}" == "true" ]; then
        _replace "s/QUAY/quay.azk8s.cn/g" ${CHART}
        _replace "s/K8SGCR/gcr.azk8s.cn\/google_containers/g" ${CHART}
        _replace "s/GCR/gcr.azk8s.cn/g" ${CHART}
        _replace "s/DOCKER/dockerhub.azk8s.cn/g" ${CHART}
        _replace "s/#EFS_CHART_CHINA_DNS.*/dnsName: EFS_ID.efs.AWS_REGION.amazonaws.com.cn/g" ${CHART}
    else
        _replace "s/QUAY/quay.io/g" ${CHART}
        _replace "s/K8SGCR/k8s.gcr.io/g" ${CHART}
        _replace "s/GCR/gcr.io/g" ${CHART}
        _replace "s/DOCKER/docker.io/g" ${CHART}
        _replace "s/#EFS_CHART_EFSID.*/efsFileSystemId: EFS_ID/g" ${CHART}
        _replace "s/#EFS_CHART_REGION.*/awsRegion: AWS_REGION/g" ${CHART}
    fi

    # global
    # yaml 파일에서 AWS_REGION, CLUSTER_NAME, NAMESPACE 문자열이 있으면 변경한다.
    # 방어코드로 넣어놓은거 같음. 이런 문자열이 없는 yaml 파일도 있음.
    _replace "s/AWS_REGION/${REGION}/g" ${CHART}
    _replace "s/CLUSTER_NAME/${CLUSTER_NAME}/g" ${CHART}
    _replace "s/NAMESPACE/${NAMESPACE}/g" ${CHART}
    _debug "yaml 파일에서 AWS_REGION, CLUSTER_NAME, NAMESPACE 문자열이 있으면 변경되었는지 확인한다."
    _debug_cat ${CHART}

    # ------------------------------------------------------------------- 여기 까지는 helm chart 관련 해서 공통적으로 처리하는 부분임

    # for cert-manager
    if [ "${NAME}" == "cert-manager" ]; then
        # Install the CustomResourceDefinition resources separately
        # https://github.com/helm/charts/blob/master/stable/cert-manager/README.md
#        kubectl apply \
#            -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml
        kubectl apply --validate=false \
            -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml


        # Label the cert-manager namespace to disable resource validation
        kubectl label namespace ${NAMESPACE} certmanager.k8s.io/disable-validation=true

    fi

    # for nginx-ingress
    # 이름이 nginx-ingress로 시작하는 것이 3개 있음.
    #   3. nginx-ingress-nodeport
    #   4. nginx-ingress-private
    #   5. nginx-ingress
    if [[ "${NAME}" == "nginx-ingress"* ]]; then
        {
            get_base_domain
        } || {
            ROOT_DOMAIN="opsnow.cn"
            BASE_DOMAIN="opsnow.cn"
        }

        get_replicas ${NAMESPACE} ${NAME}-controller
        if [ "${REPLICAS}" != "" ]; then
            EXTRA_VALUES="${EXTRA_VALUES} --set controller.replicaCount=${REPLICAS}"
            _debug "EXTRA_VALUES="${EXTRA_VALUES}
        fi

        get_cluster_ip ${NAMESPACE} ${NAME}-controller
        if [ "${CLUSTER_IP}" != "" ]; then
            EXTRA_VALUES="${EXTRA_VALUES} --set controller.service.clusterIP=${CLUSTER_IP}"
            _debug "EXTRA_VALUES="${EXTRA_VALUES}

            get_cluster_ip ${NAMESPACE} ${NAME}-controller-metrics
            if [ "${CLUSTER_IP}" != "" ]; then
                EXTRA_VALUES="${EXTRA_VALUES} --set controller.metrics.service.clusterIP=${CLUSTER_IP}"
                _debug "EXTRA_VALUES="${EXTRA_VALUES}
            fi

            get_cluster_ip ${NAMESPACE} ${NAME}-controller-stats
            if [ "${CLUSTER_IP}" != "" ]; then
                EXTRA_VALUES="${EXTRA_VALUES} --set controller.stats.service.clusterIP=${CLUSTER_IP}"
                _debug "EXTRA_VALUES="${EXTRA_VALUES}
            fi

            get_cluster_ip ${NAMESPACE} ${NAME}-default-backend
            if [ "${CLUSTER_IP}" != "" ]; then
                EXTRA_VALUES="${EXTRA_VALUES} --set defaultBackend.service.clusterIP=${CLUSTER_IP}"
                _debug "EXTRA_VALUES="${EXTRA_VALUES}
            fi
        fi
    fi

    # for external-dns
    if [ "${NAME}" == "external-dns" ]; then
        replace_chart ${CHART} "AWS_ACCESS_KEY"

        if [ "${ANSWER}" != "" ]; then
            replace_password ${CHART} "AWS_SECRET_KEY" "****"
        fi
    fi

    # for cluster-autoscaler
    if [ "${NAME}" == "cluster-autoscaler" ]; then
        get_cluster_ip ${NAMESPACE} ${NAME}
        if [ "${CLUSTER_IP}" != "" ]; then
            EXTRA_VALUES="${EXTRA_VALUES} --set service.clusterIP=${CLUSTER_IP}"
        fi
    fi

    # for efs-provisioner
    if [ "${NAME}" == "efs-provisioner" ]; then
        efs_create
    fi

    # for k8s-spot-termination-handler
    if [ "${NAME}" == "k8s-spot-termination-handler" ]; then
        replace_chart ${CHART} "SLACK_URL"
    fi

    # for vault
    if [ "${NAME}" == "vault" ]; then
        replace_chart ${CHART} "AWS_ACCESS_KEY"

        if [ "${ANSWER}" != "" ]; then
            _replace "s/#:STORAGE://g" ${CHART}

            replace_password ${CHART} "AWS_SECRET_KEY" "****"

            replace_chart ${CHART} "AWS_BUCKET" "${CLUSTER_NAME}-vault"
        fi
    fi

    # for argo
    if [ "${NAME}" == "argo" ]; then
        replace_chart ${CHART} "ARTIFACT_REPOSITORY" "${CLUSTER_NAME}-artifact"
    fi
    # for argocd
    if [ "${NAME}" == "argocd" ]; then
        replace_chart ${CHART} "GITHUB_ORG"

        if [ "${ANSWER}" != "" ]; then
            _replace "s/#:GITHUB://g" ${CHART}

            _result "New Application: https://github.com/organizations/${ANSWER}/settings/applications"

            _result "Homepage: https://${NAME}-${NAMESPACE}.${BASE_DOMAIN}"
            _result "Callback: https://${NAME}-${NAMESPACE}.${BASE_DOMAIN}/api/dex/callback"

            replace_password ${CHART} "GITHUB_CLIENT_ID" "****"

            replace_password ${CHART} "GITHUB_CLIENT_SECRET" "****"
        fi
    fi

    # for jenkins
    if [ "${NAME}" == "jenkins" ]; then
        _debug "Jenkins helm chart 설치 시작"

        # admin password
        replace_password ${CHART}

        # jenkins jobs
        _debug "${SHELL_DIR}/templates/jenkins/jobs.sh ${CHART}"
        ${SHELL_DIR}/templates/jenkins/jobs.sh ${CHART}
    fi

    # for sonatype-nexus
    if [ "${NAME}" == "sonatype-nexus" ]; then
        # admin password
        replace_password ${CHART}
    fi

    # for prometheus
    if [ "${NAME}" == "prometheus" ]; then
        replace_chart ${CHART} "SLACK_TOKEN"

        # kube-state-metrics
        COUNT=$(kubectl get pods -n kube-system | grep kube-state-metrics | wc -l | xargs)
        if [ "x${COUNT}" == "x0" ]; then
            _replace "s/KUBE_STATE_METRICS/true/g" ${CHART}
        else
            _replace "s/KUBE_STATE_METRICS/false/g" ${CHART}
        fi
    fi

    # for grafana
    if [ "${NAME}" == "grafana" ]; then
        # admin password
        replace_password ${CHART}

        # auth.google
        replace_chart ${CHART} "G_CLIENT_ID"

        if [ "${ANSWER}" != "" ]; then
            _replace "s/#:G_AUTH://g" ${CHART}

            replace_password ${CHART} "G_CLIENT_SECRET" "****"

            replace_chart ${CHART} "G_ALLOWED_DOMAINS"
        else
            # auth.ldap
            replace_chart ${CHART} "GRAFANA_LDAP"

            if [ "${ANSWER}" != "" ]; then
                _replace "s/#:LDAP://g" ${CHART}
            fi
        fi
    fi

    # for datadog
    if [ "${NAME}" == "datadog" ]; then
        # api key
        replace_password ${CHART} "API_KEY" "****"
        # app key
        replace_password ${CHART} "APP_KEY" "****"

        # kube-state-metrics
        COUNT=$(kubectl get pods -n kube-system | grep kube-state-metrics | wc -l | xargs)
        if [ "x${COUNT}" == "x0" ]; then
            _replace "s/KUBE_STATE_METRICS/true/g" ${CHART}
        else
            _replace "s/KUBE_STATE_METRICS/false/g" ${CHART}
        fi
    fi

    # for newrelic-infrastructure
    if [ "${NAME}" == "newrelic-infrastructure" ]; then
        # license key
        replace_password ${CHART} "LICENSE_KEY" "****"
    fi

    # for jaeger
    if [ "${NAME}" == "jaeger" ]; then
        # host
        replace_chart ${CHART} "CUSTOM_HOST" "elasticsearch.domain.com"
        # port
        replace_chart ${CHART} "CUSTOM_PORT" "80"
    fi

    # for fluentd-elasticsearch
    if [ "${NAME}" == "fluentd-elasticsearch" ]; then
        # host
        replace_chart ${CHART} "CUSTOM_HOST" "elasticsearch.domain.com"
        # port
        replace_chart ${CHART} "CUSTOM_PORT" "80"
    fi

    # for elasticsearch-snapshot
    if [ "${NAME}" == "elasticsearch-snapshot" ]; then
        replace_chart ${CHART} "SCHEDULE" "0 0 * * *"

        replace_chart ${CHART} "RESTART" "OnFailure" # "Always", "OnFailure", "Never"

        replace_chart ${CHART} "CONFIGMAP_NAME" "${NAME}"
    fi

    # for efs-pvc-exporter
    if [ "${NAME}" == "efs-pvc-exporter" ]; then
        replace_chart ${CHART} "SCHEDULE" "* * * * *"

        replace_chart ${CHART} "RESTART" "OnFailure" # "Always", "OnFailure", "Never"
    fi

    # for efs-mount
    if [ "${EFS_ID}" != "" ]; then
        _replace "s/#:EFS://g" ${CHART}
    fi

    # for master node
    NODE=$(cat ${CHART} | grep '# chart-node:' | awk '{print $3}')
    if [ "${NODE}" == "master" ]; then
        COUNT=$(kubectl get no | grep Ready | grep master | wc -l | xargs)
        if [ "x${COUNT}" != "x0" ]; then
            _replace "s/#:MASTER://g" ${CHART}
        fi
    fi

    # for istio
    if [ "${ISTIO}" == "true" ]; then
        COUNT=$(kubectl get ns ${NAMESPACE} --show-labels | grep 'istio-injection=enabled' | wc -l | xargs)
        if [ "x${COUNT}" != "x0" ]; then
            ISTIO_ENABLED=true
        else
            ISTIO_ENABLED=false
        fi
    else
        ISTIO_ENABLED=false
    fi
    _replace "s/ISTIO_ENABLED/${ISTIO_ENABLED}/g" ${CHART}

    # for ingress
    _debug "yaml 파일에 '# chart-ingress:' 문자열이 존재하고 해당 값이 있는지 확인한다."
    _debug "INGRESS="${INGRESS}
    if [ "${INGRESS}" == "true" ]; then
        _debug "yaml 파일에 '# chart-ingress:' 문자열이 있습니다."
        if [ -z ${BASE_DOMAIN} ]; then
            DOMAIN=

            _replace "s/SERVICE_TYPE/LoadBalancer/g" ${CHART}
            _replace "s/INGRESS_ENABLED/false/g" ${CHART}
        else
            DOMAIN="${NAME}-${NAMESPACE}.${BASE_DOMAIN}"

            _replace "s/SERVICE_TYPE/ClusterIP/g" ${CHART}
            _replace "s/INGRESS_ENABLED/true/g" ${CHART}
            _replace "s/INGRESS_DOMAIN/${DOMAIN}/g" ${CHART}
            _replace "s/BASE_DOMAIN/${BASE_DOMAIN}/g" ${CHART}
        fi
        _replace "s/#:ING://g" ${CHART}
    else
        _debug "yaml 파일에 '# chart-ingress:' 문자열이 없습니다."
    fi

    # check exist persistent volume
    COUNT=$(cat ${CHART} | grep '# chart-pvc:' | wc -l | xargs)
    _debug "yaml 파일에 '# chart-pvc:' 문자열이 존재하고 해당 값이 있는지 확인한다."
    _debug "COUNT="${COUNT}
    if [ "x${COUNT}" != "x0" ]; then
        _debug "yaml 파일에 '# chart-pvc:' 문자열이 있습니다."
        LIST=${SHELL_DIR}/build/${CLUSTER_NAME}/pvc-${NAME}-yaml
        cat ${CHART} | grep '# chart-pvc:' | awk '{print $3,$4,$5}' > ${LIST}
        _debug_cat ${LIST}
        while IFS='' read -r line || [[ -n "$line" ]]; do
            ARR=(${line})
            
            _debug "PV가 있는지 확인한다."
            _debug "check_exist_pv ${NAMESPACE} ${ARR[0]} ${ARR[1]} ${ARR[2]}"
            check_exist_pv ${NAMESPACE} ${ARR[0]} ${ARR[1]} ${ARR[2]}
            
            RELEASED=$?
            if [ "${RELEASED}" -gt "0" ]; then
                echo "  To use an existing volume, remove the PV's '.claimRef.uid' attribute to make the PV an 'Available' status and try again."
                return
            fi
        done < "${LIST}"
    else
        _debug "yaml 파일에 '# chart-pvc:' 문자열이 없습니다."
    fi

    # helm chart install
    _debug_cat ${CHART}
    if [ "${VERSION}" == "" ] || [ "${VERSION}" == "latest" ]; then
        _debug "chart 버전 정보가 지정되지 않았거나 latest로 지정되어 있으면 최신 버전을 설치한다."
        _command "helm upgrade --install ${NAME} ${REPO} --namespace ${NAMESPACE} --values ${CHART}"
        helm upgrade --install ${NAME} ${REPO} --namespace ${NAMESPACE} --values ${CHART} ${EXTRA_VALUES}
    else
        _debug "chart 버전 정보가 지정되어 있으며 해당 버전으로 설치함. VERSION="${VERSION}
        _command "helm upgrade --install ${NAME} ${REPO} --namespace ${NAMESPACE} --values ${CHART} --version ${VERSION}"
        helm upgrade --install ${NAME} ${REPO} --namespace ${NAMESPACE} --values ${CHART} --version ${VERSION} ${EXTRA_VALUES}
    fi

    # config save
    config_save

    # create pdb
    _debug "yaml 파일에 '# chart-pdb:' 문자열이 존재하는지 확인한다."
    PDB_MIN=$(cat ${CHART} | grep '# chart-pdb:' | awk '{print $3}')
    PDB_MAX=$(cat ${CHART} | grep '# chart-pdb:' | awk '{print $4}')
    if [ "${PDB_MIN}" != "" ] || [ "${PDB_MAX}" != "" ]; then
        _debug "'# chart-pdb:' 문자열 있음"
        create_pdb ${NAMESPACE} ${NAME} ${PDB_MIN:-N} ${PDB_MAX:-N}
    else
        _debug "'# chart-pdb:' 문자열 없음"
    fi

    _command "helm history ${NAME}"
    helm history ${NAME}

    # waiting 2
    waiting_pod "${NAMESPACE}" "${NAME}"

    _command "kubectl get node,deploy,pod,svc,pvc,pv,ing -n ${NAMESPACE} | grep ${NAME}"
    kubectl get node,deploy,pod,svc,pvc,pv,ing -n ${NAMESPACE} | grep ${NAME}

    # for argo
    if [ "${NAME}" == "argo" ]; then
        create_cluster_role_binding admin default default
    fi

    # for jenkins
    if [ "${NAME}" == "jenkins" ]; then
        _debug "create_cluster_role_binding admin ${NAMESPACE} default"
        create_cluster_role_binding admin ${NAMESPACE} default

        # EKS cluster role binding
        _command "kubectl apply -f ${SHELL_DIR}/templates/jenkins/jenkins-rollbinding.yaml"
        kubectl apply -f ${SHELL_DIR}/templates/jenkins/jenkins-rollbinding.yaml
        _command "kubectl get clusterrolebinding"
        kubectl get clusterrolebinding
        _command "kubectl get clusterrolebinding valve:jenkins -o yaml"
        kubectl get clusterrolebinding valve:jenkins -o yaml
    fi

    # for nginx-ingress
    if [ "${NAME}" == "nginx-ingress" ]; then
        set_base_domain "${NAME}"
    fi

    # for nginx-ingress-private
    if [ "${NAME}" == "nginx-ingress-private" ]; then
        set_base_domain "${NAME}"
        question "ingress rule delete all? (YES/[no]) : "
        if [ "${ANSWER}" == "YES" ]; then
            remove_ing_rule
        fi
    fi

    # for efs-provisioner
    if [ "${NAME}" == "efs-provisioner" ]; then
        _command "kubectl get sc -n ${NAMESPACE}"
        kubectl get sc -n ${NAMESPACE}
    fi

    # for kubernetes-dashboard
    if [ "${NAME}" == "kubernetes-dashboard" ]; then
        create_cluster_role_binding view ${NAMESPACE} ${NAME}-view true
    fi

    # chart ingress = true
    if [ "${INGRESS}" == "true" ]; then
        if [ -z ${BASE_DOMAIN} ]; then
            get_elb_domain ${NAME} ${NAMESPACE}

            _result "${NAME}: http://${ELB_DOMAIN}"
        else
            if [ -z ${ROOT_DOMAIN} ]; then
                _result "${NAME}: http://${DOMAIN}"
            else
                _result "${NAME}: https://${DOMAIN}"
            fi
        fi
    fi

    _debug "helm_install() 함수 실행 완료."
}

helm_delete() {
    _debug "helm_delete() 함수 시작"

    NAME=

    TEMP=${SHELL_DIR}/build/${CLUSTER_NAME}/helm-temp
    LIST=${SHELL_DIR}/build/${CLUSTER_NAME}/helm-list

    _command "helm ls --all"

    # find all
    helm ls --all --output json \
        | jq -r '"NAMESPACE NAME STATUS REVISION CHART",
                (.Releases[] | "\(.Namespace) \(.Name) \(.Status) \(.Revision) \(.Chart)")' \
        | column -t > ${TEMP}

    echo "     $(head -1 ${TEMP})"

    cat ${TEMP} | grep -v "NAMESPACE" | sort > ${LIST}

    # select
    select_one

    if [ "${SELECTED}" == "" ]; then
        return
    fi

    NAME="$(echo ${SELECTED} | awk '{print $2}')"

    if [ "${NAME}" == "" ]; then
        return
    fi

    # for nginx-ingress
    if [[ "${NAME}" == "nginx-ingress"* ]]; then
        ROOT_DOMAIN=
        BASE_DOMAIN=
    fi

    # for efs-provisioner
    if [ "${NAME}" == "efs-provisioner" ]; then
        efs_delete
    fi

    # helm delete
    _command "helm delete --purge ${NAME}"
    helm delete --purge ${NAME}

    # for argo
    if [ "${NAME}" == "argo" ]; then
        COUNT=$(kubectl get pod -n devops | grep argo | grep Running | wc -l | xargs)

        if [ "x${COUNT}" == "x0" ]; then
            delete_crds "argoproj.io"
        fi
    fi

    # for cert-manager
    if [ "${NAME}" == "cert-manager" ]; then
        # delete crds
        delete_crds "certmanager.k8s.io"
    fi

    # config save
    config_save

    _debug "helm_delete() 함수 끝"
}

# tiller가 설치되어 있는지 확인해서 없으면 helm init을 수행한다.
helm_check() {
    _debug "tiller가 설치되어 있는지 확인한다."
    _command "kubectl get pod -n kube-system | grep tiller-deploy"
    COUNT=$(kubectl get pod -n kube-system | grep tiller-deploy | wc -l | xargs)
    _debug "COUNT="$COUNT

    if [ "x${COUNT}" == "x0" ] || [ ! -d ~/.helm ]; then
        _debug "tiller 설치안되어 있어서 helm init 수행한다."
        helm_init
    else
        _debug "tiller 설치되어 있음."
    fi
}

helm_init() {
    NAMESPACE="kube-system"
    _debug "NAMESPACE="$NAMESPACE

    ACCOUNT="tiller"
    _debug "ACCOUNT="$ACCOUNT

    _debug "tiller 계정에 cluster-admin 권한을 부여한다."
    create_cluster_role_binding cluster-admin ${NAMESPACE} ${ACCOUNT}

    _debug "helm 클라이언트 버전 확인"
    _command "helm version --client"
    helm version --client

    _command "helm init --upgrade --service-account=${ACCOUNT}"
    TILLER_VERSION="v2.16.3"
    if [ "${IS_CHINA}" == "true" ]; then
      helm init -i gcr.azk8s.cn/kubernetes-helm/tiller:${TILLER_VERSION} --upgrade --service-account=${ACCOUNT}
    else
      helm init -i gcr.io/kubernetes-helm/tiller:${TILLER_VERSION}  --upgrade --service-account=${ACCOUNT}
    fi

    default_pdb "${NAMESPACE}"

    waiting_pod "${NAMESPACE}" "tiller"

    _command "kubectl get pod,svc -n ${NAMESPACE}"
    kubectl get pod,svc -n ${NAMESPACE}

    # Helm repo를 업데이트한다.
    helm_repo_update
}

helm_repo() {
    _debug "helm repo를 등록합니다."
    _NAME=$1
    _REPO=$2
    _debug "_NAME="${_NAME}
    _debug "_REPO="${_REPO}

    if [ "${_REPO}" == "" ]; then
        if [ "${_NAME}" == "incubator" ]; then
            _REPO="https://storage.googleapis.com/kubernetes-charts-incubator"
        elif [ "${_NAME}" == "argo" ]; then
            _REPO="https://argoproj.github.io/argo-helm"
        elif [ "${_NAME}" == "monocular" ]; then
            _REPO="https://helm.github.io/monocular"
        elif [ "${_NAME}" == "harbor" ]; then
            _REPO="https://helm.goharbor.io"
        elif [ "${_NAME}" == "appscode" ]; then
            _REPO="https://charts.appscode.com/stable/"
        elif [ "${_NAME}" == "jetstack" ]; then
            _REPO="https://charts.jetstack.io"
        fi
    fi

    if [ "${_REPO}" != "" ]; then
        _debug "helm repo list | grep -v NAME | awk '{print $1}' | grep \"${_NAME}\" | wc -l | xargs"
        COUNT=$(helm repo list | grep -v NAME | awk '{print $1}' | grep "${_NAME}" | wc -l | xargs)
        _debug "COUNT="${COUNT}
        if [ "x${COUNT}" == "x0" ]; then
            _debug "helm repo를 등록합니다."
            _command "helm repo add ${_NAME} ${_REPO}"
            helm repo add ${_NAME} ${_REPO}

            helm_repo_update
        fi
    fi
}

helm_repo_update() {
    _command "helm repo list"
    helm repo list

    _command "helm repo update"
    helm repo update
}

# 네임스페이스가 있는지 확인하고 없으면 생성합니다.
create_namespace() {
    _NAMESPACE=$1

    CHECK=

    _debug "생성하려고 하는 네임스페이스 :" $_NAMESPACE
    _debug "네임스페이스가 존재하는지 확인한다."
    _command "kubectl get ns ${_NAMESPACE}"
    kubectl get ns ${_NAMESPACE} > /dev/null 2>&1 || export CHECK=CREATE

    if [ "${CHECK}" == "CREATE" ]; then
        _result "${_NAMESPACE}"

        _debug "네임스페이스가 없어서 새로 생성합니다."
        _command "kubectl create ns ${_NAMESPACE}"
        kubectl create ns ${_NAMESPACE}
    else
        _debug "네임스페이스가 존재합니다. 새로 생성하지 않음."
    fi
}

create_service_account() {
    _debug "create_service_account() 함수 시작"

    _NAMESPACE=$1
    _ACCOUNT=$2

    create_namespace ${_NAMESPACE}

    CHECK=

    _command "kubectl get sa ${_ACCOUNT} -n ${_NAMESPACE}"
    kubectl get sa ${_ACCOUNT} -n ${_NAMESPACE} > /dev/null 2>&1 || export CHECK=CREATE

    if [ "${CHECK}" == "CREATE" ]; then
        _result "${_NAMESPACE}:${_ACCOUNT}"

        _command "kubectl create sa ${_ACCOUNT} -n ${_NAMESPACE}"
        kubectl create sa ${_ACCOUNT} -n ${_NAMESPACE}
    fi

    _debug "create_service_account() 함수 끝"
}

create_cluster_role_binding() {
    _debug "create_cluster_role_binding() 함수 시작"

    _ROLE=$1
    _NAMESPACE=$2
    _ACCOUNT=${3:-default}
    _TOKEN=${4:-false}
    _debug "_ROLE="${_ROLE}
    _debug "_NAMESPACE="${_NAMESPACE}
    _debug "_ACCOUNT="${_ACCOUNT}
    _debug "_TOKEN="${_TOKEN}

    _debug "create_service_account ${_NAMESPACE} ${_ACCOUNT}"
    create_service_account ${_NAMESPACE} ${_ACCOUNT}

    CHECK=

    _command "kubectl get clusterrolebinding ${_ROLE}:${_NAMESPACE}:${_ACCOUNT}"
    kubectl get clusterrolebinding ${_ROLE}:${_NAMESPACE}:${_ACCOUNT} > /dev/null 2>&1 || export CHECK=CREATE

    if [ "${CHECK}" == "CREATE" ]; then
        _result "${_ROLE}:${_NAMESPACE}:${_ACCOUNT}"

        _command "kubectl create clusterrolebinding ${_ROLE}:${_NAMESPACE}:${_ACCOUNT} --clusterrole=${_ROLE} --serviceaccount=${_NAMESPACE}:${_ACCOUNT}"
        kubectl create clusterrolebinding ${_ROLE}:${_NAMESPACE}:${_ACCOUNT} --clusterrole=${_ROLE} --serviceaccount=${_NAMESPACE}:${_ACCOUNT}
    fi

    if [ "${_TOKEN}" == "true" ]; then
        SECRET=$(kubectl get secret -n ${_NAMESPACE} | grep ${_ACCOUNT}-token | awk '{print $1}')

        _command "kubectl describe secret ${SECRET} -n ${_NAMESPACE}"
        kubectl describe secret ${SECRET} -n ${_NAMESPACE} | grep 'token:'
    fi

    _debug "create_cluster_role_binding() 함수 끝"
}

get_replicas() {
    _debug "deployment 설정에서 replicas 정보를 조회한다."
    _debug "kubectl get deployment -n ${1} -o json | jq -r \".items[] | select(.metadata.name == \"${2}\") | .spec.replicas\""
    REPLICAS=$(kubectl get deployment -n ${1} -o json | jq -r ".items[] | select(.metadata.name == \"${2}\") | .spec.replicas")
    _debug "REPLICAS="${REPLICAS}
}

get_cluster_ip() {
    _debug "service 설정에서 clusterIP 정보를 조회한다."
    _debug "kubectl get svc -n ${1} -o json | jq -r \".items[] | select(.metadata.name == \"${2}\") | .spec.clusterIP\""
    CLUSTER_IP=$(kubectl get svc -n ${1} -o json | jq -r ".items[] | select(.metadata.name == \"${2}\") | .spec.clusterIP")
    _debug "CLUSTER_IP="${CLUSTER_IP}
}

default_pdb() {
    _NAMESPACE=${1}

    create_pdb ${_NAMESPACE} coredns 1 N k8s-app kube-dns

    create_pdb ${_NAMESPACE} kube-dns 1 N k8s-app
    create_pdb ${_NAMESPACE} kube-dns-autoscaler N 1 k8s-app

    create_pdb ${_NAMESPACE} tiller-deploy N 1 tiller
}

create_pdb() {
    _debug "PodDisruptionBudget을 생성한다."
    _NAMESPACE=${1}
    _PDB_NAME=${2}
    _PDB_MIN=${3:-N}
    _PDB_MAX=${4:-N}
    _LABELS=${5:-app}
    _APP_NAME=${6:-${_PDB_NAME}}

    _debug "kubectl get deploy -n kube-system | grep ${_PDB_NAME} | grep -v NAME | wc -l | xargs"
    COUNT=$(kubectl get deploy -n kube-system | grep ${_PDB_NAME} | grep -v NAME | wc -l | xargs)
    _debug "COUNT="$COUNT
    if [ "x${COUNT}" == "x0" ]; then
        return
    fi

    if [ "${_PDB_NAME}" == "heapster" ]; then
        _debug "heapster인 경우 앱 이름을 heapster-heapster로 설정한다."
        _APP_NAME="heapster-heapster"
    fi

    YAML=${SHELL_DIR}/build/${CLUSTER_NAME}/pdb-${_PDB_NAME}.yaml
    get_template templates/pdb/pdb-${_LABELS}.yaml ${YAML}

    _replace "s/PDB_NAME/${_PDB_NAME}/g" ${YAML}
    _replace "s/APP_NAME/${_APP_NAME}/g" ${YAML}

    if [ "${_PDB_MIN}" != "N" ]; then
        _replace "s/PDB_MIN/${_PDB_MIN}/g" ${YAML}
        _replace "s/#:MIN://g" ${YAML}
    fi

    if [ "${_PDB_MAX}" != "N" ]; then
        _replace "s/PDB_MAX/${_PDB_MAX}/g" ${YAML}
        _replace "s/#:MAX://g" ${YAML}
    fi

    # 기존에 있는 pdb 를 삭제한다.
    delete_pdb ${_NAMESPACE} ${_PDB_NAME}

    _debug "pdb 를 생성한다."
    _debug_cat ${YAML}
    _command "kubectl apply -n ${_NAMESPACE} -f ${YAML}"
    kubectl apply -n ${_NAMESPACE} -f ${YAML}
}

delete_pdb() {
    _debug "PodDisruptionBudget을 삭제한다."
    _NAMESPACE=${1}
    _PDB_NAME=${2}

    _command "kubectl get pdb -n kube-system | grep ${_PDB_NAME} | grep -v NAME | wc -l | xargs"
    COUNT=$(kubectl get pdb -n kube-system | grep ${_PDB_NAME} | grep -v NAME | wc -l | xargs)
    if [ "x${COUNT}" != "x0" ]; then
        _command "kubectl delete pdb ${_PDB_NAME} -n ${_NAMESPACE}"
        kubectl delete pdb ${_PDB_NAME} -n ${_NAMESPACE}
    fi
}

check_exist_pv() {
    _debug "check_exist_pv() 함수 시작"
    NAMESPACE=${1}
    PVC_NAME=${2}
    PVC_ACCESS_MODE=${3}
    PVC_SIZE=${4}
    PV_NAME=

    _debug "kubectl get pv | grep ${PVC_NAME} | awk '{print $1}'"
    PV_NAMES=$(kubectl get pv | grep ${PVC_NAME} | awk '{print $1}')
    _debug "PV_NAMES="${PV_NAMES}
    _debug "PvName="${PvName}
    for PvName in ${PV_NAMES}; do
        _debug "kubectl get pv ${PvName} -o json | jq -r '.spec.claimRef.name')"
        if [ "$(kubectl get pv ${PvName} -o json | jq -r '.spec.claimRef.name')" == "${PVC_NAME}" ]; then
            PV_NAME=${PvName}
        fi
    done

    if [ -z ${PV_NAME} ]; then
        _result "No PersistentVolume."
        # Create a new pvc
        _debug "create_pvc ${NAMESPACE} ${PVC_NAME} ${PVC_ACCESS_MODE} ${PVC_SIZE}"
        create_pvc ${NAMESPACE} ${PVC_NAME} ${PVC_ACCESS_MODE} ${PVC_SIZE}
    else
        _debug "PV 정보가 존재합니다."
        PV_JSON=${SHELL_DIR}/build/${CLUSTER_NAME}/pv-${PVC_NAME}.json

        _command "kubectl get pv -o json ${PV_NAME}"
        kubectl get pv -o json ${PV_NAME} > ${PV_JSON}
        _debug_cat ${PV_JSON}

        PV_STATUS=$(cat ${PV_JSON} | jq -r '.status.phase')
        _result "PV is in '${PV_STATUS}' status."

        if [ "${PV_STATUS}" == "Available" ]; then
            _debug "If PVC for PV is not present, create PVC"
            _debug "kubectl get pvc -n ${NAMESPACE} ${PVC_NAME} | grep ${PVC_NAME} | awk '{print $1}'"
            PVC_TMP=$(kubectl get pvc -n ${NAMESPACE} ${PVC_NAME} | grep ${PVC_NAME} | awk '{print $1}')
            _debug "PVC_TMP="${PVC_TMP}
            if [ "${PVC_NAME}" != "${PVC_TMP}" ]; then
                _debug "create a static PVC"
                _debug "create_pvc ${NAMESPACE} ${PVC_NAME} ${PVC_ACCESS_MODE} ${PVC_SIZE} ${PV_NAME}"
                create_pvc ${NAMESPACE} ${PVC_NAME} ${PVC_ACCESS_MODE} ${PVC_SIZE} ${PV_NAME}
            fi
        elif [ "${PV_STATUS}" == "Released" ]; then
            return 1
        fi
    fi
    _debug "check_exist_pv() 함수 끝"
}

create_pvc() {
    _debug "create_pvc() 함수 시작"
    NAMESPACE=${1}
    PVC_NAME=${2}
    PVC_ACCESS_MODE=${3}
    PVC_SIZE=${4}
    PV_NAME=${5}

    YAML=${SHELL_DIR}/build/${CLUSTER_NAME}/pvc-${PVC_NAME}.yaml
    get_template templates/pvc.yaml ${YAML}
    _debug_cat ${YAML}

    _replace "s/PVC_NAME/${PVC_NAME}/g" ${YAML}
    _replace "s/PVC_SIZE/${PVC_SIZE}/g" ${YAML}
    _replace "s/PVC_ACCESS_MODE/${PVC_ACCESS_MODE}/g" ${YAML}
    _debug_cat ${YAML}

    # for efs-provisioner
    if [ ! -z ${EFS_ID} ]; then
        _replace "s/#:EFS://g" ${YAML}
    fi

    # for static pvc
    if [ ! -z ${PV_NAME} ]; then
        _replace "s/#:PV://g" ${YAML}
        _replace "s/PV_NAME/${PV_NAME}/g" ${YAML}
    fi

    _debug_cat ${YAML}
    _command "kubectl create -n ${NAMESPACE} -f ${YAML}"
    kubectl create -n ${NAMESPACE} -f ${YAML}

    waiting_for isBound ${NAMESPACE} ${PVC_NAME}

    _command "kubectl get pvc,pv -n ${NAMESPACE}"
    kubectl get pvc,pv -n ${NAMESPACE}

    _debug "create_pvc() 함수 끝"
}

isBound() {
    NAMESPACE=${1}
    PVC_NAME=${2}

    _debug "kubectl get pvc -n ${NAMESPACE} ${PVC_NAME} -o json | jq -r '.status.phase'"
    PVC_STATUS=$(kubectl get pvc -n ${NAMESPACE} ${PVC_NAME} -o json | jq -r '.status.phase')
    _debug "PVC_STATUS="${PVC_STATUS}
    if [ "${PVC_STATUS}" != "Bound" ]; then
        return 1
    fi
}

isEFSAvailable() {
    _debug "isEFSAvailable() 함수 시작"

    _debug "aws efs describe-file-systems --file-system-id ${EFS_ID} --region ${REGION}"
    FILE_SYSTEMS=$(aws efs describe-file-systems --file-system-id ${EFS_ID} --region ${REGION})
    _debug "FILE_SYSTEMS="${FILE_SYSTEMS}

    _debug "echo ${FILE_SYSTEMS} | jq -r '.FileSystems | length'"
    FILE_SYSTEM_LENGH=$(echo ${FILE_SYSTEMS} | jq -r '.FileSystems | length')
    _debug "FILE_SYSTEM_LENGH="${FILE_SYSTEM_LENGH}

    if [ ${FILE_SYSTEM_LENGH} -gt 0 ]; then
        _debug "echo ${FILE_SYSTEMS} | jq -r '.FileSystems[].LifeCycleState'"
        STATES=$(echo ${FILE_SYSTEMS} | jq -r '.FileSystems[].LifeCycleState')
        _debug "STATES="${STATES}

        COUNT=0
        for state in ${STATES}; do
            if [ "${state}" == "available" ]; then
                COUNT=$(( ${COUNT} + 1 ))
            fi
        done

        # echo ${COUNT}/${FILE_SYSTEM_LENGH}

        if [ ${COUNT} -eq ${FILE_SYSTEM_LENGH} ]; then
            _debug "file systems이 모두 available이면 0을 리턴한다."
            return 0
        fi
    fi

    _debug "file systems이 0개 이거나 모두 available이 아니면 1을 리턴한다."
    _debug "isEFSAvailable() 함수 끝"
    return 1
}

isMountTargetAvailable() {
    MOUNT_TARGETS=$(aws efs describe-mount-targets --file-system-id ${EFS_ID} --region ${REGION})
    MOUNT_TARGET_LENGH=$(echo ${MOUNT_TARGETS} | jq -r '.MountTargets | length')
    if [ ${MOUNT_TARGET_LENGH} -gt 0 ]; then
        STATES=$(echo ${MOUNT_TARGETS} | jq -r '.MountTargets[].LifeCycleState')

        COUNT=0
        for state in ${STATES}; do
            if [ "${state}" == "available" ]; then
                COUNT=$(( ${COUNT} + 1 ))
            fi
        done

        # echo ${COUNT}/${MOUNT_TARGET_LENGH}

        if [ ${COUNT} -eq ${MOUNT_TARGET_LENGH} ]; then
            return 0
        fi
    fi

    return 1
}

isMountTargetDeleted() {
    MOUNT_TARGET_LENGTH=$(aws efs describe-mount-targets --file-system-id ${EFS_ID} --region ${REGION} | jq -r '.MountTargets | length')
    if [ ${MOUNT_TARGET_LENGTH} == 0 ]; then
        return 0
    else
        return 1
    fi
}

delete_pvc() {
    NAMESPACE=$1
    PVC_NAME=$2

#    POD=$(kubectl -n ${NAMESPACE} get pod -l app=${PVC_NAME} -o jsonpath='{.items[0].metadata.name}')
    _command "kubectl -n ${NAMESPACE} get pod | grep ${PVC_NAME} | awk '{print \$1}'"
    POD=$(kubectl -n ${NAMESPACE} get pod | grep ${PVC_NAME} | awk '{print $1}')
    # Should be deleted releated POD
    if [ -z $POD ]; then
        _command "kubectl delete pvc $PVC_NAME -n $NAMESPACE"
        question "Continue? (YES/[no]) : "
        if [ "${ANSWER}" == "YES" ]; then
            kubectl delete pvc $PVC_NAME -n $NAMESPACE
            echo "Delete PVC $PVC_NAME -n $NAMESPACE"
        fi

    else
        echo "Retry after complete pod($POD) deletion."
    fi
}

delete_save_pv() {
    PV_DIR=$1
    PV_NAME=$2

    # get currnent pv yaml
    YAML=${PV_DIR}/pv-${PV_NAME}.yaml
    _command "kubectl get pv $PV_NAME -o yaml > ${YAML}"
    kubectl get pv $PV_NAME -o yaml > ${YAML}

    _command "kubectl delete pv $PV_NAME"
    question "Continue? (YES/[no]) : "
    if [ "${ANSWER}" == "YES" ]; then
        kubectl delete pv $PV_NAME
    fi
}

validate_pv() {
    # Get efs provisioner mounted EFS fs-id
    _command "kubectl -n kube-system get pod -l app=efs-provisioner -o jsonpath='{.items[0].metadata.name}'"
    EFS_POD=$(kubectl -n kube-system get pod -l app=efs-provisioner -o jsonpath='{.items[0].metadata.name}')

    _command "kubectl exec ${EFS_POD} -n kube-system -- df | grep amazonaws.com | awk '{print \$1}'"
    MNT_SERVER=$(kubectl exec ${EFS_POD} -n kube-system -- df | grep amazonaws.com | awk '{print $1}')

    # list up pv's nfs server fs-id
    PV_LIST=${SHELL_DIR}/build/pv-list
    kubectl get pv | grep -v "NAME" | awk '{print $1, $6}' > ${PV_LIST}

    # variable for current wrong pv list
    WRONG_PV_LIST=${SHELL_DIR}/build/wrong-pv-list
    rm -f $WRONG_PV_LIST

    # Compare pv server and EFS fs-id
    # Save wrong pv list
    while IFS='' read -r line || [[ -n "$line" ]]; do
        ARR=(${line})
        _command "kubectl get pv ${ARR[0]} -o jsonpath='{.spec.nfs.server}'"
        MNT_PV=$(kubectl get pv ${ARR[0]} -o jsonpath='{.spec.nfs.server}')
        echo "check efs-id "
        echo "    EFS-PROVISIONER :${MNT_SERVER}"
        echo "    PersistentVolume:${MNT_PV}"

        if [[ "$MNT_SERVER" == "$MNT_PV"* ]]; then
            echo "PASS - ${line} have CORRECT EFS-ID"
        else
            echo "WARNNING - ${line} have WRONG EFS-ID"
            echo "${line}" >> ${WRONG_PV_LIST}
        fi
    done < "${PV_LIST}"

    # delete_pvc, if you want.
    if [ -f ${WRONG_PV_LIST} ]; then
        # check pv list for delete
        cat ${WRONG_PV_LIST}
        question "Would you like to delete PV, PVC? (YES/[no]) : "
        if [ "${ANSWER}" == "YES" ]; then
            # save pv yaml files.
            PV_DIR=${SHELL_DIR}/build/${CLUSTER_NAME}/old-pv
            mkdir -p ${PV_DIR}

            # iter for delete and save
            while IFS='' read -r -u9 line || [[ -n "$line" ]]; do
                ARR=(${line})
                while IFS='/' read -ra NS_NM; do
                    NAMESPACE=${NS_NM[0]}
                    PVC_NAME=${NS_NM[1]}
                done <<< "${ARR[1]}"

                delete_pvc ${NAMESPACE} ${PVC_NAME}
                delete_save_pv ${PV_DIR} ${ARR[0]}
            done 9< "${WRONG_PV_LIST}"

            echo "Saved PV list."
            ls -aslF ${PV_DIR}
            echo "Edit for new EFS and command kubectl apply -f ..."
        fi
    fi
}

efs_create() {
    _debug "efs_create() 함수 시작"
    CONFIG_SAVE=true

    if [ "${EFS_ID}" == "" ]; then
        _debug "aws efs describe-file-systems --creation-token ${CLUSTER_NAME} --region ${REGION} | jq -r '.FileSystems[].FileSystemId'"
        EFS_ID=$(aws efs describe-file-systems --creation-token ${CLUSTER_NAME} --region ${REGION} | jq -r '.FileSystems[].FileSystemId')
    fi

    question "Input your file system id. [${EFS_ID}] : "
    EFS_ID=${ANSWER:-${EFS_ID}}

    if [ "${EFS_ID}" == "" ]; then
        _echo "Creating a elastic file system"

        _debug "aws efs create-file-system --creation-token ${CLUSTER_NAME} --region ${REGION} | jq -r '.FileSystemId'"
        EFS_ID=$(aws efs create-file-system --creation-token ${CLUSTER_NAME} --region ${REGION} | jq -r '.FileSystemId')
        _debug "aws efs create-tags --file-system-id ${EFS_ID} --tags Key=Name,Value=efs.${CLUSTER_NAME} --region ap-northeast-2"
        aws efs create-tags --file-system-id ${EFS_ID} --tags Key=Name,Value=efs.${CLUSTER_NAME} --region ap-northeast-2
    fi

    if [ "${EFS_ID}" == "" ]; then
        _error "Not found the EFS."
    fi

    _result "EFS_ID=${EFS_ID}"

    # replace EFS_ID
    _replace "s/EFS_ID/${EFS_ID}/g" ${CHART}
    _debug_cat ${CHART}

    # owned
    _debug "aws efs describe-file-systems --file-system-id ${EFS_ID} | jq -r '.FileSystems[].Tags[] | values[]' | grep \"kubernetes.io/cluster/${CLUSTER_NAME}\""
    OWNED=$(aws efs describe-file-systems --file-system-id ${EFS_ID} | jq -r '.FileSystems[].Tags[] | values[]' | grep "kubernetes.io/cluster/${CLUSTER_NAME}")
    _debug "OWNED="${OWNED}
    if [ "${OWNED}" != "" ]; then
        _warn "OWNED 조회 결과 값이 있어서 더이상 진행 안함."
        return
    fi

    # get the security group id
    _debug "aws ec2 describe-security-groups --filters \"Name=group-name,Values=nodes.${CLUSTER_NAME}\" | jq -r '.SecurityGroups[0].GroupId'"
    WORKER_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=nodes.${CLUSTER_NAME}" | jq -r '.SecurityGroups[0].GroupId')
    _debug "WORKER_SG_ID="${WORKER_SG_ID}
    if [ -z ${WORKER_SG_ID} ] || [ "${WORKER_SG_ID}" == "null" ]; then
        _error "Not found the security group for the nodes."
    fi
    _result "WORKER_SG_ID=${WORKER_SG_ID}"

    # get vpc id
    _debug "aws ec2 describe-security-groups --filters \"Name=group-name,Values=nodes.${CLUSTER_NAME}\" | jq -r '.SecurityGroups[0].VpcId'"
    VPC_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=nodes.${CLUSTER_NAME}" | jq -r '.SecurityGroups[0].VpcId')
    _debug "VPC_ID="${VPC_ID}
    if [ -z ${VPC_ID} ]; then
        _error "Not found the VPC."
    fi
    _result "VPC_ID=${VPC_ID}"

    # get subent ids
    _debug "aws ec2 describe-subnets --filters \"Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=shared\" \"Name=tag:SubnetType,Values=Private\" | jq '.Subnets | length'"
    VPC_PRIVATE_SUBNETS_LENGTH=$(aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=shared" "Name=tag:SubnetType,Values=Private" | jq '.Subnets | length')
    _debug "VPC_PRIVATE_SUBNETS_LENGTH="${VPC_PRIVATE_SUBNETS_LENGTH}
    if [ ${VPC_PRIVATE_SUBNETS_LENGTH} -gt 0 ]; then
        _debug "vpc private subnets이 1개 이상 존재합니다."
        _debug "aws ec2 describe-subnets --filters \"Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=shared\" \"Name=tag:SubnetType,Values=Private\" | jq -r '(.Subnets[].SubnetId)'"
        VPC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=shared" "Name=tag:SubnetType,Values=Private" | jq -r '(.Subnets[].SubnetId)')
        _debug "VPC_SUBNETS="${VPC_SUBNETS}
    else
        _debug "vpc private subnets이 없습니다."
        _debug "aws ec2 describe-subnets --filters \"Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=shared\" | jq -r '(.Subnets[].SubnetId)'"
        VPC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=shared" | jq -r '(.Subnets[].SubnetId)')
        _debug "VPC_SUBNETS="${VPC_SUBNETS}
    fi
    _result "VPC_SUBNETS=$(echo ${VPC_SUBNETS} | xargs)"

    # create a security group for efs mount targets
    _debug "aws ec2 describe-security-groups --filters \"Name=group-name,Values=efs-sg.${CLUSTER_NAME}\" | jq '.SecurityGroups | length'"
    EFS_SG_LENGTH=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=efs-sg.${CLUSTER_NAME}" | jq '.SecurityGroups | length')
    _debug "EFS_SG_LENGTH="${EFS_SG_LENGTH}
    if [ ${EFS_SG_LENGTH} -eq 0 ]; then
        _echo "Creating a security group for mount targets"

        _debug "aws ec2 create-security-group --region ${REGION} --group-name efs-sg.${CLUSTER_NAME} --description \"Security group for EFS mount targets\" --vpc-id ${VPC_ID} | jq -r '.GroupId'"
        EFS_SG_ID=$(aws ec2 create-security-group --region ${REGION} --group-name efs-sg.${CLUSTER_NAME} --description "Security group for EFS mount targets" --vpc-id ${VPC_ID} | jq -r '.GroupId')
        _debug "EFS_SG_ID="${EFS_SG_ID}

        _debug "aws ec2 authorize-security-group-ingress --group-id ${EFS_SG_ID} --protocol tcp --port 2049 --source-group ${WORKER_SG_ID} --region ${REGION}"
        aws ec2 authorize-security-group-ingress --group-id ${EFS_SG_ID} --protocol tcp --port 2049 --source-group ${WORKER_SG_ID} --region ${REGION}
    else
        _debug "aws ec2 describe-security-groups --filters \"Name=group-name,Values=efs-sg.${CLUSTER_NAME}\" | jq -r '.SecurityGroups[].GroupId'"
        EFS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=efs-sg.${CLUSTER_NAME}" | jq -r '.SecurityGroups[].GroupId')
        _debug "EFS_SG_ID="${EFS_SG_ID}
    fi

    _debug "Security group for mount targets"
    _result "EFS_SG_ID=${EFS_SG_ID}"

    _echo "Waiting for the state of the EFS to be available."
    waiting_for isEFSAvailable

    # create mount targets
    _debug "aws efs describe-mount-targets --file-system-id ${EFS_ID} --region ${REGION} | jq -r '.MountTargets | length'"
    EFS_MOUNT_TARGET_LENGTH=$(aws efs describe-mount-targets --file-system-id ${EFS_ID} --region ${REGION} | jq -r '.MountTargets | length')
    _debug "EFS_MOUNT_TARGET_LENGTH="${EFS_MOUNT_TARGET_LENGTH}
    if [ ${EFS_MOUNT_TARGET_LENGTH} -eq 0 ]; then
        _echo "Creating mount targets"

        for SubnetId in ${VPC_SUBNETS}; do
            EFS_MOUNT_TARGET_ID=$(aws efs create-mount-target \
                --file-system-id ${EFS_ID} \
                --subnet-id ${SubnetId} \
                --security-group ${EFS_SG_ID} \
                --region ${REGION} | jq -r '.MountTargetId')
            _debug "EFS_MOUNT_TARGET_ID="${EFS_MOUNT_TARGET_ID}
            EFS_MOUNT_TARGET_IDS=(${EFS_MOUNT_TARGET_IDS[@]} ${EFS_MOUNT_TARGET_ID})
            _debug "EFS_MOUNT_TARGET_IDS="${EFS_MOUNT_TARGET_IDS}
        done
    else
        EFS_MOUNT_TARGET_IDS=$(aws efs describe-mount-targets --file-system-id ${EFS_ID} --region ${REGION} | jq -r '.MountTargets[].MountTargetId')
        _debug "EFS_MOUNT_TARGET_IDS="${EFS_MOUNT_TARGET_IDS}
    fi
    _result "EFS_MOUNT_TARGET_IDS=$(echo ${EFS_MOUNT_TARGET_IDS[@]} | xargs)"

    _echo "Waiting for the state of the EFS mount targets to be available."
    waiting_for isMountTargetAvailable
    _debug "efs_create() 함수 끝"
}

efs_delete() {
    CONFIG_SAVE=true

    if [ "${EFS_ID}" == "" ]; then
        _debug "EFS_ID 값이 없어서 다음단계 진행 안함."
        return
    fi

    # owned
    _command "aws efs describe-file-systems --file-system-id ${EFS_ID}"
    OWNED=$(aws efs describe-file-systems --file-system-id ${EFS_ID} | jq -r '.FileSystems[].Tags[] | values[]' | grep "kubernetes.io/cluster/${CLUSTER_NAME}")
    _debug "OWNED="${OWNED}
    if [ "${OWNED}" == "" ]; then
        # delete mount targets
        EFS_MOUNT_TARGET_IDS=$(aws efs describe-mount-targets --file-system-id ${EFS_ID} --region ${REGION} | jq -r '.MountTargets[].MountTargetId')
        _debug "EFS_MOUNT_TARGET_IDS="${EFS_MOUNT_TARGET_IDS}
        for MountTargetId in ${EFS_MOUNT_TARGET_IDS}; do
            echo "Deleting the mount targets"
            _command "aws efs delete-mount-target --mount-target-id ${MountTargetId}"
            aws efs delete-mount-target --mount-target-id ${MountTargetId}
        done

        echo "Waiting for the EFS mount targets to be deleted."
        waiting_for isMountTargetDeleted

        # delete security group for efs mount targets
        EFS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=efs-sg.${CLUSTER_NAME}" | jq -r '.SecurityGroups[0].GroupId')
        _debug "EFS_SG_ID="${EFS_SG_ID}
        if [ -n ${EFS_SG_ID} ]; then
            echo "Deleting the security group for mount targets"
            _command "aws ec2 delete-security-group --group-id ${EFS_SG_ID}"
            aws ec2 delete-security-group --group-id ${EFS_SG_ID}
        fi

        # delete efs
        _debug "EFS_ID="${EFS_ID}
        if [ -n ${EFS_ID} ]; then
            echo "Deleting the elastic file system"
            _command "aws efs delete-file-system --file-system-id ${EFS_ID} --region ${REGION}"
            aws efs delete-file-system --file-system-id ${EFS_ID} --region ${REGION}
        fi
    fi

    EFS_ID=

    _result "EFS_ID=${EFS_ID}"
}

istio_init() {
    helm_check

    NAME="istio"
    NAMESPACE="istio-system"

    ISTIO_TMP=${SHELL_DIR}/build/istio
    mkdir -p ${ISTIO_TMP}

    CHART=${SHELL_DIR}/charts/istio/istio.yaml
    VERSION=$(cat ${CHART} | grep '# chart-version:' | awk '{print $3}')

    if [ "${VERSION}" == "" ] || [ "${VERSION}" == "latest" ]; then
        VERSION=$(curl -s https://api.github.com/repos/istio/istio/releases/latest | jq -r '.tag_name')
    fi

    _result "${NAME} ${VERSION}"

    # istio download
    if [ ! -d ${ISTIO_TMP}/${NAME}-${VERSION} ]; then
        if [ "${OS_NAME}" == "darwin" ]; then
            OSEXT="osx"
        else
            OSEXT="linux"
        fi

        URL="https://github.com/istio/istio/releases/download/${VERSION}/istio-${VERSION}-${OSEXT}.tar.gz"

        pushd ${ISTIO_TMP}
        curl -sL "${URL}" | tar xz
        popd
    fi

    ISTIO_DIR=${ISTIO_TMP}/${NAME}-${VERSION}/install/kubernetes/helm/istio
}

istio_secret() {
    YAML=${SHELL_DIR}/build/${CLUSTER_NAME}/istio-secret.yaml
    get_template templates/istio-secret.yaml ${YAML}

    replace_base64 ${YAML} "USERNAME" "admin"
    replace_base64 ${YAML} "PASSWORD" "password"

    _command "kubectl apply -n ${NAMESPACE} -f ${YAML}"
    kubectl apply -n ${NAMESPACE} -f ${YAML}
}

istio_show_pod_ips() {
    export PILOT_POD_IP=$(kubectl -n istio-system get pod -l istio=pilot -o jsonpath='{.items[0].status.podIP}')
    export POLICY_POD_IP=$(kubectl -n istio-system get pod -l istio-mixer-type=policy -o jsonpath='{.items[0].status.podIP}')
    export STATSD_POD_IP=$(kubectl -n istio-system get pod -l istio=statsd-prom-bridge -o jsonpath='{.items[0].status.podIP}')
    export TELEMETRY_POD_IP=$(kubectl -n istio-system get pod -l istio-mixer-type=telemetry -o jsonpath='{.items[0].status.podIP}')
    export ZIPKIN_POD_IP=$(kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{range .items[*]}{.status.podIP}{end}')

    echo "export PILOT_POD_IP=$PILOT_POD_IP"
    echo "export POLICY_POD_IP=$POLICY_POD_IP"
    echo "export STATSD_POD_IP=$STATSD_POD_IP"
    echo "export TELEMETRY_POD_IP=$TELEMETRY_POD_IP"
    echo "export ZIPKIN_POD_IP=$ZIPKIN_POD_IP"
}

istio_import_config_to_secret() {
    ls -lrt
    question "Enter your env files : "
    source ${ANSWER}

    _command "kubectl create secret generic ${CLUSTER_NAME} --from-file ${KUBECFG_FILE} -n ${NAMESPACE}"
    kubectl create secret generic ${CLUSTER_NAME} --from-file ${KUBECFG_FILE} -n ${NAMESPACE}

    _command "kubectl label secret ${CLUSTER_NAME} istio/multiCluster=true -n ${NAMESPACE}"
    kubectl label secret ${CLUSTER_NAME} istio/multiCluster=true -n ${NAMESPACE}

    _command "kubectl get secret ${CLUSTER_NAME} -n ${NAMESPACE} -o json"
    kubectl get secret ${CLUSTER_NAME} -n ${NAMESPACE} -o json
}

istio_export_config() {
    export WORK_DIR=$(pwd)
    CLUSTER_NAME=$(kubectl config view --minify=true -o "jsonpath={.clusters[].name}")
    export KUBECFG_FILE=${WORK_DIR}/${CLUSTER_NAME}
    export KUBECFG_ENV_FILE="${WORK_DIR}/${CLUSTER_NAME}-remote-cluster-env-vars"
    SERVER=$(kubectl config view --minify=true -o "jsonpath={.clusters[].cluster.server}")
    NAMESPACE=istio-system
    SERVICE_ACCOUNT=istio-multi
    SECRET_NAME=$(kubectl get sa ${SERVICE_ACCOUNT} -n ${NAMESPACE} -o jsonpath='{.secrets[].name}')
    CA_DATA=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o "jsonpath={.data['ca\.crt']}")
    TOKEN=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o "jsonpath={.data['token']}" | base64 --decode)

    cat <<EOF > ${KUBECFG_FILE}
apiVersion: v1
clusters:
- cluster:
   certificate-authority-data: ${CA_DATA}
   server: ${SERVER}
 name: ${CLUSTER_NAME}
contexts:
- context:
   cluster: ${CLUSTER_NAME}
   user: ${CLUSTER_NAME}
 name: ${CLUSTER_NAME}
current-context: ${CLUSTER_NAME}
kind: Config
preferences: {}
users:
- name: ${CLUSTER_NAME}
 user:
   token: ${TOKEN}
EOF

    cat <<EOF > ${KUBECFG_ENV_FILE}
export CLUSTER_NAME=${CLUSTER_NAME}
export KUBECFG_FILE=${KUBECFG_FILE}
export NAMESPACE=${NAMESPACE}
EOF

    _command "cat ${KUBECFG_FILE}"
    cat ${KUBECFG_FILE}

    _command "cat ${KUBECFG_ENV_FILE}"
    cat ${KUBECFG_ENV_FILE}

    _command "ls -aslF ${KUBECFG_FILE} ${KUBECFG_ENV_FILE}"
    ls -aslF ${KUBECFG_FILE} ${KUBECFG_ENV_FILE}
#    ls -aslF ${KUBECFG_FILE}
#    ls -aslF ${KUBECFG_ENV_FILE}
}

waiting_istio_init() {
    SEC=10
    RET=0
    IDX=0
    while true; do
        RET=$(echo -e `kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l`)
        printf ${RET}

        if [ ${RET} -gt 52 ]; then
            echo " init ok"
            break
        elif [ "x${IDX}" == "x${SEC}" ]; then
            _result "Timeout"
            break
        fi

        IDX=$(( ${IDX} + 1 ))
        sleep 2
    done
}

istio_install() {
    istio_init

    create_namespace ${NAMESPACE}

    # istio 1.1.x init
    if [[ "${VERSION}" == "1.1."* ]]; then
        _command "helm upgrade --install ${ISTIO_DIR}-init --name istio-init --namespace ${NAMESPACE}"
        helm upgrade --install istio-init ${ISTIO_DIR}-init --namespace ${NAMESPACE}

        # result will be more than 53
        waiting_istio_init
    fi

    get_base_domain

    CHART=${SHELL_DIR}/build/${CLUSTER_NAME}/${NAME}.yaml
    get_template charts/istio/${NAME}.yaml ${CHART}

    # # ingress
    # if [ -z ${BASE_DOMAIN} ]; then
    #     _replace "s/SERVICE_TYPE/LoadBalancer/g" ${CHART}
    #     _replace "s/INGRESS_ENABLED/false/g" ${CHART}
    # else
    #     _replace "s/SERVICE_TYPE/ClusterIP/g" ${CHART}
    #     _replace "s/INGRESS_ENABLED/true/g" ${CHART}
    #     _replace "s/BASE_DOMAIN/${BASE_DOMAIN}/g" ${CHART}
    # fi

    # # istio secret
    # istio_secret

    # helm install
    _command "helm upgrade --install ${NAME} ${ISTIO_DIR} --namespace ${NAMESPACE} --values ${CHART}"
    helm upgrade --install ${NAME} ${ISTIO_DIR} --namespace ${NAMESPACE} --values ${CHART}

    # kiali sa
    # create_cluster_role_binding view ${NAMESPACE} kiali-service-account

    ISTIO=true
    CONFIG_SAVE=true

    # save config (ISTIO)
    config_save

    # waiting 2
    waiting_pod "${NAMESPACE}" "${NAME}"


    # Route53 set record with ISTIO_DOMAIN not BASE_DOMAIN
    PREV_BASE_DOMAIN=${BASE_DOMAIN}
    PREV_ISTIO_DOMAIN=${ISTIO_DOMAIN}

    BASE_DOMAIN=${ISTIO_DOMAIN}
    set_base_domain "istio-ingressgateway"
    
    ISTIO_DOMAIN=${PREV_ISTIO_DOMAIN}
    BASE_DOMAIN=${PREV_BASE_DOMAIN}


    _command "helm history ${NAME}"
    helm history ${NAME}

    _command "kubectl get deploy,pod,svc,ing -n ${NAMESPACE}"
    kubectl get deploy,pod,svc,ing -n ${NAMESPACE}
}

istio_remote_install() {
    istio_init

    RNAME="istio-remote"

    RISTIO_DIR="${ISTIO_DIR}-remote"

    create_namespace ${NAMESPACE}

    CHART=${SHELL_DIR}/build/${THIS_NAME}-istio-${NAME}.yaml
    get_template charts/istio/${NAME}.yaml ${CHART}

    if [ -z ${PILOT_POD_IP} ]; then
        echo "PILOT_POD_IP=$PILOT_POD_IP"
    fi
    if [ -z ${POLICY_POD_IP} ]; then
        echo "POLICY_POD_IP=$POLICY_POD_IP"
    fi
    if [ -z ${STATSD_POD_IP} ]; then
        echo "STATSD_POD_IP=$STATSD_POD_IP"
    fi
    if [ -z ${TELEMETRY_POD_IP} ]; then
        echo "TELEMETRY_POD_IP=$TELEMETRY_POD_IP"
    fi
    if [ -z ${ZIPKIN_POD_IP} ]; then
        echo "ZIPKIN_POD_IP=$ZIPKIN_POD_IP"
    fi

    _command "helm upgrade --install ${RNAME} ${RISTIO_DIR} --namespace ${NAMESPACE} --set global.remotePilotAddress=${PILOT_POD_IP} --set global.remotePolicyAddress=${POLICY_POD_IP} --set global.remoteTelemetryAddress=${TELEMETRY_POD_IP} --set global.proxy.envoyStatsd.enabled=true --set global.proxy.envoyStatsd.host=${STATSD_POD_IP} --set global.remoteZipkinAddress=${ZIPKIN_POD_IP}"
    helm upgrade --install ${RNAME} ${RISTIO_DIR} --namespace ${NAMESPACE} \
                 --set global.remotePilotAddress=${PILOT_POD_IP} \
                 --set global.remotePolicyAddress=${POLICY_POD_IP} \
                 --set global.remoteTelemetryAddress=${TELEMETRY_POD_IP} \
                 --set global.proxy.envoyStatsd.enabled=true \
                 --set global.proxy.envoyStatsd.host=${STATSD_POD_IP} \
                 --set global.remoteZipkinAddress=${ZIPKIN_POD_IP}

    ISTIO=true
    CONFIG_SAVE=true

    # save config (ISTIO)
    config_save

    # waiting 2
    waiting_pod "${NAMESPACE}" "${RNAME}"

    _command "helm history ${RNAME}"
    helm history ${RNAME}

    _command "kubectl get deploy,pod,svc -n ${NAMESPACE}"
    kubectl get deploy,pod,svc -n ${NAMESPACE}
}

istio_injection() {
    CMD=$1

    if [ -z ${CMD} ]; then
        _command "kubectl get ns --show-labels"
        kubectl get ns --show-labels
        return
    fi

    LIST=${SHELL_DIR}/build/${CLUSTER_NAME}/istio-ns-list

    # find
    kubectl get ns | grep -v "NAME" | awk '{print $1}' > ${LIST}

    # select
    select_one

    if [ -z ${SELECTED} ]; then
        istio_menu
        return
    fi

    # istio-injection
    if [ "${CMD}" == "enable" ]; then
        kubectl label namespace ${SELECTED} istio-injection=enabled
    else
        kubectl label namespace ${SELECTED} istio-injection-
    fi

    press_enter istio
}

istio_delete() {
    istio_init

    # helm delete
    _command "helm delete --purge ${NAME}"
    helm delete --purge ${NAME}

    _command "helm delete --purge istio-init"
    helm delete --purge istio-init

    # delete crds
    delete_crds "istio.io"

    # delete ns
    _command "kubectl delete namespace ${NAMESPACE}"
    kubectl delete namespace ${NAMESPACE}

    ISTIO=
    CONFIG_SAVE=true

    # save config (ISTIO)
    config_save
}

delete_crds() {
    # delete crds
    LIST="$(kubectl get crds | grep ${1} | awk '{print $1}')"
    if [ "${LIST}" != "" ]; then
        _command "kubectl delete crds *.${1}"
        kubectl delete crds ${LIST}
    fi
}

select_cluster_type() {
    logo

    # 현재 선택된 노드 타입을 지정한다
    # 노드 타입은 툴체인노드 or 쿠버네티스 타겟 노드 둘 중 하나다
    # TODO 기존 저장된 타입을 출력해준다
    # config list
    LIST=${SHELL_DIR}/build/${THIS_NAME}/node-type-list
    echo "toolchain-cluster" > ${LIST}
    echo "target-cluster" >> ${LIST}
    _debug_cat ${LIST}

    #show default value
    if [ "${CLUSTER_TYPE}" != "" ]; then
        _result "default type : ${CLUSTER_TYPE}"
    fi

    # select
    select_one true

    if [ "${SELECTED}" == "" ]; then
        if [ "${CLUSTER_TYPE}" == "" ]; then
            CLUSTER_TYPE="toolchain-cluster"
        fi
        echo ${CLUSTER_TYPE}
    else
        CLUSTER_TYPE="${SELECTED}"
    fi

    CONFIG_SAVE=true
    config_save
}

get_cluster() {
    # config list
    LIST=${SHELL_DIR}/build/${THIS_NAME}/config-list
    _command "kubectl config view -o json | jq -r '.contexts[].name' | sort > ${LIST}"
    kubectl config view -o json | jq -r '.contexts[].name' | sort > ${LIST}

    # select
    select_one true

    if [ "${SELECTED}" == "" ]; then
        _error
    fi

    CLUSTER_NAME="${SELECTED}"

    mkdir -p ${SHELL_DIR}/build/${CLUSTER_NAME}

    _command "kubectl config use-context ${CLUSTER_NAME}"
    TEMP_FILE=${SHELL_DIR}/build/${THIS_NAME}/temp
    kubectl config use-context ${CLUSTER_NAME} > ${TEMP_FILE}
    _result "$(cat ${TEMP_FILE})"
}

get_elb_domain() {
    _debug "get_elb_domain() 함수 실행 시작."
    ELB_DOMAIN=

    if [ -z $2 ]; then
        _command "kubectl get svc --all-namespaces -o wide | grep LoadBalancer | grep $1 | head -1 | awk '{print \$5}'"
    else
        _command "kubectl get svc -n $2 -o wide | grep LoadBalancer | grep $1 | head -1 | awk '{print \$4}'"
    fi

    progress start

    # 2초 간격으로 200번 까지 조회해 본다.
    ELB_DOMAIN_RETRY_MAX=200
    IDX=0
    while true; do
        # ELB Domain 을 획득
        if [ -z $2 ]; then
            ELB_DOMAIN=$(kubectl get svc --all-namespaces -o wide | grep LoadBalancer | grep $1 | head -1 | awk '{print $5}')
        else
            _debug "kubectl get svc -n $2 -o wide | grep LoadBalancer | grep $1 | head -1 | awk '{print $4}'"
        fi

        # 점(.) 사이에 조회한 ELB_DOMAIN 값을 프린트한다.
        _debug "ELB_DOMAIN="${ELB_DOMAIN}

        if [ ! -z ${ELB_DOMAIN} ] && [ "${ELB_DOMAIN}" != "<pending>" ]; then
            progress end
            _debug "ELB_DOMAIN 값이 정상적으로 조회 되었습니다."
            break
        fi

        IDX=$(( ${IDX} + 1 ))

        if [ "${IDX}" == "${ELB_DOMAIN_RETRY_MAX}" ]; then
            progress end
            _warn "${ELB_DOMAIN_RETRY_MAX}번 수행하는 동안 ELB_DOMAIN 값 조회 안됨."
            ELB_DOMAIN=
            break
        fi

        progress
    done

    _result "ELB_DOMAIN="${ELB_DOMAIN}
}

get_ingress_elb_name() {
    _debug "get_ingress_elb_name() 함수 실행 시작."

    POD="${1:-nginx-ingress}"
    _debug "POD="${POD}

    ELB_NAME=

    get_elb_domain "${POD}"
    _debug "ELB_DOMAIN="${ELB_DOMAIN}

    if [ -z ${ELB_DOMAIN} ]; then
        _warn "ELB_DOMAIN 정보 조회 실패."
        return
    fi

    _command "echo ${ELB_DOMAIN} | cut -d'-' -f1"
    ELB_NAME=$(echo ${ELB_DOMAIN} | cut -d'-' -f1)

    _result "ELB_NAME="${ELB_NAME}
}

get_ingress_nip_io() {
    _debug "get_ingress_nip_io() 함수 실행 시작."

    POD="${1:-nginx-ingress}"
    _debug "POD="${POD}

    ELB_IP=

    get_elb_domain "${POD}"
    _debug "ELB_DOMAIN="${ELB_DOMAIN}

    if [ -z ${ELB_DOMAIN} ]; then
        _warn "ELB_DOMAIN 값 조회 실패했습니다."
        return
    fi

    _command "dig +short ${ELB_DOMAIN} | head -n 1"

    progress start

    IDX=0
    while true; do
        ELB_IP=$(dig +short ${ELB_DOMAIN} | head -n 1)

        if [ ! -z ${ELB_IP} ]; then
            BASE_DOMAIN="${ELB_IP}.nip.io"
            break
        fi

        IDX=$(( ${IDX} + 1 ))

        if [ "${IDX}" == "100" ]; then
            _warn "ELB_IP 값 조회 실패했습니다."
            BASE_DOMAIN=
            break
        fi

        progress
    done

    progress end

    _result "BASE_DOMAIN="${BASE_DOMAIN}
}

# Root 도메인을 대화식으로 입력 받는다.
read_root_domain() {
    # domain list
    LIST=${SHELL_DIR}/build/${THIS_NAME}/hosted-zones

    _command "aws route53 list-hosted-zones | jq -r '.HostedZones[] | .Name' | sed 's/.$//'"
    aws route53 list-hosted-zones | jq -r '.HostedZones[] | .Name' | sed 's/.$//' > ${LIST}
    _debug_cat ${LIST}

    __CNT=$(cat ${LIST} | wc -l | xargs)
    if [ "x${__CNT}" == "x0" ]; then
        ROOT_DOMAIN=""
        _warn "Can't find root domain" 
    else
        # select
        select_one

        if [ "${SELECTED}" == "" ]; then
            SELECTED=$(sed -n 1p ${LIST})
        fi

        ROOT_DOMAIN=${SELECTED}
    fi
    _debug "ROOT_DOMAIN="${ROOT_DOMAIN}
}

# AWS ACM에서 인증서 정보를 조회한다.
get_ssl_cert_arn() {
    if [ -z ${BASE_DOMAIN} ]; then
        return
    fi

    # get certificate arn
    _command "aws acm list-certificates | DOMAIN="${SUB_DOMAIN}.${BASE_DOMAIN}" jq -r '.CertificateSummaryList[] | select(.DomainName==env.DOMAIN) | .CertificateArn'"
    SSL_CERT_ARN=$(aws acm list-certificates | DOMAIN="${SUB_DOMAIN}.${BASE_DOMAIN}" jq -r '.CertificateSummaryList[] | select(.DomainName==env.DOMAIN) | .CertificateArn')
    _debug "SSL_CERT_ARN="${SSL_CERT_ARN}
}

req_ssl_cert_arn() {
    if [ -z ${ROOT_DOMAIN} ] || [ -z ${BASE_DOMAIN} ]; then
        return
    fi

    # request certificate
    _command "aws acm request-certificate --domain-name "${SUB_DOMAIN}.${BASE_DOMAIN}" --validation-method DNS | jq -r '.CertificateArn'"
    SSL_CERT_ARN=$(aws acm request-certificate --domain-name "${SUB_DOMAIN}.${BASE_DOMAIN}" --validation-method DNS | jq -r '.CertificateArn')

    _result "Request Certificate..."

    waiting 2

    # Route53 에서 해당 도메인의 Hosted Zone ID 를 획득
    _command "aws route53 list-hosted-zones | ROOT_DOMAIN="${ROOT_DOMAIN}." jq -r '.HostedZones[] | select(.Name==env.ROOT_DOMAIN) | .Id' | cut -d'/' -f3"
    ZONE_ID=$(aws route53 list-hosted-zones | ROOT_DOMAIN="${ROOT_DOMAIN}." jq -r '.HostedZones[] | select(.Name==env.ROOT_DOMAIN) | .Id' | cut -d'/' -f3)

    if [ -z ${ZONE_ID} ]; then
        return
    fi

    # domain validate name
    _command "aws acm describe-certificate --certificate-arn ${SSL_CERT_ARN} | jq -r '.Certificate.DomainValidationOptions[].ResourceRecord | .Name'"
    CERT_DNS_NAME=$(aws acm describe-certificate --certificate-arn ${SSL_CERT_ARN} | jq -r '.Certificate.DomainValidationOptions[].ResourceRecord | .Name')

    if [ -z ${CERT_DNS_NAME} ]; then
        return
    fi

    # domain validate value
    _command "aws acm describe-certificate --certificate-arn ${SSL_CERT_ARN} | jq -r '.Certificate.DomainValidationOptions[].ResourceRecord | .Value'"
    CERT_DNS_VALUE=$(aws acm describe-certificate --certificate-arn ${SSL_CERT_ARN} | jq -r '.Certificate.DomainValidationOptions[].ResourceRecord | .Value')

    if [ -z ${CERT_DNS_VALUE} ]; then
        return
    fi

    # record sets
    RECORD=${SHELL_DIR}/build/${CLUSTER_NAME}/record-sets-cname.json
    get_template templates/record-sets-cname.json ${RECORD}

    # replace
    _replace "s/DOMAIN/${CERT_DNS_NAME}/g" ${RECORD}
    _replace "s/DNS_NAME/${CERT_DNS_VALUE}/g" ${RECORD}

    cat ${RECORD}

    # update route53 record
    _command "aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}"
    aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}
}

set_record_alias() {
    _debug "set_record_alias() 함수 실행 시작."

    _debug "ROOT_DOMAIN="${ROOT_DOMAIN}
    _debug "BASE_DOMAIN="${BASE_DOMAIN}
    _debug "ELB_NAME="${ELB_NAME}

    if [ -z ${ROOT_DOMAIN} ] || [ -z ${BASE_DOMAIN} ] || [ -z ${ELB_NAME} ]; then
        _warn "ROOT_DOMAIN, BASE_DOMAIN, ELB_NAME 값이 있어야 합니다."
        return
    fi

    # Route53 에서 해당 도메인의 Hosted Zone ID 를 획득
    _command "aws route53 list-hosted-zones | ROOT_DOMAIN="${ROOT_DOMAIN}." jq -r '.HostedZones[] | select(.Name==env.ROOT_DOMAIN) | .Id' | cut -d'/' -f3"
    ZONE_ID=$(aws route53 list-hosted-zones | ROOT_DOMAIN="${ROOT_DOMAIN}." jq -r '.HostedZones[] | select(.Name==env.ROOT_DOMAIN) | .Id' | cut -d'/' -f3)
    _debug "ZONE_ID="${ZONE_ID}

    if [ -z ${ZONE_ID} ]; then
        _warn "ZONE_ID 값 조회 실패."
        return
    fi

    # ELB 에서 Hosted Zone ID 를 획득
    _command "aws elb describe-load-balancers --load-balancer-name ${ELB_NAME} | jq -r '.LoadBalancerDescriptions[] | .CanonicalHostedZoneNameID'"
    ELB_ZONE_ID=$(aws elb describe-load-balancers --load-balancer-name ${ELB_NAME} | jq -r '.LoadBalancerDescriptions[] | .CanonicalHostedZoneNameID')
    _debug "ELB_ZONE_ID="${ELB_ZONE_ID}

    if [ -z ${ELB_ZONE_ID} ]; then
        _warn "ELB_ZONE_ID 값 조회 실패."
        return
    fi

    # ELB 에서 DNS Name 을 획득
    _command "aws elb describe-load-balancers --load-balancer-name ${ELB_NAME} | jq -r '.LoadBalancerDescriptions[] | .DNSName'"
    ELB_DNS_NAME=$(aws elb describe-load-balancers --load-balancer-name ${ELB_NAME} | jq -r '.LoadBalancerDescriptions[] | .DNSName')
    _debug "ELB_DNS_NAME="${ELB_DNS_NAME}

    if [ -z ${ELB_DNS_NAME} ]; then
        _warn "ELB_DNS_NAME 값 조회 실패."
        return
    fi

    # record sets
    RECORD=${SHELL_DIR}/build/${CLUSTER_NAME}/record-sets-alias.json
    get_template templates/record-sets-alias.json ${RECORD}

    # replace
    _replace "s/DOMAIN/${SUB_DOMAIN}.${BASE_DOMAIN}/g" ${RECORD}
    _replace "s/ZONE_ID/${ELB_ZONE_ID}/g" ${RECORD}
    _replace "s/DNS_NAME/${ELB_DNS_NAME}/g" ${RECORD}

    cat ${RECORD}

    question "Would you like to change route53? (YES/[no]) : "

    if [ "${ANSWER}" == "YES" ]; then
        # update route53 record
        _command "aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}"
        aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}
    else
        _command "aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}"
    fi
    _debug "set_record_alias() 함수 실행 완료."
}

set_record_delete() {
    if [ -z ${ROOT_DOMAIN} ] || [ -z ${BASE_DOMAIN} ]; then
        return
    fi

    # Route53 에서 해당 도메인의 Hosted Zone ID 를 획득
    _command "aws route53 list-hosted-zones | ROOT_DOMAIN="${ROOT_DOMAIN}." jq -r '.HostedZones[] | select(.Name==env.ROOT_DOMAIN) | .Id' | cut -d'/' -f3"
    ZONE_ID=$(aws route53 list-hosted-zones | ROOT_DOMAIN="${ROOT_DOMAIN}." jq -r '.HostedZones[] | select(.Name==env.ROOT_DOMAIN) | .Id' | cut -d'/' -f3)

    if [ -z ${ZONE_ID} ]; then
        return
    fi

    # record sets
    RECORD=${SHELL_DIR}/build/${CLUSTER_NAME}/record-sets-delete.json
    get_template templates/record-sets-delete.json ${RECORD}

    # replace
    _replace "s/DOMAIN/${SUB_DOMAIN}.${BASE_DOMAIN}/g" ${RECORD}

    cat ${RECORD}

    # update route53 record
    _command "aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}"
    aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://${RECORD}
}

set_base_domain() {
    _debug "set_base_domain() 함수 실행 시작."

    POD="${1:-nginx-ingress}"
    _debug "POD="${POD}

    SUB_DOMAIN=${2:-"*"}
    _debug "SUB_DOMAIN="${SUB_DOMAIN}

    _result "Pending ELB..."

    _debug "BASE_DOMAIN="${BASE_DOMAIN}
    if [ -z ${BASE_DOMAIN} ]; then
        _debug "BASE_DOMAIN 값이 없으면 get_ingress_nip_io() 함수 호출한다."
        get_ingress_nip_io ${POD}
    else
        _debug "BASE_DOMAIN 값이 있으면 get_ingress_elb_name(), set_record_alias() 함수 호출한다."
        get_ingress_elb_name ${POD}

        set_record_alias
    fi
    _debug "set_base_domain() 함수 실행 완료."
}

get_base_domain() {

    _debug "get_base_domain() 함수 시작"

    SUB_DOMAIN=${1:-"*"}
    PREV_ROOT_DOMAIN="${ROOT_DOMAIN}"
    PREV_BASE_DOMAIN="${BASE_DOMAIN}"
    _debug "SUB_DOMAIN="$SUB_DOMAIN
    _debug "PREV_ROOT_DOMAIN="$PREV_ROOT_DOMAIN
    _debug "PREV_BASE_DOMAIN="$PREV_BASE_DOMAIN

    ROOT_DOMAIN=
    BASE_DOMAIN=

    # Root 도메인을 입력 받는다.
    read_root_domain
    _debug "ROOT_DOMAIN="${ROOT_DOMAIN}

    # base domain을 설정한다.
    if [ ! -z ${ROOT_DOMAIN} ]; then
        _debug "PREV_ROOT_DOMAIN="${PREV_ROOT_DOMAIN}
        _debug "ROOT_DOMAIN="${ROOT_DOMAIN}

        if [ "${PREV_ROOT_DOMAIN}" != "" ] && [ "${ROOT_DOMAIN}" == "${PREV_ROOT_DOMAIN}" ]; then
            _debug "PREV_ROOT_DOMAIN 값이 세팅되어 있고, ROOT_DOMAIN 값과 PREV_ROOT_DOMAIN 값이 동일하면 PREV_BASE_DOMAIN 값을 Default 값으로 설정합니다."
            DEFAULT="${PREV_BASE_DOMAIN}"
        else
            _debug "PREV_ROOT_DOMAIN 값이 없습니다. 클러스터 이름(ex, seoul-sre-jaden-eks)에서 3번째 문자 + "." + ROOT_DOMAIN 값을 Default 값으로 설정합니다."
            _debug "CLUSTER_NAME="${CLUSTER_NAME}
            _debug "echo ${CLUSTER_NAME} | cut -d'-' -f3"
            WORD=$(echo ${CLUSTER_NAME} | cut -d'-' -f3)
            _debug "WORD=${WORD}"
            DEFAULT="${WORD}.${ROOT_DOMAIN}"
            _debug "DEFAULT="${DEFAULT}
        fi

        _debug "도메인 설정 시 Route53 호스팅영역 > 레코드세트 목록 참고하여 설정해야 합니다."
        question "Enter your ingress domain, Route53 호스팅영역 > 레코드세트 목록 참고 [${DEFAULT}] : "
        _debug "ANSWER="${ANSWER}

        _debug "입력값이 없으면 기본값을 설정한다."
        BASE_DOMAIN=${ANSWER:-${DEFAULT}}

        if [[ "${BASE_DOMAIN}" == "istio"* ]]; then
            _debug "istio 설치인 경우 ISTIO_DOMAIN 변수를 설정한다."
            ISTIO_DOMAIN=${BASE_DOMAIN}
        fi
    else
        _error "Root 도메인값이 설정되지 않았습니다."
    fi
    _debug "BASE_DOMAIN="${BASE_DOMAIN}

    # certificate
    if [ ! -z ${BASE_DOMAIN} ]; then

        # SSL Cert ARN을 조회한다.
        get_ssl_cert_arn

        if [ -z ${SSL_CERT_ARN} ]; then
            _debug "ssl cert 정보가 조회되지 않아서 생성한다."
            req_ssl_cert_arn
        fi
        if [ -z ${SSL_CERT_ARN} ]; then
            _debug "ssl cert 생성 함수를 실행했는데도 정보가 없으면 에러 발생시킴."
            _error "Certificate ARN does not exists. [${ROOT_DOMAIN}][${SUB_DOMAIN}.${BASE_DOMAIN}][${REGION}]"
        fi

        _result "CertificateArn: ${SSL_CERT_ARN}"

        TEXT="aws-load-balancer-ssl-cert"
        _replace "s@${TEXT}:.*@${TEXT}: ${SSL_CERT_ARN}@" ${CHART}
        _debug "yaml 파일에서 문자열 치환"
        _debug "s@${TEXT}:.*@${TEXT}: ${SSL_CERT_ARN}@"

        TEXT="external-dns.alpha.kubernetes.io/hostname"
        _replace "s@${TEXT}:.*@${TEXT}: \"${SUB_DOMAIN}.${BASE_DOMAIN}.\"@" ${CHART}
        _debug "yaml 파일에서 문자열 치환"
        _debug "s@${TEXT}:.*@${TEXT}: \"${SUB_DOMAIN}.${BASE_DOMAIN}.\"@"

        _debug "yaml 파일 확인"
        _debug_cat ${CHART}
    fi

    # private ingress controller should not be BASE_DOMAIN
    if [[ "${BASE_DOMAIN}" == *"private"* ]] || [[ "${BASE_DOMAIN}" == "istio"* ]]; then

      question "Replace BASE_DOMAIN? ( YES(${BASE_DOMAIN}) / [No(${PREV_BASE_DOMAIN})] ) : "

      if [ "${ANSWER}" != "YES" ]; then
        BASE_DOMAIN="${PREV_BASE_DOMAIN}"
      fi

    fi

    CONFIG_SAVE=true
    _debug "get_base_domain() 함수 끝"
}

replace_chart() {
    _CHART=${1}
    _KEY=${2}
    _DEFAULT=${3}

    if [ "${_DEFAULT}" != "" ]; then
        question "Enter ${_KEY} [${_DEFAULT}] : "
        if [ "${ANSWER}" == "" ]; then
            ANSWER=${_DEFAULT}
        fi
    else
        question "Enter ${_KEY} : "
    fi

    _result "${_KEY}: ${ANSWER}"

    _replace "s|${_KEY}|${ANSWER}|g" ${CHART}
}

replace_password() {
    _debug "replace_password() 함수 시작"
    _CHART=${1}
    _KEY=${2:-PASSWORD}
    _DEFAULT=${3:-password}

    _debug "_CHART="${_CHART}
    _debug "_KEY="${_KEY}
    _debug "_DEFAULT="${_DEFAULT}

    password "Enter ${_KEY} [${_DEFAULT}] : "
    if [ "${ANSWER}" == "" ]; then
        ANSWER=${_DEFAULT}
    fi

    echo
    _result "${_KEY}: [hidden]"

    _replace "s|${_KEY}|${ANSWER}|g" ${_CHART}

    _debug_cat ${_CHART}
    _debug "replace_password() 함수 끝"
}

replace_base64() {
    _CHART=${1}
    _KEY=${2:-PASSWORD}
    _DEFAULT=${3:-password}

    password "Enter ${_KEY} [${_DEFAULT}] : "
    if [ "${ANSWER}" == "" ]; then
        ANSWER=${_DEFAULT}
    fi

    echo
    _result "${_KEY}: [encoded]"

    _replace "s|${_KEY}|$(echo ${ANSWER} | base64)|g" ${_CHART}
}

waiting_for() {
    progress start

    IDX=0
    while true; do
        if $@ ${IDX}; then
            break
        fi
        IDX=$(( ${IDX} + 1 ))
        progress ${IDX}
    done

    progress end
}

waiting_deploy() {
    _NS=${1}
    _NM=${2}
    SEC=${3:-10}

    _command "kubectl get deploy -n ${_NS} | grep ${_NM}"
    kubectl get deploy -n ${_NS} | head -1

    DEPLOY=${SHELL_DIR}/build/${THIS_NAME}/waiting-pod

    IDX=0
    while true; do
        kubectl get deploy -n ${_NS} | grep ${_NM} | head -1 > ${DEPLOY}
        cat ${DEPLOY}

        CURRENT=$(cat ${DEPLOY} | awk '{print $5}' | cut -d'/' -f1)
        _debug "CURRENT="${CURRENT}

        if [ "x${CURRENT}" != "x0" ]; then
            break
        elif [ "x${IDX}" == "x${SEC}" ]; then
            _result "Timeout"
            break
        fi

        IDX=$(( ${IDX} + 1 ))
        sleep 2
    done
}

waiting_pod() {
    _debug "waiting_pod() 함수 시작"

    _NS=${1}
    _NM=${2}
    SEC=${3:-100}

    #kubectl get pod -n ${_NS} | head -1

    POD=${SHELL_DIR}/build/${THIS_NAME}/waiting-pod

    _debug "pod 정보를 조회한다. Running 상태인지 확인하기 위해서. 최대 ${SEC}번 체크한다. 5초간 Sleep."
    _debug "kubectl get pod -n ${_NS} | grep ${_NM} | head -1 > ${POD}"
    _command "kubectl get pod -n ${_NS} | grep ${_NM}"
    IDX=0
    while true; do
        kubectl get pod -n ${_NS} | grep ${_NM} | head -1 > ${POD}
        cat ${POD}

        READY=$(cat ${POD} | awk '{print $2}' | cut -d'/' -f1)
        STATUS=$(cat ${POD} | awk '{print $3}')

        if [ "${STATUS}" == "Running" ] && [ "x${READY}" != "x0" ]; then
            _result "${_NM} pod installed successfully."
            break
        elif [ "${STATUS}" == "Error" ]; then
            _result "${STATUS}"
            break
        elif [ "${STATUS}" == "CrashLoopBackOff" ]; then
            _result "${STATUS}"
            break
        elif [ "x${IDX}" == "x${SEC}" ]; then
            _result "Timeout"
            break
        fi

        IDX=$(( ${IDX} + 1 ))
        sleep 5
    done

    _debug "waiting_pod() 함수 끝"
}

# entry point
run
