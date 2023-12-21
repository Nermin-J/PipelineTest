#!/bin/bash

STORAGE_ACCOUNT_NAME=$1
STORAGE_ACCOUNT_SUBSCRIPTION_ID=$2

az account set --name $STORAGE_ACCOUNT_SUBSCRIPTION_ID --output none
az storage account update --name $STORAGE_ACCOUNT_NAME --public-network-access Disabled --default-action Deny --set networkRuleSet.ipRules=[] --output none
echo Access to storage account \"$STORAGE_ACCOUNT_NAME\" for host IP revoked