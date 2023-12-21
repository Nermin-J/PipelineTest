#!/bin/bash

KEY_VAULT_NAME=$1
KEY_VAULT_SUBSCRIPTION_ID=$2

host_ip=$(curl https://api.ipify.org)
echo Host IP is: $host_ip

az account set --name $KEY_VAULT_SUBSCRIPTION_ID --output none
az keyvault update --name $KEY_VAULT_NAME --public-network-access Enabled --default-action Deny --output none
az keyvault network-rule add --name $KEY_VAULT_NAME --ip-address $host_ip --output none
echo Access to Key vault \"$KEY_VAULT_NAME\" for host IP $host_ip granted