## First steps
**Make the scripts executable** 
```
chmod +x btcnodemonit.sh
chmod +x json-files-btcnodemonit.sh
chmod +x peers-jsonfiles.sh
```
## Script 1: btcnodemonit.sh
This is the only script that queries the Bitcoin node directly, and is run on the Bitcoin node computer.

![Screenshot](/Screenshot-light.png)

### How to use

Show node stats and recent block stats then exit: `./btcnodemonit.sh` 

Show node stats and given block stats then exit: `./btcnodemonit.sh [blockNumber]` \
`./btcnodemonit.sh 912345`


**User defined variables**

<ins>bitcoinDir<ins>

If left blank the default is "/". Used by `df` command to show free disk space.

<ins>bitcoinCli<ins>

The `bitcoin-cli` command and optional arguments. The default value is `bitcoin-cli` without arguments.

### RPC Whitelist
The script sends these RPC commands:

`getblockcount` `getnetworkinfo` `getnettotals` `getmempoolinfo` `getblockstats` `getpeerinfo`


## Script 2: json-files-btcnodemonit.sh
This script reads data from **.json files**, which you must create. The output is similar to Script 1, but without system load and free disk space. The goal is to isolate the node from the reporting tool.

### How to use
Place the script in the same directory as the .json files, or provide the path to the directory containing the .json files as an argument after the script name.

### Creating .json files
```
mkdir jsonDir
bitcoin-cli getblockcount > jsonDir/getblockcount.json
bitcoin-cli getnetworkinfo > jsonDir/getnetworkinfo.json
bitcoin-cli getnettotals > jsonDir/getnettotals.json
bitcoin-cli getmempoolinfo > jsonDir/getmempoolinfo.json
bitcoin-cli getblockstats $(< jsonDir/getblockcount.json) > jsonDir/getblockstats.json
bitcoin-cli getpeerinfo > jsonDir/getpeerinfo.json
```

Next you must copy the json files to the computer where you will run the script. 
Skip if you will run the script on the Bitcoin node computer.
This can be automated. Below is a basic example.
```
cd my-json-scripts
scp user@nodeip:jsonDir/*.json .
./json-files-btcnodemonit.sh
```

## Script 3: peers-jsonfiles.sh
This script shows the list of peers with the following columns.

`"Address" "In/Out" "Bytes Sent" "Bytes Recv" "Connection Time" "Subver"`

It requires the **jq** program to be installed. The script is useful to identify bandwidth abusers if you are tunneling through a paid VPS or your internet bandwidth is metered.

### How to use
Place the script in the same directory as the .json files.

### Creating .json file
```
mkdir jsonDir
bitcoin-cli getpeerinfo > jsonDir/getpeerinfo.json
```

Next you must copy the getpeerinfo.json file to the computer where you will run the script. 
Skip if you will run the script on the Bitcoin node computer.
This can be automated. Below is a basic example.
```
cd my-json-scripts
scp user@nodeip:jsonDir/getpeerinfo.json .
./peers-jsonfiles.sh
```

