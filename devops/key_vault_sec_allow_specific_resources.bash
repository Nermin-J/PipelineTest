#!/usr/bin/env bash

set -eu

ENV=${1:-""}    # Get first argument if exists. If not, initilize it as empty string

# convert to lowecase
ENV="${ENV,,}"

if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" && "$ENV" != "korea-staging" && "$ENV" != "korea-prod" ]]; then
    echo "[ERROR] You must provide environment value as first argument (dev, staging, prod, korea-staging or korea-prod)!"
    exit 1
fi

# Load env variables
source ../.github/envs/$ENV.env

######## VARIABLES LOADED FROM ENVIRONMENT WILL BE USED TO INITIALIZE LOCAL VARIABLES ########

SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-""}      # Subscription id of the APIM, App gateway and Key vault
RESOURCE_GROUP=${RESOURCE_GROUP:-""}        # Resource group of the APIM, App gateway and Key vault

# App gateway props
APP_GATEWAY_NAME=${APP_GATEWAY_NAME:-""}    # Name of the APP gateway access to Key vault should be enabled for
APP_GATEWAY_FRONTEND_IP_CONFIG_NAME=${APP_GATEWAY_FRONTEND_IP_CONFIG_NAME:-""}  # Name of the APP gateway's public IP configuration (There might be multiple configs so we specify which one we want) 

# APIM props
APIM_NAME=${APIM_NAME:-""}                  # Name of the APIM access to Key vault should be enabled for

# Key vault props
KEY_VAULT_NAME=${KEYVAULT_NAME:-""}        # Name of the Key vault we want to allow access on

allowed_ips=""      # IPs (separated by space) we want to add as allowed IPs - initialize this variable with default values (if any) you want always to allow 
                    # access from

function print_requirements() {
    echo "[ERROR] You must provide additional parameters. Double check if all variables are defined correctly inside of env file:
            1. Subscription Id (SUBSCRIPTION_ID)
            2. Resource group name (RESOURCE_GROUP)
            3. Application gateway name (APP_GATEWAY_NAME)
            4. Application gateway frontend ip configuration name (APP_GATEWAY_FRONTEND_IP_CONFIG_NAME)
            5. APIM name (APIM_NAME)
            6. Key vault name (KEYVAULT_NAME)" 
}

if [ -z "$SUBSCRIPTION_ID" ] || [ -z $RESOURCE_GROUP ] || [ -z "$APP_GATEWAY_NAME" ] || [ -z $APP_GATEWAY_FRONTEND_IP_CONFIG_NAME ] || [ -z "$APIM_NAME" ] || [ -z "$KEY_VAULT_NAME" ]; then
    print_requirements
    exit 1
fi

echo "[INFO] Setting up subscription of the resources!"
az account set --name $SUBSCRIPTION_ID --output none

function include_app_gateway_ip() {
    set -eu

    echo "[INFO] Getting app gateway's IP!"
    # get id of the gateway's public IP
    app_gateway_ip_id=$(az network application-gateway frontend-ip show --gateway-name $APP_GATEWAY_NAME --name $APP_GATEWAY_FRONTEND_IP_CONFIG_NAME --resource-group $RESOURCE_GROUP --query "publicIPAddress.id" --output tsv)
    # Get gateway's IP by id
    app_gateway_ip="$(az resource show --ids $ip_id --query "properties.ipAddress" --output tsv)"

    echo "[INFO] Public IP of the App gateway is: $app_gateway_ip"
    allowed_ips="$allowed_ips $app_gateway_ip"
}

function include_apim_ip() {
    set -eu

    echo "[INFO] Getting APIM's IP!"
    apim_ip=$(az apim show --name $APIM_NAME --resource-group $RESOURCE_GROUP --query "publicIpAddresses" --output tsv)

    echo "[INFO] Public IP of the APIM is: $apim_ip"
    allowed_ips="$allowed_ips $apim_ip"
}

include_app_gateway_ip
include_apim_ip

echo "$allowed_ips"

exit 0

# To correctly enable access to Key vault for desired IPs and revoke it for all other IPs, we first add desired IPs to the list of allowed IPs (to make sure they are added)
/bin/bash modify_access_to_key_vault.sh $KEY_VAULT_NAME $SUBSCRIPTION_ID "allow ips" "$allowed_ips"
# and then we revoke access for all IPs other than desired once
/bin/bash modify_access_to_key_vault.sh $KEY_VAULT_NAME $SUBSCRIPTION_ID "revoke except" "$allowed_ips"

# With this approach, we make sure that allowed IPs won't be removed from the list even for a second (this scenario would happen if we remove all and then add desired IPs)