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

set -o errexit #Exit immediately if any command returns a non-zero exit status
# set -o xtrace #Uncomment for debugging

# bitcoinDir default is "/" if empty
bitcoinDir="${bitcoinDir:-/}"

thousandsSeparator=0
if awk -W version 2>/dev/null |grep --quiet "mawk"; then
  thousandsSeparator=1
fi

# Function bytesPrefix
# Number of arguments: 2
# Arguments: Bitcoin-cli output, The item to match
function bytesPrefix {
  local line text bytes prefix negSign
  line=$(echo "$1" | grep "\"$2\"")
  text="$2"
  bytes=$(echo "$line" | grep -E --only-matching "[0-9]+")
  if echo "$line" | grep --quiet -- "-[0-9]"; then
    negSign="-"
  else
    negSign=""
  fi

  prefix=""
  if [[ $bytes -ge 1000000000 ]]; then
    prefix="G"
    bytes=$(awk -v byte="$bytes" 'BEGIN {print byte/1000000000}')
  elif [[ $bytes -ge 1000000 ]]; then
    prefix="M"
    bytes=$(awk -v byte="$bytes" 'BEGIN {print byte/1000000}')
  elif [[ $bytes -ge 1000 ]]; then
    prefix="K"
    bytes=$(awk -v byte="$bytes" 'BEGIN {print byte/1000}')
  fi

  if [[ $thousandsSeparator -eq 1 ]]; then
    printf "  %s: %s%'.2f %sB\n" "$text" "$negSign" "$bytes" "$prefix"
  else
    printf "  %s: %s%.2f %sB\n" "$text" "$negSign" "$bytes" "$prefix"
  fi
}


# Function minutesSinceMined
# Number of arguments: 1
# Argument: Block stats
function minutesSinceMined {
  local blockTime unixSeconds
  blockTime=$(echo "$1" |grep "\"time\"" |grep -E --only-matching "[0-9]+")
  unixSeconds=$(date +%s)
  awk -v unixSeconds="$unixSeconds" -v blockTime="$blockTime" \
    'BEGIN {printf "%.1f min ago\n", (unixSeconds-blockTime)/60}'
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
  # 'df' command options for MAC OS. Suggested by AI. Untested.
  # Multiply 4th colum by 1024 to convert KB into bytes
  diskAvail=$(df -k "$bitcoinDir" | tail -1 | awk '{printf "%.0f", $4 * 1024}')
  #diskAvail=0
fi
systemLoad=$(uptime |grep -E --only-matching "load average.+")
hostName=$(hostname)
minutesSM=$(minutesSinceMined "$gbs")
date=$(date "+%Y-%m-%d %I:%M:%S %p %Z")

# Format output
echo "  $hostName  $date"
echo "$gni" |grep "connections" |tr -d '",' |sed 's/    //'
echo "  bip110 peers: $bip110Count"
bytesPrefix "$gnt" "totalbytesrecv"
bytesPrefix "$gnt" "totalbytessent"
bytesPrefix "$gnt" "bytes_left_in_cycle"
echo "$gnt" |grep "time_left_in_cycle" |grep -E --only-matching "[0-9]+" \
     |awk '{printf "  time_left_in_cycle: %.2f h\n", $1/60/60}'
echo ""
echo "$gmi" | grep 'size' |tr -d '",' | sed 's/size/mempool tx count/'
bytesPrefix "$gmi" "bytes" | sed 's/B$/vB/'| sed 's/bytes/mempool virtual bytes/'
echo "$gmi" | grep 'total_fee' |tr -d '",' | sed 's/$/ BTC/' \
     | sed 's/total_fee/mempool total_fee/'
bytesPrefix "$gmi" "usage" |sed 's/usage/mempool memory usage/'

echo ""
echo "  block: $gbc  $minutesSM"
bytesPrefix "$gbs" "total_size"
bytesPrefix "$gbs" "total_weight" | sed 's/B$/WU/'
echo "$gbs" | grep 'utxo_increase' | tr -d '",'
bytesPrefix "$gbs" "utxo_size_inc"
bytesPrefix "$gbs" "utxo_size_inc_actual"
echo "$gbs" | grep '"txs"' |tr -d '",'
totalOut=$(echo "$gbs" | grep '"total_out"' |grep -E --only-matching "[0-9]+")
if [[ $thousandsSeparator -eq 1 ]]; then
  awk -v tOut="$totalOut" 'BEGIN {printf "  total_out: %\047.2f BTC\n", tOut/100000000}'
else
  awk -v tOut="$totalOut" 'BEGIN {printf "  total_out: %.2f BTC\n", tOut/100000000}'
fi
echo "$gbs" | grep -E '"avgfeerate"|"minfeerate"|"maxfeerate"' \
     |tr -d '",' | sed 's|$| sat/vB|'
echo "$gbs" | grep --after-context=5 '"feerate_percentiles"' \
     |tr -d '\n"[' |sed 's/: /:/' |sed 's/    / /g'
echo ""
echo ""
bytesPrefix "\"disk space avail\": $diskAvail" "disk space avail"
echo "  $systemLoad"
echo ""
