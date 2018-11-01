# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  version = "~> 1.5"

  region  = "${var.aws_region}"
}

provider "tls" {
  version = "~> 1.0"
}

provider "template" {
  version = "~> 1.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# KEY PAIR FOR ALL INSTANCES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_key_pair" "auth" {
  key_name_prefix = "tx-executor-"
  public_key      = "${var.public_key}"
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR POLICY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "tx_executor" {
  name_prefix = "eximchain-tx-executor-"
  description = "A policy for a transaction executor"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeTags",
      "ec2:DescribeSnapshots"
    ],
    "Resource": "*"
  },{
    "Effect": "Allow",
    "Action": ["s3:ListBucket"],
    "Resource": ["${var.vault_cert_bucket_arn}"]
  },{
    "Effect": "Allow",
    "Action": ["s3:GetObject"],
    "Resource": [
      "${var.vault_cert_bucket_arn}/ca.crt.pem",
      "${var.vault_cert_bucket_arn}/vault.crt.pem"
    ]
  }]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR NETWORKING
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "tx_executor" {
  vpc_id                  = "${var.aws_vpc}"
  availability_zone       = "${var.availability_zone}"
  cidr_block              = "${cidrsubnet(var.base_subnet_cidr, 3, count.index)}"
  map_public_ip_on_launch = true
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR NODE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "tx_executor" {
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication if this is empty.
    private_key = "${var.private_key}"
  }

  instance_type = "${var.tx_executor_instance_type}"

  ami       = "${var.tx_executor_ami == "" ? data.aws_ami.transaction_executor.id : var.tx_executor_ami}"
  user_data = "${data.template_file.user_data_tx_executor.rendered}"

  key_name = "${aws_key_pair.auth.id}"

  iam_instance_profile = "${aws_iam_instance_profile.tx_executor.name}"

  vpc_security_group_ids = ["${aws_security_group.tx_executor.id}"]
  subnet_id              = "${element(aws_subnet.tx_executor.*.id, 0)}"

  tags {
    Name = "tx-executor"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "echo 'https://${var.vault_dns}:${var.vault_port}' > /opt/transaction-executor/info/vault-url.txt",
      "echo 'http://${var.quorum_dns}:${var.quorum_port}' > /opt/transaction-executor/info/quorum-url.txt"
    ]
  }
}

data "aws_ami" "transaction_executor" {
  most_recent = true
  owners      = ["037794263736"]

  filter {
    name   = "name"
    values = ["eximchain-tx-executor-*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH TRANSACTION EXECUTOR NODE WHEN IT'S BOOTING
# This script will configure and start the Consul Agent
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "user_data_tx_executor" {
  template = "${file("${path.module}/user-data/user-data-tx-executor.sh")}"

  vars {
    vault_dns  = "${var.vault_dns}"
    vault_port = "${var.vault_port}"

    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
    consul_cluster_tag_value = "${var.consul_cluster_tag_value}"

    vault_cert_bucket = "${var.vault_cert_bucket_name}"

    disable_authentication = "${var.disable_authentication}"

    ethconnect_webhook_port        = "${var.ethconnect_webhook_port}"
    ethconnect_always_manage_nonce = "${var.ethconnect_always_manage_nonce}"
    ethconnect_max_in_flight       = "${var.ethconnect_max_in_flight}"
    ethconnect_max_tx_wait_time    = "${var.ethconnect_max_tx_wait_time}"

    ccloud_broker     = "${var.ccloud_broker}"
    ccloud_api_key    = "${var.ccloud_api_key}"
    ccloud_api_secret = "${var.ccloud_api_secret}"

    mongo_connection_url      = "${var.mongo_connection_url}"
    mongo_database_name       = "${var.mongo_database_name}"
    mongo_collection_name     = "${var.mongo_collection_name}"
    mongo_max_receipts        = "${var.mongo_max_receipts}"
    mongo_query_limit         = "${var.mongo_query_limit}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR SECURITY GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "tx_executor" {
  name        = "tx_executor"
  description = "Used for transaction executor"
  vpc_id      = "${var.aws_vpc}"
}

resource "aws_security_group_rule" "tx_executor_ssh" {
  security_group_id = "${aws_security_group.tx_executor.id}"
  type              = "ingress"

  from_port = 22
  to_port   = 22
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "tx_executor_rpc_cidr_access" {
  count = "${length(var.rpc_api_cidrs) == 0 ? 0 : 1}"

  security_group_id = "${aws_security_group.tx_executor.id}"
  type              = "ingress"

  from_port = 8080
  to_port   = 8080
  protocol  = "tcp"

  cidr_blocks = "${var.rpc_api_cidrs}"
}

resource "aws_security_group_rule" "tx_executor_rpc_security_group_access" {
  count = "${length(var.rpc_api_security_groups)}"

  security_group_id = "${aws_security_group.tx_executor.id}"
  type              = "ingress"

  from_port = 8080
  to_port   = 8080
  protocol  = "tcp"

  source_security_group_id = "${element(var.rpc_api_security_groups, count.index)}"
}

resource "aws_security_group_rule" "tx_executor_ethconnect_cidr_access" {
  count = "${length(var.ethconnect_api_cidrs) == 0 ? 0 : 1}"

  security_group_id = "${aws_security_group.tx_executor.id}"
  type              = "ingress"

  from_port = "${var.ethconnect_webhook_port}"
  to_port   = "${var.ethconnect_webhook_port}"
  protocol  = "tcp"

  cidr_blocks = "${var.ethconnect_api_cidrs}"
}

resource "aws_security_group_rule" "tx_executor_ethconnect_security_group_access" {
  count = "${length(var.ethconnect_api_security_groups)}"

  security_group_id = "${aws_security_group.tx_executor.id}"
  type              = "ingress"

  from_port = "${var.ethconnect_webhook_port}"
  to_port   = "${var.ethconnect_webhook_port}"
  protocol  = "tcp"

  source_security_group_id = "${element(var.ethconnect_api_security_groups, count.index)}"
}

resource "aws_security_group_rule" "tx_executor_egress" {
  security_group_id = "${aws_security_group.tx_executor.id}"
  type              = "egress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "tx_executor" {
  name_prefix = "eximchain-tx-executor-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
  }]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR IAM POLICY ATTACHMENT AND INSTANCE PROFILE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "tx_executor" {
  role       = "${aws_iam_role.tx_executor.name}"
  policy_arn = "${aws_iam_policy.tx_executor.arn}"
}

resource "aws_iam_instance_profile" "tx_executor" {
  name = "${aws_iam_role.tx_executor.name}"
  role = "${aws_iam_role.tx_executor.name}"
}
