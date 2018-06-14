#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(pwd)
: "${WORKING_DIR:=$HOME/.ooo}"
: "${SSH_KEY:=$WORKING_DIR/keys/id_rsa_openshift_ansible}"

if [[ ! "$AWS_ACCESS_KEY_ID" || ! "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "You need to provide both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:"
  echo "export AWS_ACCESS_KEY_ID=AKI..."
  echo "export AWS_SECRET_ACCESS_KEY=..."
  exit -1
fi

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }

title "Undeploying OpenShift cluster"
cd "$WORKING_DIR/openshift-ansible"
ansible-playbook \
  -i ../inventory/aws_provisioning_inventory.ini \
  -e @../inventory/aws_provisioning_vars.yml \
  --private_key=$SSH_KEY \
  playbooks/aws/openshift-cluster/uninstall.yml

# rm -rf ~/.kube ~/.helm
echo "Done."
