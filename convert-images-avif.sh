#!/usr/bin/env bash

#  Copyright 2025 CompozIT Developers
#
#  Use of this source code is governed by an MIT-style
#  license that can be found in the LICENSE file or at
#  https://opensource.org/licenses/MIT.
#
#  SPDX-License-Identifier: MIT

# -------------------------------------------------------------------
#  convert-images-avif.sh
#
#  A script to find, resize, and convert images to AVIF, then report
#  on file size savings.
#
#   - Uses slowest speed (0) for maximum file size optimization.
#   - Deletes all pre-existing .avif files for a clean run.
#   - Uses all available CPU threads for encoding.
#   - Displays a single-line progress indicator instead of verbose per-file output.
#
#  Depedencies:
#   1. ImageMagick: To read and resize various image formats.
#   2. libavif (avifenc): The reference AVIF encoder.
# -------------------------------------------------------------------

set -euo pipefail

# 1. Parameters / defaults
# The root directory to search for images.
SEARCH_DIR="html/wp-content/uploads"
# The maximum dimension (width or height) for the output AVIF images.
MAX_DIMENSION=1500
# AVIF Encoding Settings for MAXIMUM compression.
# -q 75: High quality setting (0-100).
# --speed 0: The slowest setting, performs exhaustive analysis for the smallest file size.
# --jobs all: Uses all available CPU cores/threads.
AVIFENC_OPTIONS=(-q 75 --speed 0 --jobs all)

# 2. Basic checks & Dependency Check
if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick ('magick') could not be found. Please install it."
    exit 1
fi
if ! command -v avifenc &> /dev/null; then
    echo "Error: The AVIF encoder ('avifenc') could not be found. Please install libavif-tools."
    exit 1
fi
if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: The specified search directory '$SEARCH_DIR' does not exist."
    exit 1
fi

echo "Starting AVIF conversion process..."
echo "--------------------------------------------------------"
echo "Search Directory: $SEARCH_DIR"
echo "Max Dimension:    $MAX_DIMENSION""px"
echo "AVIF Options:     ${AVIFENC_OPTIONS[*]}"
echo "--------------------------------------------------------"

# 3. Delete all pre-existing .avif files to ensure a fresh run.
echo "Searching for and deleting any pre-existing .avif files..."
# The -print0 and xargs -0 pattern safely handles filenames with spaces.
find "$SEARCH_DIR" -type f -iname "*.avif" -print0 | xargs -0 -r rm -f
echo "Cleanup complete."
echo "--------------------------------------------------------"


# 4. Count total files for the progress indicator
echo "Counting total images to process..."
total_files=$(find "$SEARCH_DIR" -type f \( -iregex '.*\.\(jpg\|jpeg\|png\|webp\)$' \) | wc -l)
echo "$total_files images found."

# Initialize counters
total_original_size=0
total_avif_size=0
converted_count=0
current_file_index=0

# 5. Find all relevant image files and loop through them
find "$SEARCH_DIR" -type f \( -iregex '.*\.\(jpg\|jpeg\|png\|webp\)$' \) -print0 | while IFS= read -r -d '' image_file; do
    
    current_file_index=$((current_file_index + 1))
    output_file="${image_file%.*}.avif"
    temp_file="${output_file}.temp.png"
    
    # Update progress indicator on a single line
    # \r moves cursor to the beginning of the line, \e[K clears the rest of the line
    printf "\r\e[K⚙️ Processing: [ %d / %d ] %s" "$current_file_index" "$total_files" "$image_file"

    original_size=$(stat -c%s "$image_file")
    
    # Ensure temporary file is cleaned up even if script is interrupted
    trap 'rm -f "$temp_file"' EXIT

    # Perform the conversion using a temporary file
    magick "$image_file" -auto-orient -resize "$MAX_DIMENSION""x""$MAX_DIMENSION"'>' "$temp_file"
    
    if avifenc "${AVIFENC_OPTIONS[@]}" "$temp_file" "$output_file" &>/dev/null; then
        # On success, update counters silently
        total_original_size=$((total_original_size + original_size))
        avif_size=$(stat -c%s "$output_file")
        total_avif_size=$((total_avif_size + avif_size))
        converted_count=$((converted_count + 1))
    else
        # On failure, print an error on a new line so it's visible
        echo -e "\n❌ FAILED to convert '$image_file'. Skipping."
    fi

    # Clean up the temporary file
    rm -f "$temp_file"
    trap - EXIT # Clear the trap
done

# Print a final newline to move off the progress bar line
echo ""
echo "-------------------"
echo "🎉 Process Complete"
echo "-------------------"

# 6. Final Report
total_original_mb=$(awk "BEGIN {printf \"%.2f\", $total_original_size/1024/1024}")
total_avif_mb=$(awk "BEGIN {printf \"%.2f\", $total_avif_size/1024/1024}")
total_saved_mb=$(awk "BEGIN {printf \"%.2f\", ($total_original_size - $total_avif_size)/1024/1024}")

if [ "$total_original_size" -gt 0 ]; then
    total_reduction_percent=$(awk "BEGIN {printf \"%.2f\", (($total_original_size - $total_avif_size)/$total_original_size)*100}")
else
    total_reduction_percent="0.00"
fi

echo "Images Converted: $converted_count / $total_files"
echo ""
echo "Total Original Size: $total_original_mb MB"
echo "Total AVIF Size:     $total_avif_mb MB"
echo "Total Space Saved:   $total_saved_mb MB"
echo "Overall Reduction:   $total_reduction_percent%"