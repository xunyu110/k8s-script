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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${DIR}/common.sh
echo_info "Cleaning up.."

kubectl delete statefulset statefulset
kubectl delete sa statefulset-sa
kubectl delete clusterrolebinding statefulset-sa
kubectl delete pvc statefulset-pgdata
if [ -z "$CCP_STORAGE_CLASS" ]; then
  kubectl delete pv statefulset-pgdata
fi
kubectl delete service statefulset statefulset-primary statefulset-replica
kubectl delete pod statefulset-0 statefulset-1
if [ -z "$NAMESPACE" ]; then
  kubectl delete namespace $NAMESPACE
fi
