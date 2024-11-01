#!/bin/bash

# Create a temporary directory to store file hashes
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Function to normalize JSON (removes whitespace differences)
normalize_json() {
    jq -c '.' "$1" 2>/dev/null || echo "INVALID_JSON"
}

# Function to check if file is empty or invalid JSON
is_valid_json() {
    local content
    content=$(jq '.' "$1" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$content" ] || [ "$content" == "null" ] || [ "$content" == "{}" ]; then
        return 1
    fi
    return 0
}

# Function to remove empty directories recursively
clean_empty_dirs() {
    echo "Cleaning up empty directories..."
    while true; do
        # Find empty directories and delete them
        empty_dirs=$(find . -type d -empty -not -path "*/\.*")
        if [ -z "$empty_dirs" ]; then
            break
        fi
        echo "$empty_dirs" | while read -r dir; do
            echo "Removing empty directory: $dir"
            rmdir "$dir"
        done
    done
}

echo "Scanning for duplicate and empty JSON files..."

# Find all JSON files
find . -type f -name "*.json" | while read -r file; do
    # Check if file is empty or invalid JSON
    if ! is_valid_json "$file"; then
        echo "Removing empty or invalid JSON file: $file"
        rm "$file"
        continue
    fi

    # Generate normalized content hash
    normalized_content=$(normalize_json "$file")
    if [ "$normalized_content" == "INVALID_JSON" ]; then
        echo "Skipping invalid JSON file: $file"
        continue
    fi

    content_hash=$(echo "$normalized_content" | sha256sum | cut -d' ' -f1)
    hash_file="$temp_dir/$content_hash"

    # If we've seen this hash before, it's a duplicate
    if [ -f "$hash_file" ]; then
        original_file=$(cat "$hash_file")
        echo "Found duplicate:"
        echo "  Original: $original_file"
        echo "  Duplicate: $file (removing)"
        rm "$file"
    else
        # First time seeing this hash
        echo "$file" > "$hash_file"
    fi
done

# Clean up empty directories after processing files
clean_empty_dirs

echo "Finished processing files and cleaning up directories."
