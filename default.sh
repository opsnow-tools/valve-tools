#!/bin/bash

THIS_REPO="opsnow"
THIS_NAME="valve-tools"
THIS_VERSION="v0.0.0"

# true로 설정하면 _debug(), _debug_cat() 함수가 동작합니다.
# 기본값은 false 입니다.
DEBUG_MODE=false

CONFIG=
CONFIG_SAVE=

ANSWER=
CLUSTER=

REGION=
AZ_LIST=

KOPS_STATE_STORE=
KOPS_CLUSTER_NAME=
KOPS_TERRAFORM=

CLUSTER_NAME=

ROOT_DOMAIN=
BASE_DOMAIN=

CERT_MAN=
EFS_ID=
ISTIO=

cloud=aws
master_size=c4.large
master_count=1
master_zones=
node_size=m4.large
node_count=2
zones=
network_cidr=10.0.0.0/16
networking=calico
topology=public
dns_zone=
vpc=
