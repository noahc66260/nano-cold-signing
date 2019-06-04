# This is to broadcast a block


INPUT_FILE="nano_signed_block.txt"
exec 3< $INPUT_FILE
read -r SIGNED_BLOCK_WRAPPER <&3 
ENDPOINT="http://localhost:7076"
SIGNED_BLOCK=$(echo $SIGNED_BLOCK_WRAPPER | jq -r '.block') 


function confirm_details {
  local BLOCK=$1
  echo -e "$BLOCK"
  read -p "Do you wish to broadcast this block? " yn
  case $yn in
      [Yy]* ) echo 'broadcasting block';;
      [Nn]* ) echo 'exiting program'; exit;;
      * ) echo "Please answer yes or no.";;
  esac
}


# first arg is the block
# seocnd arg is the endpoint
function broadcast_block {
  local BLOCK=$1 
  local ENDPOINT=$2
  local ACTION="process"
  local JSON_STRING=$( jq -n \
                    --arg act "$ACTION" \
                    --arg blk "$BLOCK" \
                    '{action: $act, block: $blk}' )
  ACCOUNT_INFO=$(curl -sSd "${JSON_STRING}" $ENDPOINT)
  local IS_ERROR=$(echo $ACCOUNT_INFO | jq -r '.error'!=null)
  if [ "$IS_ERROR" == "true" ]
  then
     echo "error: $ACCOUNT_INFO" >&2; exit 1
  fi
}

confirm_details "$SIGNED_BLOCK"
broadcast_block "$SIGNED_BLOCK" "$ENDPOINT"
