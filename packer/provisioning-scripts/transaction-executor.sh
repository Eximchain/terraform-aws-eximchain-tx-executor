#!/bin/bash
set -eu -o pipefail

BASH_PROFILE=/home/ubuntu/.bash_profile

source $BASH_PROFILE

go get github.com/eximchain/eximchain-transaction-executor
go build /opt/transaction-executor/go/src/github.com/eximchain/eximchain-transaction-executor/*.go
