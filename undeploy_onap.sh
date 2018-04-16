#!/usr/bin/env bash

: "${NAMESPACE:=onap}"
: "${DEPLOYMENT:=dev}"
: "${WORKING_DIR:=$HOME}"
SCRIPT_DIR=$(pwd)

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }

title "Undeploying ONAP"
helm delete $DEPLOYMENT --purge
oc delete project $NAMESPACE

