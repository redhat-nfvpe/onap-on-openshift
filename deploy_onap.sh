#!/usr/bin/env bash

NS=onap
WORKING_DIR=$HOME
SCRIPT_DIR=$(pwd)


echo -e "\n== Relax OpenShift security constraints =="
# enable access to hostPaths
sudo setenforce 0  # required to allow hostPath volumes
#oc adm policy add-scc-to-user hostmount-anyuid -n $NS -z default
# work around ONAP images built using uid 0 or not supporting randomized uids
oc adm policy add-scc-to-group anyuid system:authenticated
#oc adm policy add-scc-to-user anyuid -n $NS -z default
oc adm policy add-scc-to-user privileged -n $NS -z default
#oc adm policy add-cluster-role-to-user cluster-admin -n $NS -z default

#echo -e "\n== Install nfs-provisioner resources =="
#oc create -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs/deploy/kubernetes/auth/serviceaccount.yaml
#oc create -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs/deploy/kubernetes/auth/openshift-scc.yaml
#oc create -f https://raw.githubusercontent.com/kubernetes-incubator/external-storage/master/nfs/deploy/kubernetes/auth/openshift-clusterrole.yaml
#oc adm policy add-scc-to-user nfs-provisioner system:serviceaccount:default:nfs-provisioner

echo -e "\n== Download OOM =="
rm -r $WORKING_DIR/oom
git clone http://gerrit.onap.org/r/oom $WORKING_DIR/oom
cd $WORKING_DIR/oom

echo -e "\n== Patch OOM =="
for p in $SCRIPT_DIR/patches/*.patch; do
  echo "Applying patch $p..."
  git apply $p
done

echo -e "\n== Configure ONAP =="
# change hardcoded cluster subnet to OpenShift's cluster subnet
cd $WORKING_DIR/oom/kubernetes
sed -i 's/10.43.255.254/172.30.255.254/' ./aai/values.yaml
sed -i 's/10.43.255.254/172.30.255.254/' ./policy/values.yaml
# populate dummy OpenStack params
cd config
cp onap-parameters-sample.yaml onap-parameters.yaml
# create config hostDir
chmod +x ./createConfig.sh
./createConfig.sh -n $NS

echo -e "\n== Deploy ONAP =="
cd ../oneclick
chmod +x tools/*.bash
./createAll.bash -n $NS

