#!/bin/bash

KEY_VAULT_NAME=$1
KEY_VAULT_SUBSCRIPTION_ID=$2

host_ip=$(curl https://api.ipify.org)
echo Host IP is: $host_ip

# az account set --name $KEY_VAULT_SUBSCRIPTION_ID
# az keyvault update --name $KEY_VAULT_NAME --public-network-access Enabled --default-action Deny
# az keyvault network-rule add --name $KEY_VAULT_NAME --ip-address $host_ip
# echo Access for host IP $host_ip granted