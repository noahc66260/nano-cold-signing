This project contains scripts which allow you to make better use of cold
storage by signing transactions from an offline computer. Currently only
sending is supported (not receiving). I am assuming the reader knows the 
basics of cold signing.

Hot computer dependencies: 
  bash
  jq - for reading and generating json from bash
  curl - for rpc calls
  nano full node
  
Cold computer dependencies: 
  bash
  jq - for reading and generating json from bash
  curl - for rpc calls
  nano node, not synced

For each nano node, the config.json should be modified to accept RPC calls.
This probably means setting rpc_enable to true.
For the cold wallet, the config.json must allow signing.
This probably means setting rpc.enable_control to true.

Normally for cold signing, and unsigned transaction is generated on the
hot computer to be signed by the cold computer. For Nano, it works
slightly differently because there is no such thing as an unsigned 
transaction and the entire process must be done through RPC.
The workflow is intended to be:
  1. Configure the input to the hot script manually
  2. Run the hot script which outputs data
  3. Transfer the intermediate data to the cold computer
  4. Run the cold script with the intermediate data as input
  5. Transfer the output of the cold script to the hot computer
  6. Run the broadcast script on the final data

More specifically:
[on hot computer]
$ gedit nano_hot_script_input.txt
$ bash nano_hot_script.sh
[move generated file -- nano_cold_script_input.txt -- to cold computer]
[on cold computer]
$ bash nano_cold_script.sh [seed]
[move generated file -- nano_signed_block.txt -- to old computer]
[on hot computer]
$ bash nano_broadcast_block.sh

The initial input to the hot script is a simple file which specifies
which account is sending money, which account is receiving money, 
and what the amount is (in raw units). Since typing raw units manually
is a huge pain, there is an additional script to take Nano units
(aka MRai) and convert it into raw units. Use it like so:
$ bash nano_to_raw.sh 123.456
