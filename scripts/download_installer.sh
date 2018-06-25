#!/bin/bash -e

REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//'`
SEED_IP_NAME=$2
SEED_IP=`aws ssm get-parameter --region $REGION --name "$SEED_IP_NAME" | grep -Po 'Value": "\K[^"]*'`
API_TOKEN_NAME=$3
API_TOKEN=`aws ssm get-parameter --region $REGION --name "$API_TOKEN_NAME" | grep -Po 'Value": "\K[^"]*'`

function downloadFromMcsvc() {
    local DOWNLOAD_URL=$1
    local DOWNLOAD_DOMAIN=`echo "$DOWNLOAD_URL" | cut -d'/' -f3`

    cd /tmp
    echo "download the installer"
    wget -O dynatrace-managed.sh "$DOWNLOAD_URL"

    echo "download the CA cert used for signing"
    wget -O dt-root.cert.pem https://ca.dynatrace.com/dt-root.cert.pem

    echo "download installer signature"
    wget -O dynatrace-managed.sh.sig https://$DOWNLOAD_DOMAIN/downloads/signature?filename=$(grep -am 1 'ARCH_FILE_NAME=' dynatrace-managed.sh | cut -d= -f2 |sed -r 's/\.tar(\.gz)?//')

    echo "verify the signature"
    openssl cms -inform PEM -binary -verify -CAfile dt-root.cert.pem -in dynatrace-managed.sh.sig -content dynatrace-managed.sh > /dev/null
}

function downloadFromSeed() {
    local SEED_IP=$1

    echo "Download from seed"
    cd /tmp
    wget --no-check-certificate -O dynatrace-managed.sh "https://$SEED_IP:8021/nodeinstaller"
}

if [[ "$API_TOKEN" == "null" ]]
then
    downloadFromMcsvc $1
else
    downloadFromSeed $SEED_IP
fi

