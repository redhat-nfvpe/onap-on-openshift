#!/usr/bin/env bash

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }

title "Undeploying OpenShift AIO"
oc cluster down
rm -rf ~/.kube ~/.helm
echo "Done."

