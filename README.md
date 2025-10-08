# OVO usage extraction scripts

This script is intended for once-off extraction of detailed usage data for archival purposes only.  

The OVO APIs are probably not designed for this, but without a better alternative, desperate times call for desperate measures.

## Getting raw JSON extracts

Use the `get-ovo.sh` script to grab raw half-hourly usage data in JSON format between two dates.  

This will output one JSON file per day between `START` and `END`.

To use:
* Copy `config.env.template` to `config.env`, adjusting the values of `START`, `END`, `ACCOUNT`, `USERNAME` and `PASSWORD` appropriately.
* Run `bash get-ovo.sh`


## Converting to CSV

Now you have the extracted daily JSON files, you can convert these to a raw CSV covering the total time period:

Electricity CSV:
```sh
jq '.electricity.data[] | {start:.interval.start,end:.interval.end,consumption:.consumption} | join(",")' -r *.json > electricity.csv
```

Gas CSV:
```sh
jq '.gas.data[] | {start:.interval.start,end:.interval.end,consumption:.consumption} | join(",")' -r *.json > gas.csv
```
