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
  cidr_block              = "10.0.${count.index + 4}.0/24"
  map_public_ip_on_launch = true
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSACTION EXECUTOR NODE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "tx_executor" {
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication.
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
      "echo 'https://${var.vault_dns}:${var.vault_port}' > /opt/transaction-executor/vault-url.txt",
      "echo 'http://${var.quorum_dns}:${var.quorum_port}' > /opt/transaction-executor/quorum-url.txt"
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
