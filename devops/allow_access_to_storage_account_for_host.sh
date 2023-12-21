#!/bin/bash

STORAGE_ACCOUNT_NAME=$1
STORAGE_ACCOUNT_SUBSCRIPTION_ID=$2

host_ip=$(curl https://api.ipify.org)
echo Host IP is: $host_ip

az account set --name $STORAGE_ACCOUNT_SUBSCRIPTION_ID
az storage account update --name $STORAGE_ACCOUNT_NAME --public-network-access Enabled --default-action Deny
az storage account network-rule add --account-name $STORAGE_ACCOUNT_NAME --ip-address $host_ip
echo Access to storage account \"$STORAGE_ACCOUNT_NAME\" for host IP $host_ip granted