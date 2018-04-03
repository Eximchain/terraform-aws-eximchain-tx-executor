Table of Contents
=================

   * [Warning](#warning)
   * [Work In Progress](#work-in-progress)
   * [Quick Start Guide](#quick-start-guide)
      * [Prerequisites](#prerequisites)
   * [Generate SSH key for EC2 instances](#generate-ssh-key-for-ec2-instances)
      * [Build AMIs to launch the instances with](#build-amis-to-launch-the-instances-with)
      * [Launch Network with Terraform](#launch-network-with-terraform)
      * [Launch and configure vault](#launch-and-configure-vault)
         * [Unseal additional vault servers](#unseal-additional-vault-servers)
      * [Access Other Components](#access-other-components)
      * [Destroy the Network](#destroy-the-network)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc)


# Warning
This software launches and uses real AWS resources. It is not a demo or test. By using this software, you will incur the costs of any resources it uses in your AWS account.

# Work In Progress
This repository is a work in progress. A more complete version of this README and code is coming soon.

# Quick Start Guide

## Prerequisites

* You must have AWS credentials at the default location (typically `~/.aws/credentials`)
* You must have the following programs installed on the machine you will be using to launch the network:
    * Python 2.7
    * Hashicorp Packer
    * Hashicorp Terraform

# Generate SSH key for EC2 instances

Generate an RSA key with ssh-keygen. This only needs to be done once. If you change the output file location you must change the key paths in the terraform variables file later.

```sh
$ ssh-keygen -t rsa -f ~/.ssh/quorum
# Enter a password if you wish
```

Add the key to your ssh agent. This must be done again if you restart your computer. If this is not done, it will cause problems provisioning the instances with terraform.

```sh
$ ssh-add ~/.ssh/quorum
# Enter your password if there is one
```

## Build AMIs to launch the instances with

Use packer to build the AMIs needed to launch instances

```sh
$ cd packer
$ packer build vault-consul.json
# Wait for build
$ packer build transaction-executor.json
# Wait for build
$ cd ..
```

Then copy the AMIs to into terraform variables

```sh
$ python copy-packer-artifacts-to-terraform.py
```

If you would like to back up the previous AMI variables in case something goes wrong with the new one, you can use this invocation instead

```sh
$ BACKUP=<File path to back up to>
$ python copy-packer-artifacts-to-terraform.py --tfvars-backup-file $BACKUP
```

## Launch Network with Terraform

Copy the example.tfvars file

```sh
$ cd terraform
$ cp example.tfvars terraform.tfvars
```

Fill in your username as the `cert_owner`:

```sh
$ sed -i '' "s/FIXME_USER/$USER/" terraform.tfvars
```

Check terraform.tfvars and change any values you would like to change. Note that the values given in examples.tfvars is NOT completely AWS free tier eligible, as they include t2.small and t2.medium instances. We do not recommend using t2.micro instances, as they were unable to compile solidity during testing.

If it is your first time using this package, you will need to run `terraform init` before applying the configuration.

Apply the terraform configuration

```sh
$ terraform apply
# Enter "yes" and wait for infrastructure creation
```

Note the IPs in the output or retain the terminal output. You will need them to finish setting up the cluster.

## Launch and configure vault

Pick a vault server IP to ssh into:

```sh
$ IP=<vault server IP>
$ ssh ubuntu@$IP
```

Initialize the vault. Choose the number of key shards and the unseal threshold based on your use case. For a simple test cluster, choose 1 for both. If you are using enterprise vault, you may configure the vault with another unseal mechanism as well.

```sh
$ KEY_SHARES=<Number of key shards>
$ KEY_THRESHOLD=<Number of keys needed to unseal the vault>
$ vault init -key-shares=$KEY_SHARES -key-threshold=$KEY_THRESHOLD
```

Unseal the vault and initialize it with permissions for the quorum nodes. Once setup-vault.sh is complete, the quorum nodes will be able to finish their boot-up procedure. Note that this example is for a single key initialization, and if the key is sharded with a threshold greater than one, multiple users will need to run the unseal command with their shards.

```sh
$ UNSEAL_KEY=<Unseal key output by vault init command>
$ vault unseal $UNSEAL_KEY
$ ROOT_TOKEN=<Root token output by vault init command>
$ /opt/vault/bin/setup-vault.sh $ROOT_TOKEN
```

If any of these commands fail, wait a short time and try again. If waiting doesn't fix the issue, you may need to destroy and recreate the infrastructure.

### Unseal additional vault servers

You can proceed with initial setup with only one unsealed server, but if all unsealed servers crash, the vault will become inaccessable even though the severs will be replaced. If you have multiple vault servers, you may unseal all of them now and if the server serving requests crashes, the other servers will be on standby to take over.

SSH each vault server and for enough unseal keys to reach the threshold run:
```sh
$ UNSEAL_KEY=<Unseal key output by vault init command>
$ vault unseal $UNSEAL_KEY
```

## Access Other Components

TODO

## Destroy the Network

If this is a test and you are finished with your infrastructure, you will likely want to destroy your network to avoid incurring extra AWS costs:

```sh
# From the terraform directory
$ terraform destroy
# Enter "yes" and wait for the network to be destroyed
```

If it finishes with a single error that looks like as follows, ignore it.  Rerunning `terraform destroy` will show that there are no changes to make.

```
Error: Error applying plan:

1 error(s) occurred:

* aws_s3_bucket.quorum_vault (destroy): 1 error(s) occurred:

* aws_s3_bucket.quorum_vault: Error deleting S3 Bucket: NoSuchBucket: The specified bucket does not exist
	status code: 404, request id: 8641A613A9B146ED, host id: TjS8J2QzS7xFgXdgtjzf6FR1Z2x9uqA5UZLHaMEWKg7I9JDRVtilo6u/XSN9+Qnkx+u5M83p4/w= "quorum-vault"

Terraform does not automatically rollback in the face of errors.
Instead, your Terraform state file has been partially updated with
any resources that successfully completed. Please address the error
above and apply again to incrementally change your infrastructure.
```
