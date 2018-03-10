#!/usr/bin/env bash

OC_URL=https://github.com/openshift/origin/releases/download/v3.7.1/openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
#OC_URL=https://github.com/openshift/origin/releases/download/v3.9.0-alpha.3/openshift-origin-client-tools-v3.9.0-alpha.3-78ddc10-linux-64bit.tar.gz
OC_TARFILE=$(basename $OC_URL)
OC_DIR=$(basename -s .tar.gz $OC_URL)
KUBECTL_VERSION=v1.7.12
HELM_VERSION=v2.8.1
HELM_URL=https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-linux-amd64.tar.gz
HELM_TARFILE=$(basename $HELM_URL)
TILLER_NAMESPACE=kube-system

# install requirements
echo -e "\n== Installing requirements =="
sudo yum install -y docker
sudo yum remove -y kubernetes-client

# configure host as described in https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md
echo -e "\n== Configuring host =="
sudo /sbin/sysctl -w net.ipv4.ip_forward=1

echo '{"insecure-registries": ["172.30.0.0/16"] }' | sudo tee /etc/docker/daemon.json > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

if ! sudo firewall-cmd --zone=dockerc --list-all &> /dev/null; then
    SUBNET=$(sudo docker network inspect -f "{{range .IPAM.Config }}{{ .Subnet }}{{end}}" bridge)
    sudo firewall-cmd --permanent --new-zone dockerc
    sudo firewall-cmd --permanent --zone dockerc --add-source $SUBNET
    sudo firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
    sudo firewall-cmd --permanent --zone dockerc --add-port 53/udp
    sudo firewall-cmd --permanent --zone dockerc --add-port 8053/udp
    sudo firewall-cmd --reload
fi

# install the OpenShift client tool
echo -e "\n== Downloading and installing OpenShift client tool =="
cd /tmp
wget -nv -nc $OC_URL
tar -xf $OC_TARFILE 2> /dev/null
sudo cp $OC_DIR/oc /usr/bin/
sudo chmod +x /usr/bin/oc
rm -r $OC_DIR $OC_TARFILE
cd -
oc version

# deploy the AIO OpenShift cluster
echo -e "\n== Deploying OpenShift AIO cluster =="
oc cluster up --service-catalog=true --public-hostname=$(hostname -f)

# log into OpenShift cluster
echo -e "\n== Logging into the OpenShift AIO cluster =="
oc login -u system:admin

# install kubectl client
echo -e "\n== Installing kubectl client $KUBECTL_VERSION =="
cd /tmp
curl -LO https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/kubectl
cd -

# install Tiller into the cluster
echo -e "\n== Installing Tiller server $HELM_VERSION =="
oc project kube-system
oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" -p HELM_VERSION="$HELM_VERSION" | oc create -f -
oc rollout status deployment tiller
oc adm policy add-cluster-role-to-user cluster-admin -z tiller -n ${TILLER_NAMESPACE}
oc expose deployment/tiller --target-port tiller --type=NodePort --name=tiller -n ${TILLER_NAMESPACE}

# install Helm client
echo -e "\n== Installing Helm client $HELM_VERSION =="
cd /tmp
wget -nv -nc $HELM_URL
tar -xf $HELM_TARFILE 2> /dev/null
sudo cp linux-amd64/helm /usr/bin/
rm -r linux-amd64 $HELM_TARFILE
cd -
helm init --client-only
export HELM_HOME
helm version

