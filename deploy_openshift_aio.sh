#!/usr/bin/env bash

SCRIPT_DIR=$(pwd)
: "${OC_URL:=https://github.com/openshift/origin/releases/download/v3.9.0/openshift-origin-client-tools-v3.9.0-191fece-linux-64bit.tar.gz}"
: "${KUBECTL_VERSION:=v1.9.1}"
: "${HELM_VERSION:=v2.8.2}"
: "${TILLER_NAMESPACE:=kube-system}"
OC_TARFILE=$(basename $OC_URL)
OC_DIR=$(basename -s .tar.gz $OC_URL)
PATH_NODE_CONFIG=/var/lib/origin/openshift.local.config/node-localhost/node-config.yaml
HELM_URL=https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-linux-amd64.tar.gz
HELM_TARFILE=$(basename $HELM_URL)

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }

title "Installing requirements"
sudo yum install -y docker
sudo yum remove -y kubernetes-client

# configure host as described in https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md
title "Configuring host"
sudo /sbin/sysctl -w net.ipv4.ip_forward=1

echo "Enabling use of insecure Docker registries..."
echo '{"insecure-registries": ["172.30.0.0/16"] }' | sudo tee /etc/docker/daemon.json > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

if ! sudo firewall-cmd --zone=dockerc --list-all &> /dev/null; then
    echo "Adding firewall zone 'dockerc' and opening UI and DNS ports..."
    SUBNET=$(sudo docker network inspect -f "{{range .IPAM.Config }}{{ .Subnet }}{{end}}" bridge)
    sudo firewall-cmd --permanent --new-zone dockerc
    sudo firewall-cmd --permanent --zone dockerc --add-source $SUBNET
    sudo firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
    sudo firewall-cmd --permanent --zone dockerc --add-port 53/udp
    sudo firewall-cmd --permanent --zone dockerc --add-port 8053/udp
    sudo firewall-cmd --reload
fi

title "Downloading and installing OpenShift client tool"
cd /tmp
wget -nv -nc $OC_URL
tar -xf $OC_TARFILE 2> /dev/null
sudo cp -- "$OC_DIR/oc" /usr/bin/
sudo chmod +x /usr/bin/oc
rm -r $OC_DIR $OC_TARFILE
cd $SCRIPT_DIR
oc version

title "Initializing OpenShift AIO cluster"
oc cluster up --service-catalog=true --public-hostname=$(hostname -f)
oc cluster down

title "Reconfiguring OpenShift AIO cluster"
if ! grep "pods-per-core" $PATH_NODE_CONFIG; then
  sed -i -e "s/kubeletArguments:/kubeletArguments:\n  pods-per-core:\n  - \"0\"/" $PATH_NODE_CONFIG
  echo "Set pods-per-node."
else
  echo "Configuration completed previously."
fi

title "Bringing up OpenShift AIO cluster"
oc cluster up --use-existing-config --service-catalog=true --public-hostname=$(hostname -f)

title "Logging into the OpenShift AIO cluster"
oc login -u system:admin

title "Installing kubectl client $KUBECTL_VERSION"
cd /tmp
curl -LO https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl
cd $SCRIPT_DIR

title "Installing Tiller server $HELM_VERSION"
if ! oc project $TILLER_NAMESPACE 2> /dev/null; then
  oc new-project $TILLER_NAMESPACE
fi
oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="$TILLER_NAMESPACE" -p HELM_VERSION="$HELM_VERSION" | oc create -f -
oc rollout status deployment tiller
oc adm policy add-cluster-role-to-user cluster-admin -z tiller -n $TILLER_NAMESPACE
oc expose deployment/tiller --target-port tiller --type=NodePort --name=tiller -n $TILLER_NAMESPACE

title "Installing Helm client $HELM_VERSION"
cd /tmp
wget -nv $HELM_URL
tar -xf $HELM_TARFILE 2> /dev/null
sudo rm /usr/bin/helm
sudo cp linux-amd64/helm /usr/bin/helm
rm -r linux-amd64 $HELM_TARFILE
cd $SCRIPT_DIR
helm init --client-only --tiller-namespace=$TILLER_NAMESPACE
export HELM_HOME
helm version
