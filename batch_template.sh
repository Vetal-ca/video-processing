#!/usr/bin/env sh
#
# NOTE: This is a template, not meant to be run directly.
# It is filled with values (%%...%%) and written to a real batch script.

set -eu

logfile="./compression.log"
touch "${logfile}"
echo "touch ${logfile}"

for src_file in %%select%%; do
  echo "${src_file}"
  echo "Compressing ${src_file} ..." >> "${logfile}"

  name="${src_file%.*}"
  dst_file="${name}.%%codec_ext%%"

  echo "Processing \"${src_file}\" => \"${dst_file}\""

  # named by a hash of the source path, so same-named sources never share transforms
  deshake_transforms="$(printf '%s' "${src_file}" | sha256sum | cut -d' ' -f1 | cut -c1-16).trf"

  if [ "%%deshake%%" = "1" ]; then
    echo "Performing deshake, phase 1" >> "${logfile}"
    ffmpeg \
      -i "${src_file}" \
      -vf "vidstabdetect=%%deshake_detection_opts%%:result=${deshake_transforms}" \
      -f null -
  fi

  echo "Performing deshake, phase 2" >> "${logfile}"

  ffmpeg \
    -stats \
    -i "${src_file}" \
    -c:v %%codec_v%% %%codec_extra%% \
    -c:a %%codec_a%% -b:a 128k \
    -max_muxing_queue_size 9999 \
    %%deinterlace_opts%% \
    %%deshake_processing_opts%% \
    %%rescale%% \
    %%vf_opts%% \
    "${dst_file}"

  if [ -f "${deshake_transforms}" ]; then
    rm -f "${deshake_transforms}"
  fi

  echo "Processed: \"${src_file}\" => \"${dst_file}\"" >> "${logfile}"
done

# Self-delete when run as the generated batch
rm -- "$0"
