# btcnodemonit
A bash script that shows bitcoin node stats and block stats.

![Screenshot](/screenshot.png)

## How to use

Show node stats and recent block stats then exit `./btcnodemonit.sh` 

Show node stats and given block stats then exit `./btcnodemonit.sh [blockNumber]` \
`./btcnodemonit.sh 912345`


## First steps
**Make file executable** 
```
chmod u+x btcnodemonit.sh
```

**Set user defined variables**

<ins>bitcoinDir<ins>

The filesystem (Example: /dev/sdb) or mount point (Example: /mnt/data)
of the bitcoin directory. If left blank the default is /.
Used by 'df' command to show free disk space.

<ins>bitcoinCli<ins>

The `bitcoin-cli` command and optional arguments.

## RPC Whitelist
The script sends these RPC commands:

`getblockcount` `getnetworkinfo` `getnettotals` `getmempoolinfo` `getblockstats` `getpeerinfo`

## Automate with Crontab
Run the script every 5 minutes and save the output to a file. \
*Prerequisite: the crontab user has execute permission on the script and write permission on the output directory.*

```
*/5 * * * * /path/to/btcnodemonit.sh > /var/www/html/btcnodemonit-out.txt 2>&1
```
## json-files-btcnodemonit.sh
This script reads data from **.json files** rather than querying a bitcoin node. The goal is to isolate the node from the reporting tool.

**How to use** \
Place the script in the same directory as the .json files, or provide the path to the directory containing the .json files as an argument after the script name.

**Files** \
getblockcount.json \
getnetworkinfo.json \
getnettotals.json \
getmempoolinfo.json \
getblockstats.json \
getpeerinfo.json
