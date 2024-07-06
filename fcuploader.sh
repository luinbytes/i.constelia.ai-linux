#!/bin/bash -e

# Configuration
auth="KEY" # Replace with your actual API key
url="https://constelia.ai/api.php"
cmd="upload"
expire="0"  # Set expire time as needed, 0 means file remains public indefinitely

# Temporary files
temp_file="/tmp/screenshot.png"
response_file="/tmp/upload.json"
error_log="/tmp/error.log"
raw_response_file="/tmp/raw_response.txt"
headers_file="/tmp/headers.txt"
body_file="/tmp/body.txt"

# Function to clean up temporary files
cleanup() {
    rm -f $temp_file $response_file $raw_response_file $headers_file $body_file
}

# Take screenshot using Flameshot and save to a temporary file
flameshot gui -r > $temp_file

# Validate the screenshot file type
if [[ $(file --mime-type -b $temp_file) != "image/png" ]]; then
    echo "Invalid file type" | tee -a $error_log
    cleanup
    exit 1
fi

# Upload the screenshot using curl
curl -X POST \
     -F "file=@$temp_file" \
     -F "key=$auth" \
     -F "cmd=$cmd" \
     -F "expire=$expire" \
     -v "$url" \
     -D $headers_file -o $body_file 2>&1 | tee -a $error_log

# Save the raw response to a file
cat $headers_file > $raw_response_file
echo "" >> $raw_response_file
cat $body_file >> $raw_response_file

# Detect the Content-Type header
content_type=$(grep -i "Content-Type" $headers_file | awk '{print tolower($2)}' | tr -d '\r')

# Process the response based on Content-Type
if [[ "$content_type" =~ "application/json" ]]; then
    json_response=$(cat $body_file)
    echo "$json_response" > $response_file
elif [[ "$content_type" =~ "text/plain" ]]; then
    json_response=$(cat $body_file | awk 'BEGIN { in_json=0 } /{.*}/ { in_json=1 } { if (in_json) print }')
    echo "$json_response" > $response_file
else
    notify-send "Error: Unsupported Content-Type ($content_type)" -a "Flameshot"
    echo "Unsupported Content-Type ($content_type)" | tee -a $error_log
    cleanup
    exit 1
fi

# Validate the JSON
if ! jq -e . >/dev/null 2>&1 < $response_file; then
    notify-send "Error: Invalid JSON response." -a "Flameshot"
    echo "Invalid JSON response" | tee -a $error_log
    cleanup
    exit 1
fi

# Extract fields from the JSON response
success=$(jq -r ".success" < $response_file)
image_url=$(jq -r ".url" < $response_file)
error=$(jq -r ".error" < $response_file)

# Check the success status
if [[ "$success" != "true" ]] || [[ "$image_url" == "null" ]]; then
    notify-send "Error: ${error:-Unknown error occurred}" -a "Flameshot"
    echo "Error: ${error:-Unknown error occurred}" | tee -a $error_log
    cleanup
    exit 1
fi

# Copy the URL to the clipboard and notify the user
echo "$image_url" | xclip -sel c
notify-send "Image URL copied to clipboard" -a "Flameshot" -i $temp_file

# Clean up temporary files
cleanup

