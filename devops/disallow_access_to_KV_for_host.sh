#!/bin/bash

KEY_VAULT_NAME=$1
KEY_VAULT_SUBSCRIPTION_ID=$2

az account set --name $KEY_VAULT_SUBSCRIPTION_ID
az keyvault update --name $KEY_VAULT_NAME --public-network-access Disabled --default-action Deny
az keyvault update --name $KEY_VAULT_NAME --set properties.networkAcls.ipRules=[]
echo Access to key vault \"$KEY_VAULT_NAME\" for host IP revoked