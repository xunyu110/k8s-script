#!/bin/bash
# Copyright 2018 Crunchy Data Solutions, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

function echo_err() {
    echo -e "${RED?}$(date) ERROR: ${1?}${RESET?}"
}

function echo_info() {
    echo -e "${GREEN?}$(date) INFO: ${1?}${RESET?}"
}

function echo_warn() {
    echo -e "${YELLOW?}$(date) WARN: ${1?}${RESET?}"
}

function env_check_err() {
    if [[ -z ${!1} ]]
    then
        echo_err "$1 environment variable is not set, aborting.."
        exit 1
    fi
}

function create_storage {
    env_check_err "STORAGE_CAPACITY"

    if [ ! -z "$STORAGE_CLASS" ]; then
        echo_info "CCP_STORAGE_CLASS is set. Using the existing storage class for the PV."
        sed 's@$STORAGE_CAPACITY@'"$STORAGE_CAPACITY"'@' $DIR/statefulset-ceph-pv.yaml.template > $DIR/statefulset-ceph-pv.yaml
        sed 's@$STORAGE_CAPACITY@'"$STORAGE_CAPACITY"'@' $DIR/statefulset-ceph-pvc.yaml.template > $DIR/statefulset-ceph-pvc.yaml
        kubectl create -f $DIR/$1-ceph-pv.yaml

        if [ -z "$NAMESPACE" ]; then
            kubectl create -f $DIR/$1-ceph-pvc.yaml
        else
            kubectl create -f $DIR/$1-ceph-pvc.yaml -n $NAMESPACE
        fi

        echo_info "Created ceph volume"
    else
        echo_info "STORAGE_CLASS not set. Creating HostPath based storage volumes."
        mkdir $DIR/pgdata-0
        export MOUNT_PATH=$DIR/pgdata-0
        sed 's@$STORAGE_CAPACITY@'"$STORAGE_CAPACITY"'@' $DIR/statefulset-pv.yaml.template > $DIR/statefulset-pv1.yaml
        sed 's@$STORAGE_CAPACITY@'"$STORAGE_CAPACITY"'@' $DIR/statefulset-pvc.yaml.template > $DIR/statefulset-pvc.yaml
        sed 's@$MOUNT_PATH@'"$MOUNT_PATH"'@' $DIR/statefulset-pv1.yaml > $DIR/statefulset-pv.yaml
        
        kubectl create -f $DIR/$1-pv.yaml

        if [ -z "$NAMESPACE" ]; then
            kubectl create -f $DIR/$1-pvc.yaml
        else
            kubectl create -f $DIR/$1-pvc.yaml -n $NAMESPACE
        fi
        
        echo_info "Created hostpath volume"
    fi

}
