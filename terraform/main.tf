provider "aws" {
  version = "~> 1.5"

  region  = "${var.aws_region}"
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "tx_executor" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "tx_executor" {
  vpc_id = "${aws_vpc.tx_executor.id}"
}

resource "aws_route" "tx_executor" {
  route_table_id         = "${aws_vpc.tx_executor.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.tx_executor.id}"
}

module "transaction_executor" {
  # Source from github if using in another project
  source = "modules/transaction-executor"

  # Variables sourced from terraform.tfvars
  public_key_path                    = "${var.public_key_path}"
  aws_region                         = "${var.aws_region}"
  availability_zone                  = "${var.availability_zone}"
  cert_owner                         = "${var.cert_owner}"
  force_destroy_s3_buckets           = "${var.force_destroy_s3_buckets}"
  tx_executor_instance_type          = "${var.tx_executor_instance_type}"

  # Variables sourced from the vault module
  vault_dns                = "${module.tx_executor_vault.vault_dns}"
  vault_cert_s3_upload_id  = "${module.tx_executor_vault.vault_cert_s3_upload_id}"
  vault_cert_bucket_name   = "${module.tx_executor_vault.vault_cert_bucket_name}"
  vault_cert_bucket_arn    = "${module.tx_executor_vault.vault_cert_bucket_arn}"
  consul_cluster_tag_key   = "${module.tx_executor_vault.consul_cluster_tag_key}"
  consul_cluster_tag_value = "${module.tx_executor_vault.consul_cluster_tag_value}"

  # Variables sourced from the eximchain node module
  quorum_dns                         = "${module.eximchain_node.eximchain_node_dns}"
  quorum_port                        = "${module.eximchain_node.eximchain_node_rpc_port}"

  aws_vpc = "${aws_vpc.tx_executor.id}"

  tx_executor_ami = "${var.tx_executor_ami}"
}

module "tx_executor_vault" {
  source = "modules/tx-executor-vault"

  vault_consul_ami = "${var.vault_consul_ami}"
  cert_owner       = "${var.cert_owner}"
  public_key_path  = "${var.public_key_path}"

  aws_region    = "${var.aws_region}"
  vault_port    = "${var.vault_port}"
  cert_org_name = "${var.cert_org_name}"

  transaction_executor_iam_role = "${module.transaction_executor.transaction_executor_iam_role}"
  eximchain_node_iam_role       = "${module.eximchain_node.eximchain_node_iam_role}"

  force_destroy_s3_bucket = "${var.force_destroy_s3_buckets}"

  aws_vpc = "${aws_vpc.tx_executor.id}"

  vault_cluster_size   = "${var.vault_cluster_size}"
  vault_instance_type  = "${var.vault_instance_type}"
  consul_cluster_size  = "${var.consul_cluster_size}"
  consul_instance_type = "${var.consul_instance_type}"
}

module "eximchain_node" {
  source = "github.com/eximchain/terraform-aws-eximchain-node.git//terraform/modules/eximchain-node"

  aws_region        = "${var.aws_region}"
  availability_zone = "${var.availability_zone}"

  public_key_path = "${var.public_key_path}"
  # TODO: Don't make certs if we're using an external vault
  cert_owner    = "${var.cert_owner}"
  cert_org_name = "${var.cert_org_name}"

  eximchain_node_ami           = "${var.eximchain_node_ami}"
  eximchain_node_instance_type = "${var.eximchain_node_instance_type}"

  aws_vpc = "${aws_vpc.tx_executor.id}"

  # External Vault Parameters
  vault_dns  = "${module.tx_executor_vault.vault_dns}"
  vault_port = "${var.vault_port}"

  vault_cert_bucket = "${module.tx_executor_vault.vault_cert_bucket_name}"

  network_id = "${var.network_id}"

  node_volume_size = "${var.node_volume_size}"

  force_destroy_s3_bucket = "${var.force_destroy_s3_buckets}"

  consul_cluster_tag_key   = "${module.tx_executor_vault.consul_cluster_tag_key}"
  consul_cluster_tag_value = "${module.tx_executor_vault.consul_cluster_tag_value}"
}

# Allow Eximchain node to download vault certificates
resource "aws_iam_role_policy_attachment" "vault_cert_access" {
  role       = "${module.eximchain_node.eximchain_node_iam_role}"
  policy_arn = "${module.tx_executor_vault.vault_cert_access_policy_arn}"
}

# Allow the transaction executor to make RPC calls to the eximchain node
module "allow_rpc" {
  source = "github.com/eximchain/terraform-aws-eximchain-node.git//terraform/modules/allow-rpc-rule"

  node_security_group = "${module.eximchain_node.eximchain_node_security_group_id}"
  rpc_security_group  = "${module.transaction_executor.transaction_executor_security_group}"
}
