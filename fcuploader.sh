#!/bin/bash -e

# Configuration
constelia_uploader_cmd="/home/lu/Documents/FC/constelia-upload"

# Temporary files
temp_file="/tmp/screenshot.png"
error_log="/tmp/error.log"
upload_output_log="/tmp/upload_output.log"

# Function to clean up temporary files
cleanup() {
    echo "Cleaning up temporary files."
    rm -f $temp_file
}

# Take screenshot using Flameshot and save to a temporary file
echo "Taking a screenshot with Flameshot."
flameshot gui -r > $temp_file

# Validate the screenshot file type
echo "Validating the screenshot file type."
if [[ $(file --mime-type -b $temp_file) != "image/png" ]]; then
    echo "Invalid file type" | tee -a $error_log
    cleanup
    exit 1
fi

# Check if the constelia_upload executable exists and is executable
echo "Checking if the constelia_upload executable exists and is executable."
if [[ ! -x $constelia_uploader_cmd ]]; then
    echo "constelia_upload executable not found or not executable: $constelia_uploader_cmd" | tee -a $error_log
    cleanup
    exit 1
fi

# Upload the screenshot using constelia_upload and capture both stdout and stderr
echo "Uploading the screenshot using constelia_upload."
upload_output=$( "$constelia_uploader_cmd" "$temp_file" 2>&1 | tee -a $error_log $upload_output_log )

# Check if constelia_upload succeeded (assuming it returns a non-zero exit code on failure)
if [[ $? -ne 0 ]]; then
    notify-send "Error: Upload failed." -a "Flameshot"
    echo "Error: Upload failed" | tee -a $error_log
    cleanup
    exit 1
fi

# Extract the URL from the upload output
url=$(grep -o 'https://[^ ]*' "$upload_output_log")

# Check if we found a URL
if [[ -z "$url" ]]; then
    notify-send "Error: No URL found in the upload output." -a "Flameshot"
    echo "Error: No URL found in the upload output" | tee -a $error_log
    cleanup
    exit 1
fi

# Copy the URL to the clipboard and notify the user
echo "$url" | xclip -sel c

# Clean up temporary files
cleanup

exit 0
