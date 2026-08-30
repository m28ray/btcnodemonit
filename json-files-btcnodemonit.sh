#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2026 m28ray
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

################################################
#
# How to use:
#
# json-files-btcnodemonit.sh
#   Get data from .json files in the same directory as this script then exit.
#
# json-files-btcnodemonit.sh [jsonDir]
#   Get data from .json files in the directory added after the 
#   script name then exit
#
#   Example: 
#   ./json-files-btcnodemonit.sh "/path/to/myData"
#
################################################

readonly files=(
getblockcount.json
getnetworkinfo.json
getnettotals.json
getmempoolinfo.json
getblockstats.json
getpeerinfo.json
)

set -o errexit # Exit immediately if any command returns a non-zero exit status
# set -o xtrace # Uncomment for debugging

readonly showBlockStats=1

# Function bytesPrefix
# Number of arguments: 4
# Arguments: Bitcoin-cli output, The item to match, The display name, The unit
function bytesPrefix {
  local line text bytes prefix negSign unit
  line=$(grep "\"$2\"" <<< "$1")
  text="$3"
  bytes=$(grep -E --only-matching "[0-9]+" <<< "$line")
  if grep --quiet -- "-[0-9]" <<< "$line"; then
    negSign="-"
  else
    negSign=""
  fi
  unit="B"
  if ! [[ -z $4 ]]; then
    unit="$4"
  fi

  prefix=""
  if [[ $bytes -ge 1000000000 ]]; then
    prefix="G"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000000000}')
  elif [[ $bytes -ge 1000000 ]]; then
    prefix="M"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000000}')
  elif [[ $bytes -ge 1000 ]]; then
    prefix="K"
    bytes=$(awk -v byte="$bytes" -v q="'" 'BEGIN {printf "%"q".2f", byte/1000}')
  fi

  printf "  %s: %s%s %s%s\n" "$text" "$negSign" "$bytes" "$prefix" "$unit"
}

# Function minutesSinceMined
# Number of arguments: 1
# Argument: Block stats
function minutesSinceMined {
  local blockTime unixSeconds
  unixSeconds=$(date +%s)
  blockTime=$(grep "\"time\"" <<<"$1" |grep -E --only-matching "[0-9]+")
  if [[ $(( ($unixSeconds-$blockTime)/60 )) -lt 180 ]]; then
    awk -v unixSeconds="$unixSeconds" -v blockTime="$blockTime" \
    'BEGIN {printf "%.1f min", (unixSeconds-blockTime)/60}'
  else
    awk -v unixSeconds="$unixSeconds" -v blockTime="$blockTime" \
    'BEGIN {printf "%.1f h", (unixSeconds-blockTime)/60/60}'
  fi
}

# Function validateJsonDir
# Number of arguments: 0
function validateJsonDir {
  local helpText="\nPlace this script in the same directory as the .json files or type\nthe .json files directory after the script name:\n\n./json-files-btcnodemonit.sh\n./json-files-btcnodemonit.sh \"/path/to/myData\"\n\n"
  if ! [[ "$jsonDir" =~ ^[\ a-zA-Z0-9/_.-]+$ ]]; then
    echo "Error: \"jsonDir\" has invalid characters"
    exit 1
  fi
  if ! [[ -d "$jsonDir"  ]]; then
    echo "Error: $jsonDir is not a directory"
    exit 1
  fi
  if ! [[ -r "$jsonDir"  ]]; then
    echo "Error: $jsonDir is not readable by you"
    printf '%b' "$helpText"
    exit 1
  fi
  for f in ${files[@]}; do
    if ! [[ -r "$jsonDir/$f" ]]; then
      echo "Error: $f is not readable by you"
      printf '%b' "$helpText"
      exit 1
    fi
  done
}

# Function printInteger
# Number of arguments: 4
# Arguments: Bitcoin-cli output, The item to match, The display name, The unit
# Example: printInteger "$gmi" "size" "mempool tx count" ""
function printInteger {
  local number
  number="$(grep "\"$2\"" <<< "$1" | grep -E --only-matching -- "-?[0-9]+" \
          || echo "No matching integer")"
  printf "  %s: %'.0f %s\n" "$3" "$number" "$4"
}

function detectCommaAsDecimalSeparator {
  # Formats 0.5 and checks if the output contains a comma
  # To make printf reliable for locale detection, you must check the output
  # string rather than the exit status - Google
  local output
  output=$(printf "%f" 0.5 2>/dev/null)
  if [[ "$output" =~ , ]]; then
    echo "true"
  else
    echo "false"
  fi
}


jsonDir="$(dirname "$0")"
if [[ -n "$1" ]]; then
  jsonDir="$1"
fi
validateJsonDir

# Get data
gbc=$(< "$jsonDir/${files[0]}") # getblockcount
gni=$(< "$jsonDir/${files[1]}") # getnetworkinfo
gnt=$(< "$jsonDir/${files[2]}") # getnettotals
gmi=$(< "$jsonDir/${files[3]}") # getmempoolinfo
gbs=$(< "$jsonDir/${files[4]}") # getblockstats
bip110Count=$(grep --count "REDUCED_DATA?" "$jsonDir/${files[5]}" \
            || true) # getpeerinfo

# Confirm getblockcount and getblockstats are for the same block
if [[ showBlockStats -eq 1 ]]; then
  blockStatsHeight=$(grep '"height"' <<< "$gbs" | grep -E --only-matching "[0-9]+")
  if ! [[ $gbc -eq  $blockStatsHeight ]]; then
    echo "Error: getblockcount and getblockstats are not for the same block"
    exit 1
  fi
fi

# More data
timeMilliS=$(grep '"timemillis"' <<<"$gnt" \
           | grep -E --only-matching "[0-9]+" \
           | awk '{printf "%.0f", $1/1000 }')
# Linux and Mac date
if date --date=@1 >/dev/null 2>&1; then
  date=$(date --date=@$timeMilliS "+%Y-%m-%d %I:%M:%S %p %Z")
else
  date=$(date -r $timeMilliS "+%Y-%m-%d %I:%M:%S %p %Z")
fi


# Format output
echo "  date: $date"
printInteger "$gni" "connections" "connections" ""
printInteger "$gni" "connections_in" "connections_in" ""
printInteger "$gni" "connections_out" "connections_out" ""
echo "  bip110 peers: $bip110Count"
bytesPrefix "$gnt" "totalbytesrecv" "totalbytesrecv" ""
bytesPrefix "$gnt" "totalbytessent" "totalbytessent" ""
bytesPrefix "$gnt" "bytes_left_in_cycle" "bytes_left_in_cycle" ""
grep '"time_left_in_cycle"' <<< "$gnt" |grep -E --only-matching "[0-9]+" \
     |awk '{printf "  time_left_in_cycle: %.2f h\n", $1/60/60}'
echo ""
printInteger "$gmi" "size" "mempool tx count" ""
bytesPrefix "$gmi" "bytes" "mempool virtual bytes" "vB"
total_fee=$(grep '"total_fee"' <<< "$gmi" |grep -E --only-matching "[0-9.]+")
if [[ "$(detectCommaAsDecimalSeparator)" == "true" ]]; then
  total_fee="$(tr '.' ',' <<< "$total_fee")"
fi
echo "  mempool total_fee: $total_fee BTC"
bytesPrefix "$gmi" "usage" "mempool memory usage" ""
echo ""

printf "  block: %s" "$gbc"
if [[ showBlockStats -eq 0 ]]; then
  echo ""
  exit 0
fi
echo "  $(minutesSinceMined "$gbs") ago"
bytesPrefix "$gbs" "total_size" "total_size" ""
bytesPrefix "$gbs" "total_weight" "total_weight" "WU"
printInteger "$gbs" "utxo_increase" "utxo_increase" ""
printInteger "$gbs" "utxo_increase_actual" "utxo_increase_actual" ""
bytesPrefix "$gbs" "utxo_size_inc" "utxo_size_inc" ""
bytesPrefix "$gbs" "utxo_size_inc_actual" "utxo_size_inc_actual" ""
printInteger "$gbs" "txs" "txs" ""
totalOut=$(grep '"total_out"' <<< "$gbs" |grep -E --only-matching "[0-9]+")
awk -v tOut="$totalOut" -v q="'" \
    'BEGIN {printf "  total_out: %"q".2f BTC\n", tOut/100000000}'
printInteger "$gbs" "avgfeerate" "avgfeerate" "sat/vB"
printInteger "$gbs" "minfeerate" "minfeerate" "sat/vB"
printInteger "$gbs" "maxfeerate" "maxfeerate" "sat/vB"
grep --after-context=5 '"feerate_percentiles"' <<< "$gbs" \
     |tr -d '\n"[' |sed 's/: /:/' |sed 's/    / /g'
echo ""
