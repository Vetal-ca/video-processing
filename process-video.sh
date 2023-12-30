#!/usr/bin/env bash

#set -o errexit
set -o nounset
set -o pipefail

usage() {
  echo "Usage: ${0##*/} -d|dir <dir_with_video_files> -s|--select *.ext -r|--rescale 1920 -i|--deinterlace"
  exit 1
}

OPTS=$(getopt -o s:d:r:i --long select:,dir:,rescale:,deinterlace -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options." >&2
  usage
fi

eval set -- "${OPTS}"

while true; do
  case "$1" in
  -s | --select)
    select="$2"
    shift 2
    ;;
  -d | --dir)
    dir="$2"
    shift 2
    ;;
  -r | --rescale)
    new_width="$2"
    shift 2
    ;;
  -i | --deinterlace)
    deinterlace="1"
    shift
    ;;
  --)
    shift
    break
    ;;
  *) break ;;
  esac
done

if [ -z ${select+set} ]; then
  select="*.mp4"
fi

if [ -z ${dir+set} ]; then
  usage
fi

if [ -z ${new_width+set} ]; then
  rescale=""
else
  # https://trac.ffmpeg.org/wiki/Scaling
  rescale="-vf \"scale='min(${new_width},iw)':-1\" -sws_flags lanczos"
fi

if [ -z ${deinterlace+set} ]; then
  deinterlace_opts=""
else
  echo "Performing deinterlace"
  # https://trac.ffmpeg.org/wiki/Scaling
  deinterlace_opts="-vf \"nnedi=weights=/data/nnedi3_weights.bin\""
fi

batch_temp="batch.sh" && \
image="vetalca/ffmpeg:6.1" && \

uid=$(id -u "$(whoami)") && \
gid=$(id -g "$(whoami)") && \

dest_log="${dir}/compression.log"
if test -f "${dest_log}"; then
  echo "\"${dest_log}\" file exists, executed by accident ?"
  exit 1
fi

read -r -d '' batch_file <<"EOF"
#!/usr/bin/env sh

logfile="./compression.log"
touch ${logfile}
echo touch ${logfile}
for src_file in %%select%%; do
    echo "${src_file}";
    echo "Compressing ${src_file} ..." >> ${logfile}
    name=$(echo "${src_file%.*}")
    dst_file="${name}.h265.mp4"
    echo "Processing \"${src_file}\" => \"${dst_file}\""
    # https://stackoverflow.com/questions/49686244/ffmpeg-too-many-packets-buffered-for-output-stream-01
    ffmpeg -stats -i "${src_file}" \
      -c:v libx265 -crf 22 -c:a aac -b:a 128k  -max_muxing_queue_size 9999 %%rescale%% %%deinterlace_opts%% "${dst_file}"

    echo "Processed: \"${src_file}\" =>  \"${dst_file}\"" >> ${logfile}

done

# self delete

rm -- "$0"
EOF

batch_file="${batch_file//%%select%%/${select}}"
batch_file="${batch_file//%%rescale%%/${rescale}}"
batch_file="${batch_file//%%deinterlace_opts%%/${deinterlace_opts}}"
#batch_file=$(sed "s,%%select%%,${select},g" <<<"${batch_file}")
batch_temp_full="${dir}/${batch_temp}"
echo "${batch_file}" >"${batch_temp_full}"

chmod +x "${batch_temp_full}" && \
docker run -d --volume "${dir}":/tmp -w="/tmp" --rm \
  --user "${uid}":"${gid}" \
  --entrypoint /bin/sh "${image}" --command "./${batch_temp}"

