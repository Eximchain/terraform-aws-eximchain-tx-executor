public_key_path                    = "~/.ssh/quorum.pub"
aws_region                         = "us-east-1"
availability_zone                  = "us-east-1a"
cert_owner                         = "FIXME_USER"
force_destroy_s3_buckets           = true
vault_cluster_size                 = 1
vault_instance_type                = "t2.small"
consul_cluster_size                = 1
consul_instance_type               = "t2.small"
tx_executor_instance_type          = "t2.medium"

eximchain_node_ami = "ami-0c7e2e40637adb0a5"
tx_executor_ami    = "ami-0fa5a086a0804e22a"
vault_consul_ami   = "ami-05fbd69b3950d9b73"
