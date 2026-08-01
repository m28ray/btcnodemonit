# btcnodemonit
A bash script that shows bitcoin node stats and block stats.

![Screenshot](/screenshot.png)

## How to use

Show node stats and recent block stats then exit `./btcnodemonit.sh` 

Show node stats and given block stats then exit `./btcnodemonit.sh [blockNumber]` \
`./btcnodemonit.sh 912345`


## First steps
Make file executable `chmod u+x btcnodemonit.sh`

**Set user defined variables**

*bitcoinDir*

The filesystem (Example: /dev/sdb) or mount point (Example: /mnt/data)
of the bitcoin directory. If left blank the default is /.
Used by 'df' command to show free disk space.

*bitcoinCli*

The bitcoin-cli command and optional arguments.

## RPC Whitelist
The script sends these rpc commands:

getblockcount getnetworkinfo getnettotals getmempoolinfo getblockstats getpeerinfo


