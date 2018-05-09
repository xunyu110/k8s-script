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
export CCP_STORAGE_CAPACITY=5Gi
export CCP_STORAGE_MODE=ReadWriteMany
export CCP_STORAGE_PATH=/Users/hawick/pgdata-0

while getopts ":n" opt; do
    case $opt in
        n)
            NAMESPACE="$OPTARG"
            kubectl create namespace $NAMESPACE
            ;;
    esac
done


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${DIR}/common.sh

${DIR}/cleanup.sh

create_storage "statefulset"
if [[ $? -ne 0 ]]
then
    echo_err "Failed to create storage, exiting.."
    exit 1
fi

# As of Kube 1.6, it is necessary to allow the service account to perform
# a label command. For this example, we open up wide permissions
# for all serviceaccounts. This is NOT for production!

kubectl create clusterrolebinding statefulset-sa \
  --clusterrole=cluster-admin \
  --user=admin \
  --user=kubelet \
  --group=system:serviceaccounts \
  --namespace=$NAMESPACE

kubectl create -f $DIR/statefulset.json
