#!/usr/bin/env bash

# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# generate-internal-groups generates everything for a project with internal types, e.g. an
# user-provided API server based on k8s.io/apiserver.

if [ "$#" -lt 5 ] || [ "${1}" == "--help" ]; then
  cat <<EOF
Usage: $(basename "$0") <generators> <output-package> <internal-apis-package> <extensiona-apis-package> <groups-versions> ...

  <generators>        the generators comma separated to run (deepcopy,defaulter,conversion,client,lister,informer,openapi) or "all".
  <output-package>    the output package name (e.g. github.com/example/project/pkg/generated).
  <int-apis-package>  the internal types dir (e.g. github.com/example/project/pkg/apis).
  <ext-apis-package>  the external types dir (e.g. github.com/example/project/pkg/apis or githubcom/example/apis).
  <groups-versions>   the groups and their versions in the format "groupA:v1,v2 groupB:v1 groupC:v2", relative
                      to <api-package>.
  ...                 arbitrary flags passed to all generator binaries.

Examples:
  $(basename "$0") all                           github.com/example/project/pkg/client github.com/example/project/pkg/apis github.com/example/project/pkg/apis "foo:v1 bar:v1alpha1,v1beta1"
  $(basename "$0") deepcopy,defaulter,conversion github.com/example/project/pkg/client github.com/example/project/pkg/apis github.com/example/project/apis     "foo:v1 bar:v1alpha1,v1beta1"
EOF
  exit 0
fi

GENS="$1"
OUTPUT_PKG="$2"
INT_APIS_PKG="$3"
EXT_APIS_PKG="$4"
GROUPS_WITH_VERSIONS="$5"
shift 5

export GO111MODULE=on

go install k8s.io/code-generator/cmd/defaulter-gen \
    k8s.io/code-generator/cmd/client-gen \
    k8s.io/code-generator/cmd/lister-gen \
    k8s.io/code-generator/cmd/informer-gen \
    k8s.io/code-generator/cmd/deepcopy-gen \
    k8s.io/code-generator/cmd/openapi-gen \
    k8s.io/code-generator/cmd/conversion-gen \
    k8s.io/code-generator/cmd/defaulter-gen \
    sigs.k8s.io/apiserver-builder-alpha/cmd/apiregister-gen

function codegen::join() { local IFS="$1"; shift; echo "$*"; }

APIS_DIR=("${INT_APIS_PKG}/...")
CLIENT_OUTPUT_PKG=("${OUTPUT_PKG}/client")

# enumerate group versions
ALL_FQ_APIS=() # e.g. k8s.io/kubernetes/pkg/apis/apps k8s.io/api/apps/v1
INT_FQ_APIS=() # e.g. k8s.io/kubernetes/pkg/apis/apps
EXT_FQ_APIS=() # e.g. k8s.io/api/apps/v1
for GVs in ${GROUPS_WITH_VERSIONS}; do
  IFS=: read -r G Vs <<<"${GVs}"
  IFS=. read -r GROUP_PATH SUFFIX <<<"${G}"

  if [ -n "${INT_APIS_PKG}" ]; then
    ALL_FQ_APIS+=("${INT_APIS_PKG}/${GROUP_PATH}")
    INT_FQ_APIS+=("${INT_APIS_PKG}/${GROUP_PATH}")
  fi

  # enumerate versions
  for V in ${Vs//,/ }; do
    ALL_FQ_APIS+=("${EXT_APIS_PKG}/${GROUP_PATH}/${V}")
    EXT_FQ_APIS+=("${EXT_APIS_PKG}/${GROUP_PATH}/${V}")
  done
done

# apiregister-gen generate the REST boilerplate of resources and their internal version
if [ "${GENS}" = "all" ] || grep -qw "registry" <<<"${GENS}"; then
  echo "Generating api registries"
  "${GOPATH}/bin/apiregister-gen" --input-dirs "$(codegen::join , "${APIS_DIR[@]}")" "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "deepcopy" <<<"${GENS}"; then
  echo "Generating deepcopy funcs"
  "${GOPATH}/bin/deepcopy-gen" --input-dirs "$(codegen::join , "${ALL_FQ_APIS[@]}")" -O zz_generated.deepcopy --bounding-dirs "${INT_APIS_PKG},${EXT_APIS_PKG}" "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "defaulter" <<<"${GENS}"; then
  echo "Generating defaulters"
  "${GOPATH}/bin/defaulter-gen"  --input-dirs "$(codegen::join , "${ALL_FQ_APIS[@]}")" -O zz_generated.defaults "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "conversion" <<<"${GENS}"; then
  echo "Generating conversions"
  "${GOPATH}/bin/conversion-gen" --input-dirs "$(codegen::join , "${ALL_FQ_APIS[@]}")" -O zz_generated.conversion "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "client" <<<"${GENS}"; then
  echo "Generating clientset for ${GROUPS_WITH_VERSIONS} at ${CLIENT_OUTPUT_PKG}/${CLIENTSET_PKG_NAME:-clientset}"
  if [ -n "${INT_APIS_PKG}" ]; then
    IFS=" " read -r -a APIS <<< "$(printf '%s/ ' "${INT_FQ_APIS[@]}")"
    "${GOPATH}/bin/client-gen" --clientset-name "${CLIENTSET_NAME_INTERNAL:-internalversion}" --input-base "" --input "$(codegen::join , "${APIS[@]}")" --output-package "${CLIENT_OUTPUT_PKG}/${CLIENTSET_PKG_NAME:-clientset}" "$@"
  fi
  "${GOPATH}/bin/client-gen" --clientset-name "${CLIENTSET_NAME_VERSIONED:-versioned}" --input-base "" --input "$(codegen::join , "${EXT_FQ_APIS[@]}")" --output-package "${CLIENT_OUTPUT_PKG}/${CLIENTSET_PKG_NAME:-clientset}" "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "lister" <<<"${GENS}"; then
  echo "Generating listers for ${GROUPS_WITH_VERSIONS} at ${CLIENT_OUTPUT_PKG}/listers"
  "${GOPATH}/bin/lister-gen" --input-dirs "$(codegen::join , "${ALL_FQ_APIS[@]}")" --output-package "${CLIENT_OUTPUT_PKG}/listers" "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "informer" <<<"${GENS}"; then
  echo "Generating informers for ${GROUPS_WITH_VERSIONS} at ${CLIENT_OUTPUT_PKG}/informers"
  "${GOPATH}/bin/informer-gen" \
           --input-dirs "$(codegen::join , "${ALL_FQ_APIS[@]}")" \
           --versioned-clientset-package "${CLIENT_OUTPUT_PKG}/${CLIENTSET_PKG_NAME:-clientset}/${CLIENTSET_NAME_VERSIONED:-versioned}" \
           --internal-clientset-package "${CLIENT_OUTPUT_PKG}/${CLIENTSET_PKG_NAME:-clientset}/${CLIENTSET_NAME_INTERNAL:-internalversion}" \
           --listers-package "${CLIENT_OUTPUT_PKG}/listers" \
           --output-package "${CLIENT_OUTPUT_PKG}/informers" \
           "$@"
fi

if [ "${GENS}" = "all" ] || grep -qw "openapi" <<<"${GENS}"; then
  echo "Generating OpenAPI definitions for ${GROUPS_WITH_VERSIONS} at ${OUTPUT_PKG}/openapi"
  "${GOPATH}/bin/openapi-gen" \
           --input-dirs "$(codegen::join , "${EXT_FQ_APIS[@]}")" \
           --input-dirs "k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/api/core/v1" \
           --output-package "${OUTPUT_PKG}/openapi" \
           -O zz_generated.openapi \
           "$@"
fi
