#bin/bash

# ISO 8601 dates
START="2021-08-31"
END="2024-12-31"

# Customer account, username and password
ACCOUNT="12345678" # Your account number - find this in your Ovo account information
USERNAME="username"
PASSWORD="password"

# Iterate through a list of potential date commands and use the first one found
DATE_CANDIDATES=("gdate" "date")
for cmd in "${DATE_CANDIDATES[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        DATE_CMD="$cmd"
        break
    fi
done
if [ -z "$DATE_CMD" ]; then
    echo "Error: No suitable date command found. Please install GNU date (gdate) or ensure date is available."
    exit 1
fi
# Check date supports the -d flag
if ! $DATE_CMD -d "2021-01-01 + 1 day" >/dev/null 2>&1; then
    echo "Error: The date command does not support the -d flag. Please install GNU date (gdate)."
    exit 1
fi

# Check we have jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Please install jq to parse JSON responses."
    exit 1
fi

# Create a cookie jar
COOKIE_FILE=`mktemp`
echo "Using cookie file: $COOKIE_FILE"

# Maintain an access token
ACCESS_TOKEN=""
function update_access_token() {
    echo "Refreshing token"
    ACCESS_TOKEN=`curl -s -S --request GET --url https://my.ovoenergy.com/api/v2/auth/token -c $COOKIE_FILE -b $COOKIE_FILE | jq --raw-output '.accessToken.value'`
}


# Let's get on with it


# Initial login and save cookies
curl -s -S -c $COOKIE_FILE -X POST --json "{\"username\": \"$USERNAME\",\"password\": \"$PASSWORD\",\"rememberMe\": true}" 'https://my.ovoenergy.com/api/v2/auth/login' -o /dev/null

# Get initial access token
update_access_token

# Iterate over the days - credit to https://www.theapproachablegeek.co.uk/blog/ovo-energy-data-extractor/
d=$START
until [[ $d > $END ]]; do 
    echo "$d"
    # curl -c $COOKIE_FILE -b $COOKIE_FILE "https://smartpaymapi.ovoenergy.com/usage/api/half-hourly/$ACCOUNT?date=$d" --compressed --output $d.json
    http_response=$(curl -s -S -w "%{response_code}" -H "Authorization: Bearer $ACCESS_TOKEN" "https://smartpaymapi.ovoenergy.com/usage/api/half-hourly/$ACCOUNT?date=$d" --compressed --output $d.json)
    if [ $http_response != "200" ]; then
        # Refresh token and retry
        update_access_token
    else
        d=$($DATE_CMD -I -d "$d + 1 day")
    fi
#sleep 1
done

# Delete the cookie jar
rm $COOKIE_FILE