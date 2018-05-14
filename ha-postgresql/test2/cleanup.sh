#!/bin/bash
# Copyright 2017 - 2018 Crunchy Data Solutions, Inc.
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
while getopts "n:t:" opt; do
    case $opt in
        n)
            export NAMESPACE=${OPTARG}
            ;;
        t)
            export STORAGE_CLASS=${OPTARG}
            ;;
        *)
            ;;
    esac
done


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/common.sh
echo_info "Cleaning up.."

kubectl delete clusterrolebinding statefulset-sa

if [ ! -z ${NAMESPACE} ]; then
    kubectl delete -f statefulset.yaml -n $NAMESPACE
    if [ ! -z "$STORAGE_CLASS" ]; then
        kubectl delete -f statefulset-ceph-pv.yaml -n $NAMESPACE
        kubectl delete -f statefulset-ceph-pvc.yaml -n $NAMESPACE
    else
        kubectl delete -f statefulset-pv.yaml -n $NAMESPACE
        kubectl delete -f statefulset-pvc.yaml -n $NAMESPACE
    fi  
else
    kubectl delete -f statefulset.yaml
    if [ ! -z "$STORAGE_CLASS" ]; then
        kubectl delete -f statefulset-ceph-pv.yaml
        kubectl delete -f statefulset-ceph-pvc.yaml
    else
        kubectl delete -f statefulset-pv.yaml
        kubectl delete -f statefulset-pvc.yaml
    fi  
fi

rm -f $DIR/statefulset-pv.yaml $DIR/statefulset-pv1.yaml $DIR/statefulset-pvc.yaml $DIR/statefulset-ceph-pv.yaml $DIR/statefulset-ceph-pvc.yaml
