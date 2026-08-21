# TESSERA embeddings for Greenland coastline extraction

This fork holds the TESSERA code exactly as it was run to generate the
per-pixel embedding rasters for AOI1–AOI3 in *Applying Deep Learning and
Advances in Coastal Line Segmentation to Geospatial Data in Greenland*
(Akgül & So). Downstream code — training, coastline vectorisation, and
evaluation — lives in
[greenland-coastline-extraction](https://github.com/TalhaAkgul/greenland-coastline-extraction).

Upstream: [ucam-eo/tessera](https://github.com/ucam-eo/tessera), MIT,
© Frank Feng. Nothing here changes the model or its weights.

## Base commit

Branched from upstream `494a550` (`beta_version_1.0`, 2026-02-13), **not**
from `master`. Upstream `master` has since added `tessera_infer_v2/`, which
this study did not use; branching from it would misrepresent the diff.

## Which pipeline produced the embeddings

The **QAT (int8) path**, using checkpoint
`best_model_fsdp_20250608_220648_QAT.pt`, writing to
`representation_retiled_qat/`.

`tessera_infer/` was used only for its two post-inference utilities,
`stitch_tiled_representation.py` and `convert_npy2tiff.py`, which the QAT
array job calls by path. The float checkpoint
(`best_model_fsdp_20250427_084307.pt`) was tried during setup but is not
what produced the published rasters.

## Running it

Two SLURM array jobs, one grid tile per array task, run in order:

```bash
export CONDA_ENV=/path/to/conda/env
export TESSERA_DATA_ROOT=/path/to/aoi-data
export TILE_LIST_FILE=/path/to/all_tiles_list.txt   # one ROI .tiff per line
export TESSERA_REPO=$PWD

# Build the ROI tiles for an AOI (once per AOI)
python tessera_infer/convert_shp_to_tiff.py AOI2-BB-grid.shp --pixel_size 10

# Steps 1-3: download, stack, retile
cd tessera_preprocessing && sbatch --array=1-N prep_array.job

# Steps 4-6: infer, stitch, convert to GeoTIFF
cd ../tessera_infer_QAT && sbatch --array=1-N inference_array.job
```

Every site-specific value is read from the environment and every required
one uses `${VAR:?}`, so an unset variable aborts with a message rather than
silently resolving to a path that does not exist.

Sentinel-1 download needs Earthdata Login credentials in `~/.netrc` and/or a
bearer token at `~/.edl_bearer_token`. That is upstream's mechanism; no
credentials are stored in this repository.

Output per tile: `stitched_representation.tif`, a 128-band float GeoTIFF at
10 m, tiled 256×256 with LZW compression.

## What changed from upstream

Four commits, in this order:

1. **`dpixel_retiler.py` — clamp patch extraction to source bounds.**
   The read window was not checked against the source array's shape, so
   patches straddling a block edge produced a short slice and either a
   broadcast error or misaligned data. Affects ROI-edge pixels, which for
   this study is where the land–water boundary often falls. This is an
   upstream bug and applies to any ROI, not just ours.

2. **`infer_all_tiles.sh` — per-tile tile lists and logs.**
   GPU work manifests were written to `src/tile_lists/` relative to the
   working directory. Under a SLURM array, concurrent tasks resolved that
   to the same file and overwrote each other between write and read. Now
   anchored under `$OUTPUT_DIR`.

3. **Environment-driven configuration and tiled GeoTIFF output.**
   Upstream's placeholder path constants replaced with environment lookups;
   `convert_npy2tiff.py` given a CLI. Output GeoTIFFs gained tiling and LZW
   — as untiled uncompressed rasters the 128-band outputs are slow to
   window-read downstream and are rejected on Earth Engine ingest.

4. **The SLURM array drivers and AOI tiling script** used for the study.

## Known limitations

- In `tessera_infer/infer_all_tiles.sh` the CPU-worker and `gpu_monitor`
  log paths are still relative to the working directory. This study ran
  GPU-only (`CPU_GPU_SPLIT=0:1`), so those paths were never exercised; they
  carry the same collision hazard as fix (2) if CPU workers are used under
  an array job.
- `YEAR=2017` covers 2017-01-01 to 2017-12-31, since TESSERA embeddings are
  annual by construction. The HED-UNet baseline in the same paper consumes
  a June–September 2017 Sentinel-2 median composite. The two methods
  therefore see different temporal footprints of the same year.
- The AOI grid shapefiles and the embedding rasters themselves are not in
  this repository; they are large, and the GST reference data they are
  aligned to is © Geodatastyrelsen and not redistributable.
