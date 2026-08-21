#!/usr/bin/env bash
set -u
#
# Step 3: retile the stacked d-pixel series into fixed-size patches.
# BASE_DIR and INPUT_TIFF are exported by prep_array.job.

: "${INPUT_TIFF:?INPUT_TIFF must be set: the ROI GeoTIFF for this tile}"
: "${BASE_DIR:?BASE_DIR must be set: the per-tile output directory}"

python dpixel_retiler.py \
    --tiff_path "$INPUT_TIFF" \
    --d_pixel_dir "${BASE_DIR}/data_processed" \
    --patch_size 250 \
    --out_dir "${BASE_DIR}/retiled_d_pixel" \
    --num_workers "${PATCH_WORKERS:-16}" \
    --overwrite \
    --block_size 1000
