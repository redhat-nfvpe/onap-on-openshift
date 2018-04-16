#!/usr/bin/env bash

SCRIPT_DIR=$(pwd)
: "${NAMESPACE:=onap}"
: "${DEPLOYMENT:=dev}"
: "${WORKING_DIR:=$HOME}"
: "${OOM_COMMIT:=HEAD}"
: "${CONFIG_FILE:=$SCRIPT_DIR/configs/onap-config.yaml}"

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }

title "Relaxing OpenShift security constraints"
# enable access to hostPaths
sudo setenforce 0  # required to allow hostPath volumes
# work around ONAP images built using uid 0 or not supporting randomized uids
oc adm policy add-scc-to-group anyuid system:authenticated
oc adm policy add-scc-to-user privileged -n $NAMESPACE -z default

title "Downloading OOM"
rm -r $WORKING_DIR/oom
git clone http://gerrit.onap.org/r/oom $WORKING_DIR/oom
cd $WORKING_DIR/oom
if [ "$OOM_COMMIT" != "HEAD" ]; then
  git reset --hard $OOM_COMMIT
fi

title "Applying OOM patches (if any)"
for patch in $SCRIPT_DIR/patches/*.patch; do
  if [[ ! -e "$patch" ]]; then
    echo "No patches to apply."
    break
  fi
  echo "Applying patch $patch..."
  git apply "$patch"
done

title "Setting up local Chart repo"
if [ -z "$(ps -ef | grep -v grep | grep 'helm serve')" ]; then
  helm serve &
else
  echo "Helm server already running."
fi
helm repo remove stable 2> /dev/null

title "Populating local Chart repo with ONAP Charts"
cd $WORKING_DIR/oom/kubernetes
make all

#title "Configuring ONAP"
# populate dummy OpenStack params
#cd config
#cp onap-parameters-sample.yaml onap-parameters.yaml

title "Deploying ONAP"
if [[ -e $CONFIG_FILE ]]; then
  helm install local/onap -f $SCRIPT_DIR/configs/onap-config.yaml --name=$DEPLOYMENT --namespace=$NAMESPACE
else
  helm install local/onap --name=$DEPLOYMENT --namespace=$NAMESPACE
fi

