#bin/bash

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


# ISO 8601 date defaults
# use gdate to find 1st jan this year if on macOS with coreutils installed
START=$($DATE_CMD -I -d "$($DATE_CMD +%Y)-01-01")
END=$($DATE_CMD -I)

# Read the config from a file if it exists
if [ -f ./config.env ]; then
    source ./config.env
else
    echo "Error: config.env file not found.  Copy config.env.template sideways to config.env and edit"
    exit 1
fi
if [ -z "$ACCOUNT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: USERNAME and PASSWORD must be set in config.env"
    exit 1
fi

# Echo out config
echo "Account & username: $ACCOUNT / $USERNAME"
echo "Period: $START -> $END"

# Create a cookie jar
COOKIE_FILE=`mktemp`
echo "Using cookie file: $COOKIE_FILE"

# Maintain an access token
ACCESS_TOKEN=""
function update_access_token() {
    echo "Refreshing token"
    ACCESS_TOKEN=`curl -s -S --request GET --url https://my.ovoenergy.com/api/v2/auth/token -c $COOKIE_FILE -b $COOKIE_FILE | jq --raw-output '.accessToken.value'`
    # Check the exit code was OK
    if [ $? -ne 0 ] || [ -z "$ACCESS_TOKEN" ]; then
        echo "Error: Failed to retrieve access token."
        exit 1
    fi
}


# Let's get on with it!

# Initial login and save cookies
curl -s -S -c $COOKIE_FILE -X POST --json "{\"username\": \"$USERNAME\",\"password\": \"$PASSWORD\",\"rememberMe\": true}" 'https://my.ovoenergy.com/api/v2/auth/login' -o /dev/null
# Check the exit code was OK
if [ $? -ne 0 ]; then
    echo "Error: Login failed."
    exit 1
fi

# Get initial access token
update_access_token

# Iterate over the days - credit to https://www.theapproachablegeek.co.uk/blog/ovo-energy-data-extractor/
d=$START
until [[ $d > $END ]]; do 
    echo "Fetching data: $d"
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