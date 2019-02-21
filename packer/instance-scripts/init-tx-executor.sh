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
  local readonly VAULT_URL=$(cat /opt/transaction-executor/info/vault-url.txt)
  local readonly QUORUM_URL=$(cat /opt/transaction-executor/info/quorum-url.txt)
  local readonly DISABLE_AUTH=$(cat /opt/transaction-executor/info/disable-authentication.txt)
  echo "[program:tx-executor]
command=sh -c '/opt/transaction-executor/go/bin/eximchain-transaction-executor server -vault-address=$VAULT_URL -quorum-address=$QUORUM_URL -disable-auth=$DISABLE_AUTH'
stdout_logfile=/opt/transaction-executor/log/tx-executor-stdout.log
stderr_logfile=/opt/transaction-executor/log/tx-executor-error.log
numprocs=1
autostart=true
autorestart=unexpected
stopsignal=INT
user=ubuntu
environment=GOPATH=/opt/transaction-executor/go" | sudo tee /etc/supervisor/conf.d/tx-executor-supervisor.conf
}

function generate_ethconnect_supervisor_config {
  local readonly ETHCONNECT_SERVER_CONFIG="/opt/transaction-executor/ethconnect-config.yml"
  local readonly LOG_LEVEL="1"
  echo "[program:ethconnect]
command=/opt/transaction-executor/go/bin/ethconnect server -f $ETHCONNECT_SERVER_CONFIG -d $LOG_LEVEL
stdout_logfile=/opt/transaction-executor/log/ethconnect-stdout.log
stderr_logfile=/opt/transaction-executor/log/ethconnect-error.log
numprocs=1
autostart=true
autorestart=unexpected
stopsignal=INT
user=ubuntu
environment=GOPATH=/opt/transaction-executor/go" | sudo tee /etc/supervisor/conf.d/ethconnect-supervisor.conf
}

function ensure_ethconnect_topics_exist {
  local readonly TOPIC_IN=$(cat /opt/transaction-executor/info/ethconnect-topic-in.txt)
  local readonly TOPIC_OUT=$(cat /opt/transaction-executor/info/ethconnect-topic-out.txt)

  local readonly TOPIC_LIST=$(wait_for_successful_command 'ccloud topic list')
  local readonly TOPIC_IN_EXISTS=$(echo "$TOPIC_LIST" | grep $TOPIC_IN | wc -l)
  local readonly TOPIC_OUT_EXISTS=$(echo "$TOPIC_LIST" | grep $TOPIC_OUT | wc -l)

  if [ "$TOPIC_IN_EXISTS" == "0" ]
  then
    ccloud topic create $TOPIC_IN
  fi

  if [ "$TOPIC_OUT_EXISTS" == "0" ]
  then
    ccloud topic create $TOPIC_OUT
  fi
}

ensure_ethconnect_topics_exist

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

#generate_ethconnect_supervisor_config

# Replace the config that runs this with one that runs the tx-executor itself
generate_tx_executor_supervisor_config
sudo rm /etc/supervisor/conf.d/init-tx-executor-supervisor.conf
sudo supervisorctl reread
sudo supervisorctl update
