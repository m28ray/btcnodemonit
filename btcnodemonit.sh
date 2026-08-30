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
# btcnodemonit.sh
#   Show node stats and recent block stats then exit
#
# btcnodemonit.sh [blockNumber]
#   Show node stats and given block stats then exit
#   Example:  btcnodemonit.sh 912345
#
################################################
# User defined variables
#
# bitcoinDir
# The filesystem (Example: /dev/sdb) or mount point (Example: /mnt/data)
# of the bitcoin directory. If left blank the default is /.
# Used by 'df' command to show free disk space.
bitcoinDir="/"
#
# bitcoinCli
# The 'bitcoin-cli' command and optional arguments
# Examples:
# bitcoinCli="bitcoin-cli"
# bitcoinCli="bitcoin-cli -rpcuser=username -rpcpassword=password"
bitcoinCli="bitcoin-cli"
#
################################################

set -o errexit # Exit immediately if any command returns a non-zero exit status
# set -o xtrace # Uncomment for debugging

# bitcoinDir default is "/" if empty
bitcoinDir="${bitcoinDir:-/}"

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


# Get data
gbc=$($bitcoinCli getblockcount)
# Block search feature: accept block number as first script argument, optional
if [[ -n "$1" ]]; then
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    gbc=$1
  else
    echo "Error: Input is not a whole number"
    exit 1
  fi
fi
gni=$($bitcoinCli getnetworkinfo)
gnt=$($bitcoinCli getnettotals)
gmi=$($bitcoinCli getmempoolinfo)
gbs=$($bitcoinCli getblockstats $gbc)
# Added "|| true" below because 'grep --count' error exits when count is 0
bip110Count=$($bitcoinCli getpeerinfo |grep --count "REDUCED_DATA?" || true)
# More data
### Linux and Mac OS compatible 'df' command options
if df --output=avail --block-size=1 / >/dev/null 2>&1; then
  diskAvail=$(df --output=avail --block-size=1 "$bitcoinDir" |grep --invert-match "Avail")
else
  # 'df' command options for MAC OS. Suggested by AI.
  # Multiply 4th colum by 1024 to convert KB into bytes
  diskAvail=$(df -k "$bitcoinDir" | tail -n 1 | awk '{printf "%.0f", $4 * 1024}')
fi
systemLoad=$(uptime |grep -E --only-matching "load average.+")
hostName=$(hostname)
minutesSM=$(minutesSinceMined "$gbs")
date=$(date "+%Y-%m-%d %I:%M:%S %p %Z")

# Format output
echo "  $hostName  $date"
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
echo "  block: $gbc  $minutesSM ago"
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
echo ""
bytesPrefix "\"disk_avail\": $diskAvail" "disk_avail" "disk space avail" ""
echo "  $systemLoad"
echo ""
