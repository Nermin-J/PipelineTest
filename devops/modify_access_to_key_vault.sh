#!/bin/bash

####################################################################################################
# This script allows/revokes access to key vault based on the input parameter (allow/revoke)
# Logic in the script assumes that the Azure login was already done

# input arguments -> see print_requirements function
####################################################################################################

set -eu

host_ip=""

# function print_requirements() {
#     echo "[ERROR] You must provide parameters:
#             1. Key vault name 
#             2. Subscription Id of the key vault
#             3. Access action
#             $(access_action_values_print)
#             4. List of IPs (separated with space) access should be enabled for (required in case of Access action == allow ips || revoke except)"
# }

# function access_action_values_print {
#     echo "possible values:      
#                 - allow ips             -> enables access only for passed IPs
#                 - allow host [and ips]  -> enables access for host and IPs if IPs are specified as 4th parameter
#                 - allow all             -> enables completely public access
#                 - revoke ips            -> revokes access to key vault only for specific IPs
#                 - revoke except         -> revokes access to key vault but keeps it for specific IPs specified as 4th parameter
#                 - revoke all            -> revokes access for all IPs and disables it completely"
# }

KEY_VAULT_NAME=${1:-""}
KEY_VAULT_SUBSCRIPTION_ID=${2:-""}
ACCESS_ACTION=${3:-""}
LIST_OF_IPS=${4:-""} # list of IPs could hold list of allowed IPs or list of IPs access should be revoked for - the meaning of the list depends on 3rd parameter

# convert to lowecase
ACCESS_ACTION=${ACCESS_ACTION,,} 

if [ -z "$KEY_VAULT_NAME" ] || [ -z $KEY_VAULT_SUBSCRIPTION_ID ] || [ -z "$ACCESS_ACTION" ]; then
    print_requirements
    exit 1
fi

if [[ "$ACCESS_ACTION" != "allow ips" && "$ACCESS_ACTION" != "allow host [and ips]" && "$ACCESS_ACTION" != "allow all" && "$ACCESS_ACTION" != "revoke ips" && "$ACCESS_ACTION" != "revoke except" && "$ACCESS_ACTION" != "revoke all" ]]; then
    echo "[ERROR] Access action can have values 'allow ips', 'allow host [and ips]', 'allow all', 'revoke ips', 'revoke except' or 'revoke all'!"
    access_action_values_print
    exit 1 
fi

if ([[ $ACCESS_ACTION == "allow ips" ]] || [[ $ACCESS_ACTION == "revoke ips" ]] || [[ $ACCESS_ACTION == "revoke except" ]]) && [ -z "$LIST_OF_IPS" ]; then    
    echo "[ERROR] You must provide list of IPs (separated with space) as 4th parameter!"
    exit 1
fi

if [[ $ACCESS_ACTION == "allow host [and ips]" ]] && [ -z "$LIST_OF_IPS" ]; then    
    echo -e "[WARNING] List of IPs (separated with space) is not specified as 4th parameter! Only host IP will be allowed to access resource!\n"
fi

echo "[INFO] Setting up subscription of the Key vault."
az account set --name $KEY_VAULT_SUBSCRIPTION_ID --output none

# checks if any IP was left in the list of allowed IPs after revoking access. If not, access will be completely disabled
function revoke_access_to_key_vault_if_no_IPs_addedd() {
    echo "[INFO] Checking if there are any IPs left as allowed IPs!"
    network_rules="$(az keyvault network-rule list --name $KEY_VAULT_NAME --query "ipRules[*]" --output tsv)"

    if [[ -z "$network_rules" ]]; then
        echo "[WARNING] There are no IPs addedd to the list of allowed IPs on this resource! Access to the resource will be completely disabled!"
    fi

    revoke_access_to_key_vault
}

# enables access to Key vault only for specific (passed) IPs
function allow_access_to_key_vault_for_ips(){
    set -eu

    list_of_allowed_ips="$1"

    echo "[INFO] Allowing access to key vault '${KEY_VAULT_NAME}' only for specific IP addresses!"
    az keyvault update --name $KEY_VAULT_NAME --public-network-access Enabled --default-action Deny --output none

    echo "[INFO] Adding IPs '${list_of_allowed_ips}' to the list of allowed IPs!"
    az keyvault network-rule add --name $KEY_VAULT_NAME --ip-address $list_of_allowed_ips --output none

    echo "[INFO] Getting info about public network access and list of allowed IPs!"
	publicNetworkAccess="$(az keyvault show --name $KEY_VAULT_NAME --query properties.publicNetworkAccess)"
    network_rules="$(az keyvault network-rule list --name $KEY_VAULT_NAME --query "ipRules[*]" --output tsv)"
	
    echo "[INFO] Public network access to key vault '$KEY_VAULT_NAME' is '$publicNetworkAccess'" 
    echo "[INFO] Currently allowed IPs are '$network_rules'"

    error="[ERROR] There was an issue while allowing access to key vault '$KEY_VAULT_NAME'! One (or all) of the IPs are not addedd or Public network access is not enabled!"

    # check if all IPs are addedd to the list of allowed IPs
    for check_IP in ${list_of_allowed_ips}; do
        if [[ "$network_rules" != *"$check_IP"* ]]; then
            echo $error # throw an error if desired IP is not inside the list of allowed IPs
            exit 1
        fi 
    done
    
    # If all desired IPs are addedd to the list of allowed IPs, continue and check if network access is enabled 
    if [[ "$publicNetworkAccess"=="Enabled" ]]; then
        echo "[INFO] Access to Key vault '$KEY_VAULT_NAME' for host IPs '$list_of_allowed_ips' has been granted successfully!"
        echo "$host_ip"
        exit 0
    else
        echo $error
        exit 1
    fi
}

# enables complete public access to Key vault
function allow_public_access_to_key_vault {
    set -eu

    echo "[WARNING] Allowing complete public access to key vault '${KEY_VAULT_NAME}'!"
    az keyvault update --name $KEY_VAULT_NAME --public-network-access Enabled --default-action Allow --output none

    publicNetworkAccess="$(az keyvault show --name $KEY_VAULT_NAME --query properties.publicNetworkAccess)"
    defaultAction="$(az keyvault show --name $KEY_VAULT_NAME --query properties.networkAcls.defaultAction)"

    if [[ "$publicNetworkAccess"=="Enabled" && "$defaultAction"=="Allow" ]]; then
        echo "[WARNING] Complete public access to Key vault '$KEY_VAULT_NAME' has been granted successfully!"
        exit 0
    else
        echo "[ERROR] There was an issue while allowing public access to key vault '$KEY_VAULT_NAME'!"
        exit 1
    fi
}

# revokes access to Key vault for IPs specified in 'LIST_OF_IPS'
function revoke_access_to_key_vault_for_ips(){
    set -eu

    list_of_disallowed_ips="$1"

    echo "[INFO] Revoking access to Key vault '${KEY_VAULT_NAME}' for IPs '$list_of_disallowed_ips'!"

    for disallowed_ip in ${list_of_disallowed_ips}; do
        echo "[INFO] Removing IP '$disallowed_ip'"
        az keyvault network-rule remove --name $KEY_VAULT_NAME --ip-address $disallowed_ip --output none
    done

    revoke_access_to_key_vault_if_no_IPs_addedd
}

# revokes access to Key vault for all IPs except 'LIST_OF_IPS'
function revoke_and_keep_access_to_key_vault(){
    set -eu

    list_of_allowed_ips="$1"

    echo "[INFO] Revoking access to Key vault '${KEY_VAULT_NAME}' while keeping IPs '$list_of_allowed_ips' as allowed IPs!"

    network_rules="$(az keyvault network-rule list --name $KEY_VAULT_NAME --query "ipRules[*]" --output tsv)"
    network_rules=$(echo -n "$network_rules" | tr -d '\r')

    if [[ -z "$network_rules" ]]; then
        echo "[WARNING] There are no IPs addedd to the list of allowed IPs on this resource! No changes will be performed!"
        exit 0
    fi

    # if there are IPs already addedd, continue
    az keyvault update --name $KEY_VAULT_NAME --public-network-access Enabled --default-action Deny --output none

    for check_IP in ${network_rules}; do
        check_IP="${check_IP%???}" # remove subnet mask (/32, /24... part) from IP - remove last three characters
        if [[ "$list_of_allowed_ips" != *"$check_IP"* ]]; then
            echo "[INFO] Removing IP '$check_IP'"
            az keyvault network-rule remove --name $KEY_VAULT_NAME --ip-address $check_IP --output none
        fi
    done

    echo "[INFO] Getting info about public network access and list of allowed IPs!"
	publicNetworkAccess="$(az keyvault show --name $KEY_VAULT_NAME --query properties.publicNetworkAccess)"
    network_rules="$(az keyvault network-rule list --name $KEY_VAULT_NAME --query "ipRules[*]" --output tsv)"
	
    echo "[INFO] Public network access to key vault '$KEY_VAULT_NAME' is '$publicNetworkAccess'" 
    echo "[INFO] Currently allowed IPs are '$network_rules'"

    revoke_access_to_key_vault_if_no_IPs_addedd
}

# revokes access to Key vault for all IPs
function revoke_access_to_key_vault(){
    set -eu
    echo "[INFO] Revoking access to Key vault '${KEY_VAULT_NAME}' by Disabling public access and removing all IPs from the list of allowed IPs!"
    az keyvault update --name $KEY_VAULT_NAME --public-network-access Disabled --default-action Deny --set properties.networkAcls.ipRules=[] --output none

    echo "[INFO] Getting info about public network access and list of allowed IPs!"
    publicNetworkAccess="$(az keyvault show --name $KEY_VAULT_NAME --query properties.publicNetworkAccess)"
    network_rules="$(az keyvault network-rule list --name $KEY_VAULT_NAME --query "ipRules[*]" --output tsv)"

    echo "[INFO] Public network access to key vault '$KEY_VAULT_NAME' is '$publicNetworkAccess'" 
    echo "[INFO] Currently allowed IPs are '$network_rules'"

    if [[ "$publicNetworkAccess"=="Disabled" && -z "$network_rules" ]]; then
	    echo "[INFO] Access to key vault '$KEY_VAULT_NAME' successfully revoked for all IPs!"
        exit 0
    else
	    echo "[ERROR] There was an issue while revoking access to key vault '$KEY_VAULT_NAME'!"
	    exit 1
    fi
}

########## ALLOWING ACCESS ##########
if [[ "${ACCESS_ACTION}" == "allow ips" ]]; then
    allow_access_to_key_vault_for_ips "$LIST_OF_IPS" # allow access from specific IPs

elif [[ "${ACCESS_ACTION}" == "allow host [and ips]" ]]; then
    echo "[INFO] Getting host IP!"
    host_ip=$(curl https://api.ipify.org)
    allow_access_to_key_vault_for_ips "$LIST_OF_IPS $host_ip" # allow access from host IP and optionaly from specific IPs

elif [[ "${ACCESS_ACTION}" == "allow all" ]]; then
    allow_public_access_to_key_vault # allow access completely publicly (for everyone)

########## REVOKING ACCESS ##########
elif [[ "${ACCESS_ACTION}" == "revoke ips" ]]; then
    revoke_access_to_key_vault_for_ips "$LIST_OF_IPS" # revoke access to Key vault for specifiv IPs

elif [[ "${ACCESS_ACTION}" == "revoke except" ]]; then
    revoke_and_keep_access_to_key_vault "$LIST_OF_IPS" # revoke access to Key vault for all IPs except 'LIST_OF_IPS'

elif [[ "${ACCESS_ACTION}" == "revoke all" ]]; then
    revoke_access_to_key_vault # completely revoke access to Key vault
fi