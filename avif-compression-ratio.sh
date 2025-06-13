#!/usr/bin/env bash

#  Copyright 2025 CompozIT Developers
#
#  Use of this source code is governed by an MIT-style
#  license that can be found in the LICENSE file or at
#  https://opensource.org/licenses/MIT.
#
#  SPDX-License-Identifier: MIT

# -------------------------------------------------------------------
#  calculate-avif-compression-ratio.sh
#
#  Calculate avif compression ratio for converted images
# -------------------------------------------------------------------

set -euo pipefail

# 1. Parameters / defaults
SEARCH_DIR="html/wp-content/uploads/"
# Set how many top images ratio to display in the report
TOP_N_COUNT=30

# Converts bytes to a human-readable format (KB, MB, GB)
human_readable() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1048576 )); then
        printf "%.2f KB\n" $(echo "scale=2; $bytes / 1024" | bc)
    elif (( bytes < 1073741824 )); then
        printf "%.2f MB\n" $(echo "scale=2; $bytes / 1048576" | bc)
    else
        printf "%.2f GB\n" $(echo "scale=2; $bytes / 1073741824" | bc)
    fi
}

# 2. Basic checks & Dependency Check
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' (basic calculator) is required but not installed."
    echo "Please install it (e.g., 'sudo apt-get install bc' or 'sudo yum install bc')."
    exit 1
fi

if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory '$SEARCH_DIR' not found."
    exit 1
fi

echo "Analyzing AVIF optimization in '$SEARCH_DIR'..."
echo "----------------------------------------------------------------"

# 2. Initialize variables
total_old_size=0
total_new_size=0
pair_count=0
# Declare an array to hold performance data for each file pair
declare -a performance_data

# 3. Find all original images and process only those with an AVIF pair
while IFS= read -r image_file; do
    base_name="${image_file%.*}"
    avif_file="${base_name}.avif"

    if [ -f "$avif_file" ]; then
        old_size=$(stat -c %s "$image_file")
        new_size=$(stat -c %s "$avif_file")

        total_old_size=$((total_old_size + old_size))
        total_new_size=$((total_new_size + new_size))
        pair_count=$((pair_count + 1))

        if (( old_size > 0 )); then
            ratio=$(echo "scale=4; ($old_size - $new_size) / $old_size" | bc)
            # Store ratio, old size, new size, and filename together in one line
            performance_data+=("$ratio $old_size $new_size $image_file")
        fi
    fi
done < <(find "$SEARCH_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \))

# 4. Check if any pairs were found
if (( pair_count == 0 )); then
    echo "No matching image/.avif pairs were found in the directory."
    exit 0
fi

# 5. Calculate Overall Statistics
overall_savings_bytes=$((total_old_size - total_new_size))
overall_optimization_rate=0
if (( total_old_size > 0 )); then
    overall_optimization_rate=$(echo "scale=2; ($overall_savings_bytes * 100) / $total_old_size" | bc)
fi

# 6. Calculate Percentile Statistics
# Create a sorted list of just the ratios by extracting the first column
sorted_ratios=($(printf '%s\n' "${performance_data[@]}" | sort -rn | awk '{print $1}'))

idx_1=$(( (pair_count * 1 / 100) -1 ))
idx_10=$(( (pair_count * 10 / 100) -1 ))
idx_50=$(( (pair_count * 50 / 100) -1 ))
[ $idx_1 -lt 0 ] && idx_1=0
[ $idx_10 -lt 0 ] && idx_10=0
[ $idx_50 -lt 0 ] && idx_50=0

ratio_1=${sorted_ratios[$idx_1]}
ratio_10=${sorted_ratios[$idx_10]}
ratio_50=${sorted_ratios[$idx_50]}

percent_1=$(printf "%.2f" $(echo "scale=2; $ratio_1 * 100" | bc))
percent_10=$(printf "%.2f" $(echo "scale=2; $ratio_10 * 100" | bc))
percent_50=$(printf "%.2f" $(echo "scale=2; $ratio_50 * 100" | bc))

# 7. Print the reports
echo "Analysis based on $pair_count image pairs found."
echo
echo "--- Overall Size Comparison ---"
printf "Total size of original images: %s\n" "$(human_readable $total_old_size)"
printf "Total size of AVIF images:     %s\n" "$(human_readable $total_new_size)"
printf "Total space saved:             %s\n" "$(human_readable $overall_savings_bytes)"
echo "----------------------------------------------------------------"
printf "Overall Optimization Rate:     %.2f%%\n" "$overall_optimization_rate"
echo "----------------------------------------------------------------"
echo
echo "--- Optimization Rate Distribution ---"
printf "50%% Low (Median): The best 50%% of files were optimized by at least %.2f%%\n" "$percent_50"
printf "10%% Low (Top 10%%): The best 10%% of files were optimized by at least %.2f%%\n" "$percent_10"
printf " 1%% Low (Top 1%%):  The best  1%% of files were optimized by at least %.2f%%\n" "$percent_1"
echo "----------------------------------------------------------------"
echo

# 8. Find and display the Top N most compressed images (configurable)
echo "--- Top ${TOP_N_COUNT} Images by Compression Ratio ---"
printf "%-12s | %-12s | %-12s | %s\n" "Reduction" "Original Sz" "AVIF Sz" "File"
printf "%-12s | %-12s | %-12s | %s\n" "------------" "------------" "------------" "----"

# Sort all performance data numerically and in reverse by the first column (the ratio)
# and feed the top N lines (defined by TOP_N_COUNT) into a 'while' loop.
while IFS= read -r line; do
    # Use 'read' to split the line into its component parts.
    # The last variable, 'file_path', will contain the rest of the line,
    # correctly handling filenames with spaces.
    read -r ratio old_sz new_sz file_path <<< "$line"

    # Format data for display
    percent_str=$(printf "%.2f%%" $(echo "scale=2; $ratio * 100" | bc))
    old_sz_hr=$(human_readable "$old_sz")
    new_sz_hr=$(human_readable "$new_sz")

    # Print the formatted table row
    printf "%-12s | %-12s | %-12s | %s\n" "$percent_str" "$old_sz_hr" "$new_sz_hr" "$file_path"

done < <(printf '%s\n' "${performance_data[@]}" | sort -rn | head -n "${TOP_N_COUNT}")
echo "----------------------------------------------------------------"


# -----------------------------------------------------------------------------
# 9. Request confirmation and delete original images with AVIF counterparts
# -----------------------------------------------------------------------------

echo
echo "The analysis found $pair_count original images that have an AVIF counterpart."
echo "The next step will PERMANENTLY DELETE these original files."
echo

# Ask for user confirmation.
# -p: displays a prompt.
# -n 1: reads only one character.
# -r: raw mode (prevents backslash interpretation).
# The response is stored in the default $REPLY variable.
read -p "Are you sure you want to delete these $pair_count files? (y/N) " -n 1 -r
echo # Move to a new line for better formatting.

# Check if the user's reply was 'y' or 'Y'.
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    echo "User confirmed. Proceeding with deletion..."
    deleted_count=0
    
    # Iterate through the performance data array which contains all the necessary file info.
    # This is more efficient than running 'find' again.
    for item in "${performance_data[@]}"; do
        # Use 'read' to easily parse the line.
        # The first three variables are placeholders; the rest of the line goes into 'file_to_delete'.
        read -r _ _ _ file_to_delete <<< "$item"

        # Double-check that the file exists before attempting to delete it.
        if [ -f "$file_to_delete" ]; then
            rm -v "$file_to_delete"
            ((deleted_count++))
        else
            echo "Warning: File not found, skipping: $file_to_delete"
        fi
    done

    echo "----------------------------------------------------------------"
    echo "Deletion complete. $deleted_count files were removed."

else
    echo
    echo "Deletion cancelled by user. No files have been changed."
fi