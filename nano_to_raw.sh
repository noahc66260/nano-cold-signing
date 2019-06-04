#!/bin/bash

# to convert nano to raw units
# this will floor the fractional raw units
# pass in the units as the arguments
# e.g. 
# $ bash nano_to_raw 123.456
AMOUNT_AS_NANO=$1
ENDPOINT="http://localhost:7076"

function validate_number {
  local NUMBER=$1
  local REG_EXPRESSION='^[0-9]+\.[0-9]+$'
  if ! [[ $NUMBER =~ $REG_EXPRESSION ]] ; then
     echo "error: $NUMBER is not a number" >&2; exit 1
  fi
}

validate_number $AMOUNT_AS_NANO
function nano_to_raw {
  local AMOUNT_AS_NANO=$1
  local ENDPOINT=$2
  # one nano is a MRai
  local ACTION="mrai_to_raw"
  local ONE_NANO=1
  local JSON_STRING=$( jq -n \
                    --arg act "$ACTION" \
                    --arg amt "$ONE_NANO" \
                    '{action: $act, amount: $amt}' )
  local RESPONSE=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
  local IS_ERROR=$(echo $RESPONSE | jq -r '.error'!=null)
  if [ "$IS_ERROR" == "true" ]
  then
     echo "error: $RESPONSE" >&2; exit 1
  fi
  NANO_TO_RAW_CONVERSION=$(echo $RESPONSE | jq -r '.amount')
  AMOUNT_IN_RAW=$(bc <<< "($NANO_TO_RAW_CONVERSION * $AMOUNT_AS_NANO)/1")
}

nano_to_raw "$AMOUNT_AS_NANO" "$ENDPOINT"
echo $AMOUNT_IN_RAW
