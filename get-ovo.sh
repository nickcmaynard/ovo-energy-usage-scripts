#bin/bash

# ISO 8601 dates
START="2021-08-31"
END="2024-12-31"

# Customer account, username and password
ACCOUNT="12345678" # Your account number - find this in your Ovo account information
USERNAME="username"
PASSWORD="password"

# Create a cookie jar
COOKIE_FILE=`mktemp`

# Initial login and save cookies
curl -c $COOKIE_FILE -X POST --json "{\"username\": \"$USERNAME\",\"password\": \"$PASSWORD\",\"rememberMe\": true}" 'https://my.ovoenergy.com/api/v2/auth/login'

# Iterate over the days - credit to https://www.theapproachablegeek.co.uk/blog/ovo-energy-data-extractor/
d=$START
until [[ $d > $END ]]; do 
    echo "$d"
    curl -c $COOKIE_FILE -b $COOKIE_FILE "https://smartpaymapi.ovoenergy.com/usage/api/half-hourly/$ACCOUNT?date=$d" --compressed --output $d.json
    d=$(date -I -d "$d + 1 day")
#sleep 1
done

# Delete the cookie jar
rm $COOKIE_FILE