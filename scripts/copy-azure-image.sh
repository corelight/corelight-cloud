#!/bin/bash
#
# Azure Blob Copy and Image Creation Script
#
# This script copies a blob from a source Azure storage account (using SAS URL)
# to a destination storage account, with automatic resource creation if needed.
# After copying, it automatically creates a managed image from the VHD blob.
#
# Quick usage - curl and run directly from GitHub gist:
# curl -s https://raw.githubusercontent.com/corelight/corelight-cloud/refs/heads/main/scripts/copy-azure-image.sh | bash -s -- --source-sas "https://sourceaccount.blob.core.windows.net/container/file.vhd?sp=r&st=..."
#
# Or download and run locally:
# curl -O https://raw.githubusercontent.com/corelight/corelight-cloud/refs/heads/main/scripts/copy-azure-image.sh
# chmod +x copy-azure-image.sh
# ./copy-azure-image.sh --source-sas "https://sourceaccount.blob.core.windows.net/container/file.vhd?sp=r&st=..."
#

set -e

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Copy a blob from source to destination Azure storage account using azcopy and create a managed image.
The blob name will be automatically extracted from the source SAS URL.

OPTIONS:
    --source-sas                Source blob SAS URL (required)
    --dest-account-name         Destination storage account name (optional - will auto-create if not provided)
    --dest-container-name       Destination container name (optional - will auto-create if not provided)
    --dest-resource-group       Destination resource group name (required when using existing resources)
    --dest-location             Azure location for auto-created resources (default: East US)
    -h, --help                  Show this help message

EXAMPLE:
    $0 --source-sas "https://sourceaccount.blob.core.windows.net/container/example-file.vhd?sp=r&st=..." --dest-account-name "myaccount"
    $0 --source-sas "https://sourceaccount.blob.core.windows.net/container/example-file.vhd?sp=r&st=..." --dest-resource-group "my-rg"
    $0 --source-sas "https://sourceaccount.blob.core.windows.net/container/example-file.vhd?sp=r&st=..."  # Will auto-create all resources
EOF
}

# Set defaults
SOURCE_SAS=""

# Destination parameters - now optional
DESTINATION_ACCOUNT_NAME=""
DESTINATION_CONTAINER_NAME=""
DESTINATION_RESOURCE_GROUP=""
DESTINATION_LOCATION="East US"


# Blob name will be extracted from SAS URL
BLOB_NAME=""

# Helper functions
create_random_id() {
  echo "$RANDOM" | base64 | head -c 6 | tr '[:upper:]' '[:lower:]'
}

# Function to extract blob name from SAS URL
extract_blob_name_from_sas() {
    local sas_url="$1"

    # Remove query parameters (everything after ?)
    local url_without_params="${sas_url%%\?*}"

    # Extract the blob name (everything after the last /)
    local blob_name="${url_without_params##*/}"

    echo "$blob_name"
}

# Function to extract version from URL
extract_version_from_url() {
    local url="$1"
    
    # Remove query parameters
    local url_without_params="${url%%\?*}"
    
    # Extract version pattern (vX.Y.Z or vX.Y.Z-something)
    # Matches patterns like v28.4.0 or v28.4.0-rc20
    if [[ "$url_without_params" =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        local patch="${BASH_REMATCH[3]}"
        echo "${major}.${minor}.${patch}"
    else
        echo ""
    fi
}

# Function to compare versions
# Returns 0 if version1 < version2, 1 otherwise
version_less_than() {
    local version1="$1"
    local version2="$2"
    
    # Split versions into components
    IFS='.' read -ra v1_parts <<< "$version1"
    IFS='.' read -ra v2_parts <<< "$version2"
    
    # Compare major version
    if [[ ${v1_parts[0]} -lt ${v2_parts[0]} ]]; then
        return 0
    elif [[ ${v1_parts[0]} -gt ${v2_parts[0]} ]]; then
        return 1
    fi
    
    # Compare minor version
    if [[ ${v1_parts[1]} -lt ${v2_parts[1]} ]]; then
        return 0
    elif [[ ${v1_parts[1]} -gt ${v2_parts[1]} ]]; then
        return 1
    fi
    
    # Compare patch version
    if [[ ${v1_parts[2]} -lt ${v2_parts[2]} ]]; then
        return 0
    else
        return 1
    fi
}

# Check if any arguments were provided
if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source-sas)
            SOURCE_SAS="$2"
            shift 2
            ;;
        --dest-account-name)
            DESTINATION_ACCOUNT_NAME="$2"
            shift 2
            ;;
        --dest-container-name)
            DESTINATION_CONTAINER_NAME="$2"
            shift 2
            ;;
        --dest-resource-group)
            DESTINATION_RESOURCE_GROUP="$2"
            shift 2
            ;;
        --dest-location)
            DESTINATION_LOCATION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SOURCE_SAS" ]]; then
    echo "Error: --source-sas is required"
    echo ""
    usage
    exit 1
fi

# Extract blob name from source SAS URL
BLOB_NAME=$(extract_blob_name_from_sas "$SOURCE_SAS")

if [[ -z "$BLOB_NAME" ]]; then
    echo "Error: Could not extract blob name from source SAS URL"
    echo "Please ensure the SAS URL is in the correct format: https://account.blob.core.windows.net/container/blobname?..."
    echo ""
    usage
    exit 1
fi

echo "Extracted blob name: $BLOB_NAME"

# Validate blob type for image creation
if [[ ! "$BLOB_NAME" =~ \.vhd$ ]]; then
    echo "Warning: The blob '$BLOB_NAME' does not appear to be a VHD file."
    echo "Managed images are typically created from VHD files. Proceeding anyway..."
fi

# Check if destination parameters are provided
if [[ -z "$DESTINATION_ACCOUNT_NAME" || -z "$DESTINATION_CONTAINER_NAME" ]]; then
    echo "Destination account/container not provided. Will auto-create resources..."
    AUTO_CREATE_RESOURCES=true
else
    AUTO_CREATE_RESOURCES=false
fi

# Function to get expiry date 24 hours from now in Azure SAS format
get_sas_expiry() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        date -v+1d -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        # Linux
        date -d "+1 day" -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Function to create resource group if it doesn't exist
create_resource_group() {
    local rg_name="$1"
    local location="$2"

    echo "Checking if resource group '$rg_name' exists..."
    if ! az group show --name "$rg_name" &>/dev/null; then
        echo "Creating resource group '$rg_name' in location '$location'..."
        az group create --name "$rg_name" --location "$location"
    else
        echo "Resource group '$rg_name' already exists."
    fi
}

# Function to create storage account
create_storage_account() {
    local account_name="$1"
    local rg_name="$2"
    local location="$3"

    echo "Creating storage account '$account_name'..."
    az storage account create \
        --name "$account_name" \
        --resource-group "$rg_name" \
        --location "$location" \
        --sku Standard_LRS \
        --kind StorageV2
}

# Function to create container
create_container() {
    local account_name="$1"
    local container_name="$2"

    echo "Creating container '$container_name' in storage account '$account_name'..."
    az storage container create \
        --name "$container_name" \
        --account-name "$account_name"
}

# Function to generate unique resource group name
generate_resource_group_name() {
    local prefix="corelightimages"
    echo "corelightimages-$(create_random_id)"
}

# Function to generate unique storage account name
generate_storage_account_name() {
    local prefix="corelightimages"
    echo "corelightimages$(create_random_id)"
}

# Function to generate SAS URL and remove quotes
generate_sas_url() {
    local account_name="$1"
    local container_name="$2"
    local blob_name="$3"
    local expiry="$4"

    local sas_url=$(az storage blob generate-sas \
        --account-name "$account_name" \
        --container-name "$container_name" \
        --name "$blob_name" \
        --expiry "$expiry" \
        --permissions acdrw \
        --full-uri)

    # Remove surrounding quotes
    echo "${sas_url//\"/}"
}

# Function to check if managed image already exists
check_image_exists() {
    local image_name="$1"
    local resource_group="$2"

    echo "Checking if managed image '$image_name' exists in resource group '$resource_group'..."
    if az image show --name "$image_name" --resource-group "$resource_group" &>/dev/null; then
        echo "Managed image '$image_name' already exists."
        return 0
    else
        echo "Managed image '$image_name' does not exist."
        return 1
    fi
}

# Function to create managed image from VHD blob
create_managed_image() {
    local image_name="$1"
    local resource_group="$2"
    local location="$3"
    local storage_account="$4"
    local container_name="$5"
    local blob_name="$6"
    local hyperv_generation="$7"

    # Construct the VHD blob URI
    local vhd_uri="https://${storage_account}.blob.core.windows.net/${container_name}/${blob_name}"

    echo "Creating managed image '$image_name' from VHD blob..."
    echo "VHD URI: $vhd_uri"
    echo "Hyper-V Generation: $hyperv_generation"

    az image create \
        --name "$image_name" \
        --resource-group "$resource_group" \
        --location "$location" \
        --hyper-v-generation "$hyperv_generation" \
        --source "$vhd_uri" \
        --os-type Linux

    if [[ $? -eq 0 ]]; then
        echo "Successfully created managed image '$image_name'."
    else
        echo "Failed to create managed image '$image_name'."
        return 1
    fi
}

# Function to generate image name from blob name
generate_image_name() {
    local blob_name="$1"
    # Remove .vhd extension
    local base_name="${blob_name%.vhd}"
    echo "$base_name"
}

# Auto-create resources if needed
# When AUTO_CREATE_RESOURCES=true, this creates:
# - Resource Group (if not provided)
# - Storage Account (if not provided)
# - Storage Container (if not provided)
if [[ "$AUTO_CREATE_RESOURCES" == "true" ]]; then
    echo "Auto-creating destination resources..."

    # Generate resource group name if not provided
    if [[ -z "$DESTINATION_RESOURCE_GROUP" ]]; then
        DESTINATION_RESOURCE_GROUP=$(generate_resource_group_name)
        echo "Generated resource group name: $DESTINATION_RESOURCE_GROUP"
    fi

    # Create resource group
    create_resource_group "$DESTINATION_RESOURCE_GROUP" "$DESTINATION_LOCATION"

    # Generate unique storage account name if not provided
    if [[ -z "$DESTINATION_ACCOUNT_NAME" ]]; then
        DESTINATION_ACCOUNT_NAME=$(generate_storage_account_name)
        echo "Generated storage account name: $DESTINATION_ACCOUNT_NAME"
    fi

    # Set default container name if not provided
    if [[ -z "$DESTINATION_CONTAINER_NAME" ]]; then
        DESTINATION_CONTAINER_NAME="corelightsensor"
        echo "Using default container name: $DESTINATION_CONTAINER_NAME"
    fi

    # Create storage account
    create_storage_account "$DESTINATION_ACCOUNT_NAME" "$DESTINATION_RESOURCE_GROUP" "$DESTINATION_LOCATION"

    # Wait a bit for storage account to be fully provisioned
    echo "Waiting for storage account to be ready..."
    sleep 10

    # Create container
    create_container "$DESTINATION_ACCOUNT_NAME" "$DESTINATION_CONTAINER_NAME"
else
    # When using existing resources, ensure resource group is set
    if [[ -z "$DESTINATION_RESOURCE_GROUP" ]]; then
        echo "Error: When using existing resources, --dest-resource-group must be provided for image creation"
        exit 1
    fi

    echo "Using existing resources:"
    echo "  Resource Group: $DESTINATION_RESOURCE_GROUP"
    echo "  Storage Account: $DESTINATION_ACCOUNT_NAME"
    echo "  Container: $DESTINATION_CONTAINER_NAME"
fi

EXPIRY_DATE=$(get_sas_expiry)

echo "Generating destination SAS URL..."
DESTINATION_SAS=$(generate_sas_url "$DESTINATION_ACCOUNT_NAME" "$DESTINATION_CONTAINER_NAME" "$BLOB_NAME" "$EXPIRY_DATE")

echo "Copying blob from source to destination..."
echo "Source SAS: $SOURCE_SAS"
echo "Destination: $DESTINATION_ACCOUNT_NAME/$DESTINATION_CONTAINER_NAME/$BLOB_NAME"

azcopy cp "$SOURCE_SAS" "$DESTINATION_SAS"

echo "Copy completed successfully!"
if [[ "$AUTO_CREATE_RESOURCES" == "true" ]]; then
    echo "Created resources:"
    echo "  Resource Group: $DESTINATION_RESOURCE_GROUP"
    echo "  Storage Account: $DESTINATION_ACCOUNT_NAME"
    echo "  Container: $DESTINATION_CONTAINER_NAME"
fi

# Create managed image
echo ""
echo "Processing managed image creation..."

# Extract version from source SAS URL
VERSION=$(extract_version_from_url "$SOURCE_SAS")
if [[ -n "$VERSION" ]]; then
    echo "Detected version: $VERSION"
    
    # Determine Hyper-V generation based on version
    # Version < 28.4.0 uses V1, otherwise V2
    if version_less_than "$VERSION" "28.4.0"; then
        HYPERV_GENERATION="V1"
        echo "Version $VERSION is less than 28.4.0, using Hyper-V Generation V1"
    else
        HYPERV_GENERATION="V2"
        echo "Version $VERSION is 28.4.0 or greater, using Hyper-V Generation V2"
    fi
else
    # Default to V2 if version cannot be detected
    HYPERV_GENERATION="V2"
    echo "Warning: Could not extract version from URL, defaulting to Hyper-V Generation V2"
fi

# Generate image name from blob name (without .vhd extension)
IMAGE_NAME=$(generate_image_name "$BLOB_NAME")
echo "Using image name: $IMAGE_NAME"

# Check if image already exists
if check_image_exists "$IMAGE_NAME" "$DESTINATION_RESOURCE_GROUP"; then
    echo "Managed image '$IMAGE_NAME' already exists. Skipping image creation."
else
    # Create the managed image
    echo "Creating managed image from VHD blob..."
    if create_managed_image "$IMAGE_NAME" "$DESTINATION_RESOURCE_GROUP" "$DESTINATION_LOCATION" "$DESTINATION_ACCOUNT_NAME" "$DESTINATION_CONTAINER_NAME" "$BLOB_NAME" "$HYPERV_GENERATION"; then
        echo "Managed image creation completed successfully!"
        echo "  Image Name: $IMAGE_NAME"
        echo "  Resource Group: $DESTINATION_RESOURCE_GROUP"
        echo "  Location: $DESTINATION_LOCATION"
        echo "  Hyper-V Generation: $HYPERV_GENERATION"
    else
        echo "Failed to create managed image. Please check Azure CLI output for details."
        exit 1
    fi
fi


