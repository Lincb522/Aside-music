#!/bin/bash
set -e

# Project paths
ENV_FILE=".env"
INFO_PLIST="Sources/AuroraMusic/Info.plist"

# Check if .env file exists
if [ -f "$ENV_FILE" ]; then
    echo "Found .env file, injecting variables..."
    
    # Read .env file line by line
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip comments and empty lines
        [[ $key =~ ^#.*$ ]] && continue
        [[ -z $key ]] && continue
        
        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        if [ -n "$key" ] && [ -n "$value" ]; then
            echo "Injecting $key into Info.plist..."
            
            # Use PlistBuddy to add or set the value
            # Try to delete first to avoid "Entry Already Exists" error, ignoring failure
            /usr/libexec/PlistBuddy -c "Delete :$key" "$INFO_PLIST" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Add :$key string $value" "$INFO_PLIST"
        fi
    done < "$ENV_FILE"
    
    echo "Injection complete."
else
    echo "No .env file found. Skipping injection."
fi
