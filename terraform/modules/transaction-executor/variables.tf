# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to launch servers."
}

variable "availability_zone" {
  description = "AWS availability zone to launch the transaction executor in"
}

variable "aws_vpc" {
  description = "The VPC to create the transaction executor in"
}

variable "public_key" {
  description = "The public key that will be used to SSH the instances in this region."
}

variable "cert_owner" {
  description = "The OS user to be made the owner of the local copy of the vault certificates. Should usually be set to the user operating the tool."
}

variable "vault_dns" {
  description = "The DNS name that vault will be accessible on."
}

variable "quorum_dns" {
  description = "The DNS name that a quorum node will be accessible on."
}

variable "vault_cert_bucket_name" {
  description = "The name of the S3 bucket holding the vault TLS certificates"
}

variable "vault_cert_bucket_arn" {
  description = "The ARN of the S3 bucket holding the vault TLS certificates"
}

variable "consul_cluster_tag_key" {
  description = "The tag key of the consul cluster to use for vault cluster locking."
}

variable "consul_cluster_tag_value" {
  description = "The tag value of the consul cluster to use for vault cluster locking."
}

variable "vault_cert_s3_upload_id" {
  description = "Generated by tx_executor_vault after uploading certificates to S3. Used to work around lack of depends_on for modules."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "vault_port" {
  description = "The port that vault will be accessible on."
  default     = 8200
}

variable "quorum_port" {
  description = "The port that vault will be accessible on."
  default     = 8545
}

variable "private_key" {
  description = "The private key that will be used to SSH the instances in this region. Will use the agent if empty"
  default     = ""
}

variable "force_destroy_s3_buckets" {
  description = "Whether or not to force destroy s3 buckets. Set to true for an easily destroyed test environment. DO NOT set to true for a production environment."
  default     = false
}

variable "ccloud_broker" {
  description = "The broker for the confluence cloud cluster to use for ethconnect."
  default     = ""
}

variable "ccloud_api_key" {
  description = "The API key for the confluence cloud cluster to use for ethconnect."
  default     = ""
}

variable "ccloud_api_secret" {
  description = "The API secret for the confluence cloud cluster to use for ethconnect."
  default     = ""
}

variable "mongo_connection_url" {
  description = "Connection string for use with the mgo driver to connect to the MongoDB store to use for receipts."
  default     = ""
}

variable "mongo_database_name" {
  description = "Name of the MongoDB database to use for receipts."
  default     = ""
}

variable "mongo_collection_name" {
  description = "Name of the MongoDB collection to use for receipts. Does not need to exist in the database already."
  default     = ""
}

variable "mongo_max_receipts" {
  description = "Number of receipts to retain in the MongoDB store."
  default     = ""
}

variable "mongo_query_limit" {
  description = "Max number of receipts to retrieve at once."
  default     = ""
}

variable "tx_executor_ami" {
  description = "AMI ID to use for transaction executor servers. Defaults to getting the most recently built version from Eximchain"
  default     = ""
}

variable "tx_executor_instance_type" {
  description = "The EC2 instance type to use for transaction executor nodes"
  default     = "t2.medium"
}
