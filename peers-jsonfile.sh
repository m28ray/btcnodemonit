#!/usr/bin/env bash

# Licensed under the MIT License

readonly peerInfoFile="getpeerinfo.json"

set -o errexit # Exit immediately if any command returns a non-zero exit status

# Function bytesPrefix
# Number of arguments: 1
# Arguments: bytes
function bytesPrefix {
  local bytes prefix unit
  bytes="$1"
  unit="B"
  prefix=""
  if [[ $bytes -ge 1000000000000 ]]; then
    prefix="T"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000000000000}')
  elif [[ $bytes -ge 1000000000 ]]; then
    prefix="G"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000000000}')
  elif [[ $bytes -ge 1000000 ]]; then
    prefix="M"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000000}')
  elif [[ $bytes -ge 1000 ]]; then
    prefix="K"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000}')
  fi

  printf "%s %s%s\n" "$bytes" "$prefix" "$unit"
}

function countPeers {
  local total b2b
  total=$(grep --count "\"id\"" "$peerInfoFile" || true)
  b2b=$(grep --count "BLAKE2B" "$peerInfoFile" || true)
  printf "Connections: %u   BLAKE2b: %u   %u%%\n\n" \
    "$total" "$b2b" "$(( 100 * $b2b / $total ))"
}

function jqRequired {
  if ! jq --help >/dev/null 2>&1; then
    echo "jq is not installed. sudo apt install jq | sudo dnf install jq"
    exit 1
  fi
}
jqRequired
countPeers

datePad=$(( $(wc -c <<< "$(date)") + 2 )) #34

printf "%-50s %-6s %-12s %-12s %-${datePad}s %s\n" \
  "Address" "In/Out" "Bytes Sent" "Bytes Recv" "Connection Time" "Subver"

# Loop through each object
while IFS= read -r item; do
  # Extract specific fields from the current object
  addr=$(jq -r '.addr' <<< "$item")
  inbound=$( [[ "$(jq -r '.inbound' <<< "$item")" == "true" ]] && echo "in" || echo "out" )
  bytessent=$(bytesPrefix "$(jq -r '.bytessent' <<< "$item")")
  bytesrecv=$(bytesPrefix "$(jq -r '.bytesrecv' <<< "$item")")
  conntime=$( date -d @$(jq -r '.conntime' <<< "$item") 2>/dev/null \
           || date -r $(jq -r '.conntime' <<< "$item") 2>/dev/null \
           || echo "Linux and Mac date failed")
  subver=$(jq -r '.subver' <<< "$item")

  printf "%-50s %-6s %-12s %-12s %-${datePad}s %s\n" \
    "$addr" \
    "$inbound" \
    "$bytessent" \
    "$bytesrecv" \
    "$conntime" \
    "$subver"

done < <(jq -c '.[]' "$peerInfoFile")
