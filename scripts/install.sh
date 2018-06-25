#!/bin/bash -e

REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//'`
SEED_IP_NAME=$4
SEED_IP=`aws ssm get-parameter --region $REGION --name "$SEED_IP_NAME" | grep -Po 'Value": "\K[^"]*'`
API_TOKEN_NAME=$5
API_TOKEN=`aws ssm get-parameter --region $REGION --name "$API_TOKEN_NAME" | grep -Po 'Value": "\K[^"]*'`

function installSeed() {
    local LICENSE_KEY=$1
    local ADMIN_EMAIL=$2
    local ADMIN_PASS=$3
    local SEED_IP_NAME=$4
    local API_TOKEN_NAME=$5

    echo "Run the installer in silent mode, assuming the defaults. Note: license key must be valid and not used by any other cluster"
    cd /tmp
    /bin/sh dynatrace-managed.sh --install-silent --license "$LICENSE_KEY" \
     --initial-environment test \
     --initial-first-name Admin \
     --initial-last-name Admin \
     --initial-email "$ADMIN_EMAIL" \
     --initial-pass "$ADMIN_PASS" | tee /tmp/installer.out

    if [[ "$?" != 0 ]]
    then
        echo "Dynatrace Managed installation failed"
        return 1
    fi

    echo "Dynatrace Managed installation complete"

    local SEED_IP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`
    local API_TOKEN=`grep "Your API token for Server communication" /tmp/installer.out | cut -d":" -f 2 | xargs`

    rm /tmp/installer.out

    echo "Storing API token"
    aws ssm put-parameter --region $REGION --name "$API_TOKEN_NAME" --value "$API_TOKEN" --type String --overwrite
    echo "Storing seed IP address"
    aws ssm put-parameter --region $REGION --name "$SEED_IP_NAME" --value "$SEED_IP" --type String --overwrite

    echo "Done installing seed node"

    return 0
}

function addNode() {
    local SEED_IP=$1
    local API_TOKEN=$2

    echo "Add node"
    cd /tmp
    /bin/sh dynatrace-managed.sh --install-silent --seed-ip "$SEED_IP" --seed-auth "$API_TOKEN"
    return $?
}

function waitUntilFullyBootstrapped() {

    local ITER=60

    for (( i=1; $i <= $ITER; i++ )) ; do
       if grep -q "SSLConnector at port=8021 refreshed" /opt/dynatrace-managed/server/log/Server.0.0.log
       then
          echo "Bootstrapping complete"
          return 0
       else
          if [[ "$ITER" == "$i" ]]
          then
             echo "Timeout when bootstrapping"
             return 1
          else
             echo "Waiting to finish bootstrapping"
             sleep 10
          fi
       fi
    done
}

if [[ "$API_TOKEN" == "null" ]]
then
    installSeed "$@" && waitUntilFullyBootstrapped
else
    addNode "$SEED_IP" "$API_TOKEN" && waitUntilFullyBootstrapped
fi

exit $?

