# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  version = "~> 1.5"

  region  = "${var.aws_region}"
}

provider "null" {
  version = "~> 1.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# KEY PAIR FOR ALL INSTANCES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_key_pair" "auth" {
  key_name   = "transaction-executor-key"
  public_key = "${file(var.public_key_path)}"
}

# ---------------------------------------------------------------------------------------------------------------------
# VAULT CLUSTER NETWORKING
# ---------------------------------------------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "vault" {
  vpc_id                  = "${var.aws_vpc}"
  count                   = "${length(data.aws_availability_zones.available.names)}"
  availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"
  cidr_block              = "10.0.${count.index + 8}.0/24"
  map_public_ip_on_launch = true
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 BUCKET FOR VAULT BACKEND
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "tx_executor_vault" {
  bucket_prefix = "transaction-executor-"
}

# ---------------------------------------------------------------------------------------------------------------------
# LOAD BALANCER FOR VAULT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lb" "tx_executor_vault" {
  internal = true

  subnets         = ["${aws_subnet.vault.*.id}"]
  security_groups = ["${module.vault_cluster.security_group_id}"]
}

resource "aws_lb_target_group" "tx_executor_vault" {
  name = "vault-lb-target"
  port = "${var.vault_port}"
  protocol = "HTTPS"
  vpc_id = "${var.aws_vpc}"
}

resource "aws_lb_listener" "tx_executor_vault" {
  load_balancer_arn = "${aws_lb.tx_executor_vault.arn}"
  port              = "${var.vault_port}"
  protocol          = "HTTPS"
  ssl_policy        = "${var.lb_ssl_policy}"
  certificate_arn   = "${aws_iam_server_certificate.vault_certs.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.tx_executor_vault.arn}"
    type             = "forward"
  }
}

data "aws_ami" "vault_consul" {
  most_recent = true
  owners      = ["037794263736"]

  filter {
    name   = "name"
    values = ["eximchain-vault-tx-executor-*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE VAULT SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
module "vault_cluster" {
  source = "github.com/hashicorp/terraform-aws-vault.git//modules/vault-cluster?ref=v0.0.8"

  cluster_name  = "transaction-executor-vault"
  cluster_size  = "${var.vault_cluster_size}"
  instance_type = "${var.vault_instance_type}"

  ami_id    = "${var.vault_consul_ami == "" ? data.aws_ami.vault_consul.id : var.vault_consul_ami}"
  user_data = "${data.template_file.user_data_vault_cluster.rendered}"

  s3_bucket_name          = "${aws_s3_bucket.tx_executor_vault.id}"
  force_destroy_s3_bucket = "${var.force_destroy_s3_bucket}"

  vpc_id     = "${var.aws_vpc}"
  subnet_ids = "${aws_subnet.vault.*.id}"

  target_group_arns = ["${aws_lb_target_group.tx_executor_vault.arn}"]

  allowed_ssh_cidr_blocks            = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks        = ["0.0.0.0/0"]
  allowed_inbound_security_group_ids = []
  ssh_key_name                       = "${aws_key_pair.auth.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# ALLOW VAULT CLUSTER TO USE AWS AUTH
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_aws_auth" {
  name        = "allow_aws_auth"
  description = "Allow authentication to vault by AWS mechanisms"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:DescribeInstances",
      "iam:GetInstanceProfile",
      "iam:GetUser",
      "iam:GetRole"
    ],
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "allow_aws_auth" {
  role       = "${module.vault_cluster.iam_role_id}"
  policy_arn = "${aws_iam_policy.allow_aws_auth.arn}"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH IAM POLICIES FOR CONSUL
# To allow our Vault servers to automatically discover the Consul servers, we need to give them the IAM permissions from
# the Consul AWS Module's consul-iam-policies module.
# ---------------------------------------------------------------------------------------------------------------------
module "consul_iam_policies_servers" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-iam-policies?ref=v0.1.0"

  iam_role_id = "${module.vault_cluster.iam_role_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
# This script will configure and start Vault
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_vault_cluster" {
  template = "${file("${path.module}/user-data/user-data-vault.sh")}"

  vars {
    aws_region                = "${var.aws_region}"
    s3_bucket_name            = "${aws_s3_bucket.tx_executor_vault.id}"
    consul_cluster_tag_key    = "${module.consul_cluster.cluster_tag_key}"
    consul_cluster_tag_value  = "${module.consul_cluster.cluster_tag_value}"
    vault_cert_bucket         = "${aws_s3_bucket.vault_certs.bucket}"
    tx_executor_role          = "${var.transaction_executor_iam_role}"
    eximchain_node_role       = "${var.eximchain_node_iam_role}"
  }

  # user-data needs to download these objects
  depends_on = ["aws_s3_bucket_object.vault_ca_public_key", "aws_s3_bucket_object.vault_public_key", "aws_s3_bucket_object.vault_private_key"]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
module "consul_cluster" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.1.0"

  cluster_name  = "quorum-consul"
  cluster_size  = "${var.consul_cluster_size}"
  instance_type = "${var.consul_instance_type}"

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = "consul-cluster"
  cluster_tag_value = "transaction-executor-consul"

  ami_id    = "${var.vault_consul_ami == "" ? data.aws_ami.vault_consul.id : var.vault_consul_ami}"
  user_data = "${data.template_file.user_data_consul.rendered}"

  vpc_id     = "${var.aws_vpc}"
  subnet_ids = "${aws_subnet.vault.*.id}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.

  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = "${aws_key_pair.auth.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL SERVER WHEN IT'S BOOTING
# This script will configure and start Consul
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_consul" {
  template = "${file("${path.module}/user-data/user-data-consul.sh")}"

  vars {
    consul_cluster_tag_key   = "${module.consul_cluster.cluster_tag_key}"
    consul_cluster_tag_value = "${module.consul_cluster.cluster_tag_value}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EXPORT CURRENT VAULT SERVER IPS
# These servers may change over time but you can use an arbitrary server for initial setup
# ---------------------------------------------------------------------------------------------------------------------
data "aws_instances" "vault_servers" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = ["${module.vault_cluster.asg_name}"]
  }
}
