#!/bin/bash

# Run this script on the cold computer
#
# This only works if you have a seed for your accounts
# The first argument is the seed.
# e.g.
# $ bash nano_cold_script.sh [seed]
# 
# Input file required is generated from the hot script
# Output file is fed into the broadcast script

SEED=$1
if [ -z "$SEED" ]
then
      echo "Seed must be provided as an argument" >&2; exit 1
fi

INPUT_FILE="nano_cold_script_input.txt"
if ! test -f "$INPUT_FILE"; then
    echo "$INPUT_FILE does not exist" >&2; exit 1
fi

exec 3< $INPUT_FILE
read -r BLOCK_HASH <&3
read -r BLOCK_INFO <&3
read -r DESTINATION <&3
read -r AMOUNT_AS_RAW <&3
ENDPOINT="http://127.0.0.1:7076"

# first arg is block_info contents
# second arg is block hash
# third arg is endpoint
function verify_block_hash {
  local BLOCK=$1
  local EXPECTED_HASH=$2
  local ENDPOINT=$3
  local ACTION="block_hash"
  local JSON_STRING=$( jq -n \
                    --arg act "$ACTION" \
                    --arg blk "$BLOCK" \
                    '{action: $act, block: $blk}' )
  local HASH_DATA=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
  local ACTUAL_HASH=$(echo $HASH_DATA | jq -r '.hash') 
  if ! [ $ACTUAL_HASH = $EXPECTED_HASH ]; then
    echo "Hash of block info contents did not verify" >&2; exit 1
  fi
}

# first arg is seed, second is account you want the private key to
function get_key_from_seed {
  local SEED=$1
  local EXPECTED_ACCOUNT=$2
  local ATTEMPTS=100
  for INDEX in $(seq 0 $ATTEMPTS) 
  do
    local ACTION="deterministic_key"
    local JSON_STRING=$( jq -n \
                      --arg act "$ACTION" \
                      --arg seed "$SEED" \
                      --arg ind "$INDEX" \
                      '{action: $act, seed: $seed, index: $ind}' )
    local KEY_DATA=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
    local ACTUAL_ACCOUNT=$(echo $KEY_DATA | jq -r '.account')
    if [ "$ACTUAL_ACCOUNT" == "$EXPECTED_ACCOUNT" ]
    then
      PRIVATE_KEY=$(echo $KEY_DATA | jq -r '.private')
      return
    fi
  done
  echo "error: Account not found from seed after $ATTEMPTS indexes searched" >&2; exit 1
}


BLOCK=$(echo $BLOCK_INFO | jq -r '.contents')
verify_block_hash "$BLOCK" "$BLOCK_HASH" "$ENDPOINT"

ACCOUNT=$(echo $BLOCK | jq -r '.account')
get_key_from_seed "$SEED" "$ACCOUNT"

# first arg - block
# second arg - hash
# third arg - key
# fourth arg - destination
# fifth arg - amount as raw units
# sixth arg - endpoint
function block_create {
  local BLOCK=$1
  local BLOCK_HASH=$2
  local KEY=$3
  local DESTINATION=$4
  local AMOUNT_TO_SEND_RAW=$5
  local ENDPOINT=$6
  local ACTION="block_create"
  local TYPE="state"
  local REPRESENTATIVE=$(echo $BLOCK | jq -r '.representative')
  local ORIGINAL_BALANCE=$(echo $BLOCK | jq -r '.balance')
  local NEW_BALANCE=$(bc <<< "$ORIGINAL_BALANCE - $AMOUNT_TO_SEND_RAW")
  local JSON_STRING=$( jq -n \
                    --arg act "$ACTION" \
                    --arg typ "$TYPE" \
                    --arg pre "$BLOCK_HASH" \
                    --arg rep "$REPRESENTATIVE" \
                    --arg bal "$NEW_BALANCE" \
                    --arg lin "$DESTINATION" \
                    --arg key "$KEY" \
                    '{action: $act, type: $typ, previous: $pre, representative: $rep, balance: $bal, link: $lin, key: $key}' )
  SIGNED_BLOCK=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
  local IS_ERROR=$(echo $SIGNED_BLOCK | jq -r '.error'!=null)
  if [ "$IS_ERROR" == "true" ]
  then
    echo 'in block_create'
    echo "error: $SIGNED_BLOCK" >&2; exit 1
  fi  
}

block_create "$BLOCK" "$BLOCK_HASH" "$PRIVATE_KEY" "$DESTINATION" "$AMOUNT_AS_RAW" "$ENDPOINT"

OUTPUT_FILE="nano_signed_block.txt"
echo $SIGNED_BLOCK > $OUTPUT_FILE
