#!/bin/bash

KEY_VAULT_NAME=$1
KEY_VAULT_SUBSCRIPTION_ID=$2

az account set --name $KEY_VAULT_SUBSCRIPTION_ID --output none
az keyvault update --name $KEY_VAULT_NAME --public-network-access Disabled --default-action Deny --set properties.networkAcls.ipRules=[] --output none
echo Access to key vault \"$KEY_VAULT_NAME\" for host IP revoked