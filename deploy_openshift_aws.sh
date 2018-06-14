#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(pwd)
: "${WORKING_DIR:=$HOME/.ooo}"
: "${OC_URL:=https://github.com/openshift/origin/releases/download/v3.9.0/openshift-origin-client-tools-v3.9.0-191fece-linux-64bit.tar.gz}"
: "${KUBECTL_VERSION:=v1.9.1}"
: "${HELM_VERSION:=v2.8.2}"
: "${TILLER_NAMESPACE:=kube-system}"
: "${SSH_KEY:=$WORKING_DIR/keys/id_rsa_openshift_ansible}"
: "${AWS_SSH_KEY_PAIR_NAME:=openshift_ansible}"
OC_TARFILE=$(basename "$OC_URL")
OC_DIR=$(basename -s .tar.gz "$OC_URL")
HELM_URL="https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-linux-amd64.tar.gz"
HELM_TARFILE=$(basename "$HELM_URL")

if [[ ! "$AWS_ACCESS_KEY_ID" || ! "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "You need to provide both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:"
  echo "export AWS_ACCESS_KEY_ID=AKI..."
  echo "export AWS_SECRET_ACCESS_KEY=..."
  exit -1
fi
if [[ ! "$DNS_DOMAIN" ]]; then
  echo "You need to provide the domain name registered with Route53:"
  echo "export DNS_DOMAIN=example.com"
  exit -1
fi

title() { echo -e "\E[34m\n== $1 ==\E[00m"; }


title "Installing requirements"
sudo yum install -y docker python-botocore python-boto python-boto3 awscli
sudo yum remove -y kubernetes-client && true


title "Generating and uploading SSH key"
KEYDIR=$(dirname "$SSH_KEY")
mkdir -p "$KEYDIR"

if [[ ! -e "$SSH_KEY" ]]; then
  echo "Generating SSH key $SSH_KEY"
  ssh-keygen -t rsa -b 4096 -N '' -C "openshift_ansible" -f "$SSH_KEY"
else
  echo "Using existing SSH key $SSH_KEY"
fi

echo "Importing SSH key to AWS"
mkdir -p "$HOME/.aws"
cat <<EOF >"$HOME/.aws/credentials"
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF
cat <<EOF >"$HOME/.aws/config"
[default]
region = us-east-1
EOF
aws ec2 delete-key-pair --key-name "openshift_ansible"
aws ec2 import-key-pair --key-name "openshift_ansible" \
  --public-key-material file://$SSH_KEY.pub


title "Generating TLS certificate"
if [[ ! -e "$KEYDIR/Certificate.pem" ]]; then
  echo "Generating self-signed cert $KEYDIR/Certificate.pem"
  cd $KEYDIR

  cat <<EOF >Certificate.cnf
[ req ]
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[ req_distinguished_name ]
C  = US
ST = MA
L  = Westford
CN = *.$DNS_DOMAIN

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $DNS_DOMAIN
DNS.2 = *.$DNS_DOMAIN
EOF

  # generate RSA private key
  openssl genrsa 2048 > PrivateKey.pem

  # create CSR
  openssl req -new -batch \
    -key PrivateKey.pem \
    -config Certificate.cnf \
    -out Certificate.csr

  # create certificate
  openssl x509 -req -days 365 \
    -extensions v3_req -extfile Certificate.cnf \
    -signkey PrivateKey.pem \
    -in Certificate.csr \
    -out Certificate.pem
else
  echo "Using existing certificate $KEYDIR/Certificate.pem"
fi


title "Deploying OpenShift cluster on AWS"
cd "$WORKING_DIR"

rm -rf inventory
mkdir inventory
cp "$SCRIPT_DIR/inventory/aws_provisioning_inventory.ini" inventory/
cp "$SCRIPT_DIR/inventory/aws_provisioning_vars.yml" inventory/

rm -rf openshift-ansible
git clone https://github.com/openshift/openshift-ansible.git
cd openshift-ansible
git checkout release-3.9

for playbook in prerequisites build_ami provision install provision_nodes accept; do
  title "Deploying OpenShift cluster on AWS (stage: $playbook)"
  ansible-playbook \
    -i ../inventory/aws_provisioning_inventory.ini \
    -e @../inventory/aws_provisioning_vars.yml \
    --private-key=$SSH_KEY \
    playbooks/aws/openshift-cluster/$playbook.yml
done


title "Downloading and installing OpenShift client tool"
cd /tmp
wget -nv -nc $OC_URL
tar -xf $OC_TARFILE 2> /dev/null
sudo cp -- "$OC_DIR/oc" /usr/bin/
sudo chmod +x /usr/bin/oc
rm -r $OC_DIR $OC_TARFILE
cd $SCRIPT_DIR
oc version


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
