# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to launch servers."
}

variable "availability_zone" {
  description = "AWS availability zone to launch the transaction executor and eximchain node in"
}

variable "cert_owner" {
  description = "The OS user to be made the owner of the local copy of the vault certificates. Should usually be set to the user operating the tool."
}

variable "network_id" {
  description = "The network ID of the eximchain network to join"
  default     = 513
}

variable "node_volume_size" {
  description = "The size of the storage drive on the eximchain node"
  default     = 50
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "public_key_path" {
  description = "The path to the public key that will be used to SSH the instances in this region."
  default     = ""
}

variable "public_key" {
  description = "The path to the public key that will be used to SSH the instances in this region. Will override public_key_path if set."
  default     = ""
}

variable "vault_port" {
  description = "The port that vault will be accessible on."
  default     = 8200
}

variable "force_destroy_s3_buckets" {
  description = "Whether or not to force destroy s3 buckets. Set to true for an easily destroyed test environment. DO NOT set to true for a production environment."
  default     = false
}

variable "tx_executor_ami" {
  description = "AMI ID to use for transaction executor servers. Defaults to getting the most recently built version from Eximchain"
  default     = ""
}

variable "tx_executor_instance_type" {
  description = "The EC2 instance type to use for eximchain nodes"
  default     = "t2.medium"
}

variable "eximchain_node_ami" {
  description = "AMI ID to use for eximchain node. If not set, will retrieve the latest version from Eximchain."
  default     = ""
}

variable "eximchain_node_instance_type" {
  description = "The EC2 instance type to use for transaction executor nodes"
  default     = "t2.medium"
}

variable "vault_consul_ami" {
  description = "AMI ID to use for vault and consul servers. Defaults to getting the most recently built version from Eximchain"
  default     = ""
}

variable "vault_cluster_size" {
  description = "The number of instances to use in the vault cluster"
  default     = 3
}

variable "vault_instance_type" {
  description = "The EC2 instance type to use for vault nodes"
  default     = "t2.micro"
}

variable "consul_cluster_size" {
  description = "The number of instances to use in the consul cluster"
  default     = 3
}

variable "consul_instance_type" {
  description = "The EC2 instance type to use for consul nodes"
  default     = "t2.micro"
}

variable "cert_org_name" {
  description = "The organization to associate with the vault certificates."
  default     = "Example Co."
}
