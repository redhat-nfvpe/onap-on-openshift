# ONAP on Openshift
## About
This repo contains scripts to make it very easy to deploy
[ONAP](https://www.onap.org/) on an [OpenShift](https://www.openshift.org/)
cluster. OpenShift is an enterprise-grade Kubernetes distribution with security hardening, pre-integrated
application lifecycle management functionality, and DevOps tooling.

Deployment consists of two simple steps:
1. Deploy an OpenShift cluster.
  * "all-in-one" on a single baremetal or virtual machine. Choose this option for a simple ONAP test-drive or for ONAP development.
  * "multi-node" (coming soon) on a public or private cloud. Choose this option for
  a more production-like environment.
1. Deploy ONAP.

## 1. Deploy an OpenShift Cluster
### All-in-one Cluster
Prerequisites:
* A physical or virtual machine (e.g. from a public cloud provider) min. 64GB RAM, 8 CPU cores, and 200GB disk for a full ONAP install (note that the requirements for OpenShift itself are negligible in comparison).
* RHEL or CentOS 7.4 or higher installed.
* User with privileges to `sudo` into root.

To deploy Openshift:

    git clone https://github.com/redhat-nfvpe/onap-on-openshift.git
    cd onap-on-OpenShift
    ./deploy_openshift_aio.sh

To undeploy OpenShift:

    ./undeploy_openshift_aio.sh

Notes:

That script takes care of the host configuration (package dependencies, firewall rules, etc.), installs the `oc` client tool, deploys an OpenShift Origin v3.9 cluster without pods-per-core limit, and installs matching `kubectl` and `helm` clients.

### Multi-node Cluster
Coming soon.

## 2. Deploy ONAP
Prerequisites:
* Valid login into a running OpenShift cluster (handled by step 1).

To deploy ONAP:

    ./deploy_onap.sh

To undeploy ONAP (note this may take several 10mins!):

    ./undeploy_onap.sh

Notes:

This script clones the ONAP Operations Manager (OOM) repo and automates the steps described in the [User Guide](http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_user_guide.html#user-guide-label) to configure and deploy ONAP.

To modify which ONAP services are deployed, edit the file `configs/onap-config.yaml` to enable or disable ONAP services before running `deploy_onap.sh`.
