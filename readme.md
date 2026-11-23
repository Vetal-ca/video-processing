# Video Batch Compressor

This is a small Bash helper that generates and runs a per-directory batch script (inside a Docker `ffmpeg` container) to:

- Re-encode videos to **H.265 (HEVC)** or **AV1**, on the CPU or on an NVIDIA GPU (NVENC)
- Optionally **rescale**, **deinterlace**, **VR-to-normal** convert, and **deshake**
- Log work into `compression.log` in the target directory

The main entrypoint is the Bash script (e.g. `process-video.sh`), which builds a `batch.sh` in the target directory from `batch_template.sh` and runs it inside Docker.

## Requirements

- Bash
- Docker
- `yq` and `jq` (for deshake profiles)
- `vetalca/ffmpeg:9.1` image (pulled automatically on first run, built from `dockerfiles/ffmpeg`)
- For `--gpu`: WSL2 with the Windows NVIDIA driver, NVENC with AV1 needs an RTX 40 series or newer. No NVIDIA Container Toolkit is needed
- `deshake.yaml` next to the main script if you use `--deshake`

## CLI Options

Short and long options are equivalent.

- `-d, --dir <path>`  
  Directory containing the video files to process.  
  **Required.**

- `-s, --select '<pattern>'`  
  Glob pattern of files to process within the directory.  
  Default: `*.mp4`  
  Examples: `"*.mp4"`, `"*.mkv"`.

- `-r, --rescale <width>`  
  Rescale using FFmpeg `scale=min(width,iw):-1` with `lanczos` filter.  
  Example: `-r 1920` (rescale to max width 1920, keep aspect ratio).

- `-i, --deinterlace`  
  Enable deinterlacing using `nnedi=weights=/data/nnedi3_weights.bin`.

- `-v, --vf`  
  Apply VR-to-normal "lens fix" filter chain:  
  `crop=iw/2:ih:0:0,lenscorrection=k1=0.18:k2=0.03:i=bilinear,scale=1920:1080`.

- `--deshake <profile>`  
  Enable two-pass deshake using vidstab.  
  The `<profile>` name is looked up in `deshake.yaml` in the same directory as the script.  
  `deshake.yaml` must define:

  ```yaml
  profiles:
    handheld:
      detection_phase: "shakiness=10:accuracy=15"
      processing_phase: "smoothing=30:zoom=0"
  ```

- `-e, --encoding <h265|av1>`
  Select output codec and container.
  Default: h265.

    - h265
      - Video: libx265 -crf 22
      - Audio: aac -b:a 128k
      - Extension: .h265.mp4

    - av1
      - Video: libsvtav1 -crf 30 -preset 6
      - Audio: libopus -b:a 128k
      - Extension: .av1.mkv

- `-g, --gpu`
  Encode on the NVIDIA GPU: `hevc_nvenc -cq 24` or `av1_nvenc -cq 30`, preset p7, 10-bit.
  Same audio and extensions. Filters (rescale, deinterlace, deshake) still run on the CPU.
  About 7x faster than libx265 and 5x faster than libsvtav1 on an RTX 5060 Ti (1080p).
  The container gets `--device /dev/dxg --volume /usr/lib/wsl:/usr/lib/wsl:ro`.

  Check the GPU is visible:

  ```bash
  docker run --rm --device /dev/dxg --volume /usr/lib/wsl:/usr/lib/wsl:ro --entrypoint /usr/lib/wsl/lib/nvidia-smi vetalca/ffmpeg:9.1
  ```


## Output Files

For each `input.ext` the script produces:

- H.265: `input.h265.mp4`
- AV1: `input.av1.mkv`

A log file is created in the target directory:

- `compression.log`, each processed file is logged there.

If `compression.log` already exists in the directory **before** you run the tool, it will exit to avoid accidental re-runs on the same folder.

## Basic Usage Examples

### 1. Default H.265 re-encode of all `.mp4` in a directory

```bash
./process-video.sh --dir /path/to/videos
```


### 2. Explicit H.265, custom selection

Process only `.mkv` files:

```bash
./process-video.sh --dir /path/to/videos --select "*.mkv" --encoding h265
```

### 3. AV1 high-quality re-encode (time no issue)

```bash
./process-video.sh --dir /path/to/videos --encoding av1
```


### 4. Rescale to 1920 width and encode to H.265

```bash
./process-video.sh --dir /path/to/videos --rescale 1920 --encoding h265
```

### 5. Deinterlace, deshake with profile `handheld`, AV1

```bash
./process-video.sh --dir /path/to/videos --deinterlace --deshake handheld --encoding av1
```

### 6. AV1 on the GPU

```bash
./process-video.sh --dir /path/to/videos --encoding av1 --gpu
```

### 7. VR video to normal perspective, H.265

```bash
./process-video.sh --dir /path/to/vr_videos --vf --encoding h265
```

### How It Works (Short Overview)

1. The main script parses CLI options and validates required parameters.
2. It reads batch_template.sh, replaces %%...%% placeholders with the chosen options (codec, filters, etc.), and writes a generated batch.sh into the target directory.
3. It runs batch.sh inside a Docker container (vetalca/ffmpeg:9.1) with the directory mounted.

`--dir` must be a path the Docker daemon sees. Run the script in WSL itself. Inside build-env, `/projects` is a different host path.
4. batch.sh loops over the selected files, runs ffmpeg, logs progress to compression.log, and deletes itself when done.

batch_template.sh is intentionally kept non-executable; it is a template to copy.
