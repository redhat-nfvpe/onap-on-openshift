#!/usr/bin/env bash

SCRIPT_DIR=$(pwd)
: "${WORKING_DIR:=$HOME/.ooo}"
: "${NAMESPACE:=onap}"
: "${DEPLOYMENT:=dev}"

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }

title "Undeploying ONAP"
helm delete $DEPLOYMENT --purge
oc delete project $NAMESPACE
