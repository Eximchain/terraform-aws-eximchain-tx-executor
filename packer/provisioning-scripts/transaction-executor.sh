#!/bin/bash
set -eu -o pipefail

BASH_PROFILE=/home/ubuntu/.bash_profile

source $BASH_PROFILE


GO_SRC="$GOPATH/src"
GO_BIN="$GOPATH/bin"

mkdir -p $GOPATH
mkdir $GO_SRC
mkdir $GO_BIN

# Install dep
curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

cd $GO_SRC
git clone https://github.com/Eximchain/eximchain-transaction-executor.git
cd eximchain-transaction-executor

# Install Dependencies
$GO_BIN/dep ensure

# Build Go Project
go install
