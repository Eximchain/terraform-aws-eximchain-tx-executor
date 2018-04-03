#!/bin/bash
set -u -o pipefail

function wait_for_successful_command {
    local COMMAND=$1

    $COMMAND
    until [ $? -eq 0 ]
    do
        sleep 5
        $COMMAND
    done
}

function generate_tx_executor_supervisor_config {
  VAULT_URL=$(cat /opt/transaction-executor/vault-url.txt)
  QUORUM_URL=$(cat /opt/transaction-executor/quorum-url.txt)
  echo "[program:tx-executor]
command=sh -c '/opt/transaction-executor/go/bin/eximchain-transaction-executor -vault-address=$VAULT_URL -quorum-address=$QUORUM_URL'
stdout_logfile=/opt/transaction-executor/log/tx-executor-stdout.log
stderr_logfile=/opt/transaction-executor/log/tx-executor-error.log
numprocs=1
autostart=true
autorestart=unexpected
stopsignal=INT
user=ubuntu
environment=GOPATH=/opt/transaction-executor/go" | sudo tee /etc/supervisor/conf.d/tx-executor-supervisor.conf
}

# Generate singleton geth keypair for testing
GETH_PW=$(uuidgen -r)
ADDRESS=0x$(echo -ne "$GETH_PW\n$GETH_PW\n" | geth account new | grep Address | awk '{ gsub("{|}", "") ; print $2 }')
PRIV_KEY=$(cat /home/ubuntu/.ethereum/keystore/*$(echo $ADDRESS | cut -d 'x' -f2))

# Wait for operator to initialize and unseal vault
wait_for_successful_command 'vault init -check'
wait_for_successful_command 'vault status'

# Wait for vault to be fully configured by the root user
wait_for_successful_command 'vault auth -method=aws'

wait_for_successful_command "vault write keys/singleton password=$GETH_PW address=$ADDRESS key=$PRIV_KEY"

# Replace the config that runs this with one that runs the tx-executor itself
generate_tx_executor_supervisor_config
sudo rm /etc/supervisor/conf.d/init-tx-executor-supervisor.conf
sudo supervisorctl reread
sudo supervisorctl update
