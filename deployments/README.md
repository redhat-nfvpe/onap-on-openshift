# ONAP on OpenShift using AWS

In this directory you can spin up some biased infrastructure for an OpenShift
deployment in AWS using Ansible and the playbooks provided.

## Prerequisites

You'll need to provide IAM user credentials to your control machine (laptop for
example) to authenticate against the AWS EC2 API. An IAM user can be created in
the AWS dashboard, and the only permissions that should be required is
`AmazonEC2FullAccess`.

Once you have the access key and access secret for that user, you'll need to
export those credentials into two environment variables on your host machine
for Ansible to use.

    export AWS_ACCESS_KEY_ID=abcd1234
    export AWS_SECRET_ACCESS_KEY=zyxw9876

## Deployment

First, modify the `inventory/vars.yml` or copy it into another location as
you'll need to pass this to Ansible. Once that is done, you can spin up the
infrastructure with the following command.

    ansible-playbook -e "@./inventory/vars.yml" playbooks/main.yml

## TODO

<More to follow>
