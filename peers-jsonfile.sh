#!/usr/bin/env bash

# Licensed under the MIT License

readonly peerInfoFile="$(dirname "$0")/getpeerinfo.json"

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
  local total b2b percent
  total=$(grep --count "\"id\"" "$peerInfoFile" || true)
  b2b=$(grep --count "BLAKE2B" "$peerInfoFile" || true)
  percent=$([[ $total -gt 0 ]] && echo "$(( 100 * $b2b / $total ))" || echo "0")
  printf "Connections: %u   BLAKE2b: %u   %u%%\n\n" \
    "$total" "$b2b" "$percent"
}

function jqRequired {
  if ! jq --help >/dev/null 2>&1; then
    echo "jq is not installed. sudo apt install jq OR sudo dnf install jq"
    exit 1
  fi
  if ! [[ -r "$peerInfoFile" ]]; then
    echo "Cannot read $peerInfoFile"
    exit 1
  fi  
}
jqRequired
countPeers

datePad=$(( $(wc -c <<< "$(date)") + 2 )) #34

printf "%-50s %-6s %-12s %-12s %-${datePad}s %s\n" \
  "Address" "In/Out" "Bytes Sent" "Bytes Recv" "Connection Time" "Subver"

# Grok's version that extracts everything in a single jq pass and feeds it to the loop.
# Extract all needed fields in one jq call (TSV, null-safe)
while IFS=$'\t' read -r addr inbound bytessent bytesrecv conntime subver; do
  bytessent=$(bytesPrefix "$bytessent")
  bytesrecv=$(bytesPrefix "$bytesrecv")

  # date conversion (GNU then BSD)
  conntime=$(date -d "@$conntime" 2>/dev/null \
          || date -r "$conntime" 2>/dev/null \
          || echo "Linux and Mac date failed")

  printf "%-50s %-6s %-12s %-12s %-${datePad}s %s\n" \
    "$addr" \
    "$inbound" \
    "$bytessent" \
    "$bytesrecv" \
    "$conntime" \
    "$subver"

done < <(jq -r '
  .[] | [
    .addr // "?",
    (if .inbound == true then "in" else "out" end),
    (.bytessent // 0 | tostring),
    (.bytesrecv // 0 | tostring),
    (.conntime // 0 | tostring),
    (.subver // "")
  ] | @tsv
' "$peerInfoFile")
