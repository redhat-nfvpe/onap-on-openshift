#!/usr/bin/env bash

NS=onap
WORKING_DIR=$HOME

echo -e "\n== Undeploy ONAP =="
cd $WORKING_DIR/oom/kubernetes/oneclick/tools
./autoCleanConfig.bash $NS
