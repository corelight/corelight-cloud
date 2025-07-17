#!/bin/bash

# Read JSON from stdin
INPUT=$(cat)

# Parse values using jq
FLEET_URL=$(echo "$INPUT" | jq -r '.fleet_url')
FLEET_USERNAME=$(echo "$INPUT" | jq -r '.fleet_username')
FLEET_PASSWORD=$(echo "$INPUT" | jq -r '.fleet_password')
SENSOR_INSTANCE_NAME=$(echo "$INPUT" | jq -r '.sensor_instance_name')

# Get the bearer auth token for Fleet
AUTH=$(curl -s "$FLEET_URL/login" \
  -H "content-type: application/json" \
  -H "user-agent: corelight-client" \
  --data-raw "{\"username\":\"$FLEET_USERNAME\",\"password\":\"$FLEET_PASSWORD\"}" \
  --insecure | jq -r .token)

# Create a new tethered sensor in Fleet. Store the tether token from the creation
DATA="{\"name\":\"$SENSOR_INSTANCE_NAME\",\"provider\":\"TETHERED\"}"
SENSORSTRING=$(curl -s "$FLEET_URL/sensor/catalog" \
  -H "accept: application/json, text/plain, */*" \
  -H "authorization: Bearer $AUTH" \
  -H "content-type: application/json" \
  -H "user-agent: corelight-client" \
  --data-raw "$DATA" \
  --insecure)

TETHERTOKEN=$(echo "$SENSORSTRING" | jq -r .tethering_token)

# Output as JSON for Terraform external data source
echo "{\"token\": \"$TETHERTOKEN\"}"