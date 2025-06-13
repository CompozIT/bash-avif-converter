#!/usr/bin/env bash

#  Copyright 2025 CompozIT Developers
#
#  Use of this source code is governed by an MIT-style
#  license that can be found in the LICENSE file or at
#  https://opensource.org/licenses/MIT.
#
#  SPDX-License-Identifier: MIT

# -------------------------------------------------------------------
#  purge-wordpress-images.sh
#
#  Builds a list of images to purge based on SQL database dump:
#
#  1. All derivative images (-150x150, -scaled) are automatically
#     marked for purging.
#  2. An original image is only kept if its exact filename is found
#     in the database. Otherwise, it is also marked for purging.
# -------------------------------------------------------------------

set -euo pipefail

# 1. Parameters / defaults
HTML_DIR="${1:-html}"
SQL_DUMP="${2:-wordpress.sql}"
PURGE_FILE="${3:-images_to_purge.txt}"

UPLOADS_DIR="$HTML_DIR/wp-content/uploads"

# 2. Basic checks & Dependency Check
[[ -d "$UPLOADS_DIR" ]] || { echo "ERROR: '$UPLOADS_DIR' not found"; exit 1; }
[[ -f "$SQL_DUMP"    ]] || { echo "ERROR: '$SQL_DUMP' not found";    exit 1; }
command -v rg >/dev/null 2>&1 || { echo "ERROR: ripgrep (rg) is not installed. Please install it to run this optimized script."; exit 1; }

# 3. Setup Temporary Directory and Output File
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT # Clean up temporary files on exit

# Define temporary file paths
ALL_DISK_IMAGE_PATHS="$tmpdir/all_disk_images_paths.txt"
ORIGINAL_IMAGE_PATHS="$tmpdir/original_image_paths.txt"
USED_DB_FILENAMES="$tmpdir/used_db_filenames.txt"

# Ensure the final output file is empty before we start
> "$PURGE_FILE"

# 4. Find and Partition Images
echo "--> (1/4) Finding all image files on disk..."
find "$UPLOADS_DIR" -type f \
     \( -iname '*.jpg'  -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.svg' \) \
     -printf '%P\n' > "$ALL_DISK_IMAGE_PATHS"

total_img=$(wc -l < "$ALL_DISK_IMAGE_PATHS")
[[ "$total_img" -eq 0 ]] && { echo "No pictures were found."; exit 0; }

# The regex finds any path containing '-<numbers>x<numbers>.' or '-scaled.'.
# You need to adapt this regex based on your theme or plugins functions.
echo "--> (2/4) Automatically adding all thumbnails and scaled images to the purge list..."
grep -E -- '-[0-9]+x[0-9]+\.|-scaled\.' "$ALL_DISK_IMAGE_PATHS" > "$PURGE_FILE"

# We use `grep -v` to get every line that DOES NOT match the derivative pattern.
grep -vE -- '-[0-9]+x[0-9]+\.|-scaled\.' "$ALL_DISK_IMAGE_PATHS" > "$ORIGINAL_IMAGE_PATHS"

# 5. Check only Original Images Against the Database
echo "--> (3/4) Checking only original images against the database..."

# First, get a clean list of all filenames referenced in the database.
# rg is ripgrep, a much better and faster implementation of grep
rg --no-line-number --only-matching --ignore-case \
   '[^"'"'"'\/]+\.(jpg|jpeg|png|gif|webp|svg)' \
   "$SQL_DUMP" | sort -u > "$USED_DB_FILENAMES"

# Now, loop through our list of originals and check if they are used.
while IFS= read -r image_path; do
    filename="${image_path##*/}"

    # If the original's filename is NOT in the database's list of used files...
    if ! grep -qxF "$filename" "$USED_DB_FILENAMES"; then
        # ...then it is also purgeable. Append it to the list.
        echo "$image_path" >> "$PURGE_FILE"
    fi
done < "$ORIGINAL_IMAGE_PATHS"

# 6. Report
echo "--> (4/4) Generating final report..."
purgeable_img=$(wc -l < "$PURGE_FILE")
kept_img=$((total_img - purgeable_img))

if [[ "$total_img" -gt 0 ]]; then
    percent_kept=$(awk "BEGIN {printf \"%.2f\", (${kept_img}/${total_img})*100}")
else
    percent_kept="0.00"
fi

echo
echo "✔ List of purgeable pictures has been saved to: $PURGE_FILE"
echo
echo "------------------------------ Summary -------------------------------------"
printf "Total image files on disk   : %d\n"   "$total_img"
printf "Kept image files            : %d\n"   "$kept_img"
printf "Purgeable image files       : %d\n"   "$purgeable_img"
printf "Percentage of files to keep : %s %%\n" "$percent_kept"
echo "----------------------------------------------------------------------------"
echo
echo "1. All thumbnails (-WxH) and scaled versions (-scaled) were automatically marked as purgeable."
echo "2. Original files were marked as purgeable if their filename was not found in the database."
echo
echo "You can now review '$PURGE_FILE' and use it to delete the files, e.g.:"
echo "while read -r file; do rm \"$UPLOADS_DIR/\$file\"; done < \"$PURGE_FILE\""
