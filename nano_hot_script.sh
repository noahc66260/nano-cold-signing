#!/bin/bash

# Run this script on an internet connected computer.
#
# We need to get the hash of the head block of the account
# we want to create a transaction from.
# This is to verify the block we will be using to construct
# a transaction from so we know the account balance is not 
# tinkered with.
#
# With the block data we can create a signed transaction 
# on the cold computer.
#
# Input file has three lines:
# from:[account]
# to:[account]
# amount:[value in raw units]

INPUT_FILE="nano_hot_script_input.txt"

if ! test -f "$INPUT_FILE"; then
    echo "$INPUT_FILE does not exist" >&2; exit 1
fi

exec 3< $INPUT_FILE
read -r ACCOUNT_LINE <&3 
read -r DESTINATION_LINE <&3 
read -r AMOUNT_LINE <&3 
ACCOUNT="${ACCOUNT_LINE:5}"
DESTINATION="${DESTINATION_LINE:3}"
AMOUNT="${AMOUNT_LINE:7}"

function validate_account {
  local ACCOUNT=$1
  local REG_EXPRESSION='^nano_[a-z0-9]{60}|^xrb_[a-z0-9]{60}'
  if ! [[ $ACCOUNT =~ $REG_EXPRESSION ]] ; then
     echo "error: $ACCOUNT is not an account" >&2; exit 1
  fi
}

function validate_raw_number {
  local NUMBER=$1
  local REG_EXPRESSION='^[1-9][0-9]*$'
  if ! [[ $NUMBER =~ $REG_EXPRESSION ]] ; then
     echo "error: Amount must be a number in raw units." >&2; exit 1
  fi
}
validate_account "$ACCOUNT"
validate_account "$DESTINATION"
validate_raw_number "$AMOUNT"

ENDPOINT="http://127.0.0.1:7076"
OUTPUT_FILE="nano_cold_script_input.txt"

function get_account_info {
  local ACCOUNT=$1
  local ENDPOINT=$2
  local ACTION="account_info"
  local REPRESENTATIVE="true"
  local JSON_STRING=$( jq -n \
                    --arg act "$ACTION" \
                    --arg acc "$ACCOUNT" \
                    --arg rep "$REPRESENTATIVE" \
                    '{action: $act, account: $acc, representative: $rep}' )

  ACCOUNT_INFO=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
  local IS_ERROR=$(echo $ACCOUNT_INFO | jq -r '.error'!=null)
  if [ "$IS_ERROR" == "true" ]
  then
     echo "error: $ACCOUNT_INFO" >&2; exit 1
  fi
}

function get_block_info {
  local ACTION="block_info"
  local HASH=$1
  local ENDPOINT=$2
  local JSON_STRING=$( jq -n \
                    --arg act "$ACTION" \
                    --arg has "$HASH" \
                    '{action: $act, hash: $has}' )
  BLOCK_INFO=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
  local IS_ERROR=$(echo $BLOCK_INFO | jq -r '.error'!=null)
  if [ "$IS_ERROR" == "true" ]
  then
     echo "error: $BLOCK_INFO" >&2; exit 1
  else
    return 0
  fi
}

get_account_info "$ACCOUNT" "$ENDPOINT"
HASH=$(echo $ACCOUNT_INFO | jq -r '.frontier')
get_block_info "$HASH" "$ENDPOINT"

echo $HASH > $OUTPUT_FILE
echo $BLOCK_INFO >> $OUTPUT_FILE
echo $DESTINATION >> $OUTPUT_FILE
echo $AMOUNT >> $OUTPUT_FILE
