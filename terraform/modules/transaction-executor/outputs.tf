output "transaction_executor_dns" {
  value = "${aws_instance.tx_executor.public_dns}"
}

output "transaction_executor_security_group" {
  value = "${aws_security_group.tx_executor.id}"
}

output "transaction_executor_iam_role" {
  value = "${aws_iam_role.tx_executor.name}"
}
