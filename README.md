# Bash AVIF Converter & Optimizer Toolkit

![Bash Shell](https://img.shields.io/badge/bash-5.2.37-blue)
![ImageMagick](https://img.shields.io/badge/ImageMagick-7.1.1-orange)
![libavif](https://img.shields.io/badge/libavif-1.3.0-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

A suite of powerful Bash scripts you can use to automate the conversion of your WordPress media library to the modern, high-efficiency AVIF format. These tools not only handle the conversion but also provide detailed analytics on compression ratios and help you clean up unreferenced and obsolete images from your server.

![format_image_populaire](https://lafibre.info/images/format/format_image_populaire.webp)

---

## 🚀 Features

-   **Batch Image Conversion**: Recursively finds and converts JPG, PNG, and WebP images to AVIF.
-   **High-Efficiency Encoding**: Utilizes `avifenc` with settings tuned for maximum file size reduction.
-   **Image Resizing**: Automatically resizes images to a maximum dimension before conversion.
-   **Detailed Compression Analysis**: Provides in-depth reports on storage savings, including overall and percentile-based statistics.
-   **Intelligent Image Purging**: Identifies and lists unused or derivative images for safe removal, cross-referencing your WordPress database to protect active content.
-   **Interactive Deletion**: Includes a confirmation step to prevent accidental data loss.

---

## 🏛️ Project Architecture

This toolkit is composed of three core scripts that form a complete workflow for optimizing your WordPress media library.

1.  **`purge-wordpress-images.sh`**: An optional but highly recommended first step. This script intelligently scans your WordPress database dump to identify which images are no longer referenced in your posts or pages. It generates a list of purgeable files, including both unused originals and all derivative sizes (thumbnails), allowing you to reclaim significant server space.
2.  **`convert-images-avif.sh`**: The second step is to convert your existing images to AVIF. This script scans your `wp-content/uploads` directory, resizes images to a safe maximum dimension, and encodes them into AVIF using the best possible compression settings.
3.  **`avif-compression-ratio.sh`**: After conversion, this script analyzes the results. It compares the original image sizes with their new AVIF counterparts and generates a detailed report on the space savings. It also includes an interactive prompt to safely delete the original files, now that they have been replaced by AVIF.

---

## 📜 Scripts in Detail

### `purge-wordpress-images.sh`

A powerful utility for cleaning up a mature WordPress site. It identifies images that are no longer in use by cross-referencing them with a SQL database dump.

**Key Operations:**

-   **Derivative Purging**: Automatically marks all generated thumbnails (e.g., `image-150x150.jpg`) and scaled images (`-scaled`) for deletion, as these can be regenerated by WordPress if needed.
-   **Database Cross-Reference**: For original images, it checks if the filename appears anywhere in the SQL dump. If an image is not found, it's considered unused and added to the purge list.
-   **Safe Output**: Generates a text file (`images_to_purge.txt`) containing the relative paths of all files deemed safe to delete. This allows you to review the list before taking any action.
-   **Clear Instructions**: The script output provides the exact command to use for deleting the files listed in the purge file.

### `convert-images-avif.sh`

This script is the workhorse of the toolkit. It recursively scans a specified directory for common image formats (`.jpg`, `.jpeg`, `.png`, `.webp`) and converts them to AVIF.

**Key Operations:**

-   **Pre-cleanup**: Deletes all existing `.avif` files to ensure a fresh and clean run.
-   **Resizing**: Uses ImageMagick to resize images, ensuring they do not exceed a `MAX_DIMENSION` (default: 1500px) on either axis. This is crucial for web performance.
-   **Encoding**: Employs `avifenc` with `--speed 0` for the slowest, most exhaustive compression, maximizing file size reduction. You can set this parameter up to 10 for faster compression.
-   **Progress Tracking**: Displays a clean, single-line progress indicator showing the current file being processed.
-   **Final Report**: Concludes with a summary of the total number of images converted and the overall storage savings in MB and percentage.

### `avif-compression-ratio.sh`

Once you have your AVIF images, this script provides a deep dive into the efficiency of the conversion.

**Key Operations:**

-   **Pair Analysis**: Scans the directory for original/AVIF image pairs and calculates compression statistics for each.
-   **Overall Statistics**: Reports the total size of original vs. AVIF images and the total space saved.
-   **Percentile Distribution**: Shows the optimization rate for the top 1%, 10%, and 50% of your most compressed files, giving you a clearer picture of the gains.
-   **Top Performers**: Lists the top 30 images with the highest compression ratio. You can also modify this setting to obtain information on the desired number of images.
-   **Interactive Deletion**: After presenting the analysis, it prompts the user to confirm the deletion of the original source images that now have an AVIF version. This is a critical step to reclaim disk space.

---

## 🛠️ Usage Workflow

1.  **Backup Your Site**: Before running any scripts, always create a full backup of your `wp-content/uploads` directory and your WordPress database.

2.  **Purge Unused Images**:
    -   Export your WordPress database to a `.sql` file (e.g., `wordpress.sql`).
    -   Run the purge script:
        ```bash
        ./purge-wordpress-images.sh "html" wordpress.sql
        ```
    -   Review the generated `images_to_purge.txt`.
    -   If you are satisfied with the list, run the provided command to delete the files:
        ```bash
        while read -r file; do rm "html/wp-content/uploads/$file"; done < "images_to_purge.txt"
        ```

3.  **Convert Images**:
    ```bash
    ./convert-images-avif.sh "html/wp-content/uploads"
    ```

3.  **Analyze and Delete Originals**:
    ```bash
    ./avif-compression-ratio.sh "html/wp-content/uploads" 30
    ```
    Review the report and, when prompted, press `y` to delete the original JPG/PNG files that have been successfully converted to AVIF.

---

## ⚙️ Dependencies

-   **Bash**: v4.4 or newer.
-   **ImageMagick**: For reading and resizing images.
-   **libavif (`avifenc`)**: The reference AVIF encoder.
-   **ripgrep (`rg`)**: A high-performance search tool used by `purge-wordpress-images.sh` for fast database scanning.
-   **bc**: A command-line calculator used for floating-point arithmetic in reports.

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 👋🏼 You need help ?

We can help you with your software projects. [Contact Us !](mailto:contact@compozit.fr)