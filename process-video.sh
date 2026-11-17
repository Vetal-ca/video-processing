#!/usr/bin/env bash

set -euo pipefail

  usage() {
    echo "Usage: ${0##*/} -d|dir <dir_with_video_files> -s|--select *.ext -r|--rescale 1920 -i|--deinterlace -v|--vf --deshake <profile>"
    exit 1
  }

function process_video() {
  local this_script
  local this_dir
  local deshake_profiles

  this_script=$(readlink -f "${0}")
  this_dir=$(dirname "${this_script}")

  deshake_profiles="${this_dir}/deshake.yaml"


  opts=$(getopt -o s:d:r:i --long select:,dir:,rescale:,deinterlace,vf,deshake: -n 'parse-options' -- "$@")
  if [ $? != 0 ]; then
    echo "Failed parsing options." >&2
    usage
  fi

  eval set -- "${opts}"

  local select
  local dir
  local new_width
  local deinterlace
  local vf
  local deshake
  local deshake_profile

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
    -v | --vf) # VR undo
      vf="1"
      shift
      ;;
    --deshake)
      deshake="1"
      deshake_profile="$2"
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

  local rescale
  local deinterlace_opts
  local vf_opts

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

    deinterlace_opts="-vf \"nnedi=weights=/data/nnedi3_weights.bin\""
  fi

  if [ -z ${vf+set} ]; then
    vf_opts=""
  else
    echo "Performing VF to normal convert"
    vf_opts="-vf \"crop=iw/2:ih:0:0,lenscorrection=k1=0.18:k2=0.03:i=bilinear,scale=1920:1080\""
  fi

  local deshake_opts deshake_detection_phase deshake_processing_phase
  if [ -z "${deshake_profile+set}" ]; then
    deshake_processing_opts=""
    deshake_detection_phase=""
    deshake_processing_phase=""
  else
    echo "Performing deshake"

    if ! deshake_data=$(yq -o=json "${deshake_profiles}" | jq -e --arg profile "${deshake_profile}" '.profiles[$profile]' 2>/dev/null); then
        echo "Error: Profile '${deshake_profile}' not found" >&2
        exit 1
    fi 
    deshake_detection_phase=$(echo "${deshake_data}" | jq -r ".detection_phase")
    deshake_processing_phase=$(echo "${deshake_data}" | jq -r ".processing_phase")
    deshake_processing_opts="-vf \"vidstabtransform=input=\${deshake_transforms}:${deshake_processing_phase}\""
  fi

  batch_temp="batch.sh" && \
  image="vetalca/ffmpeg:6.1.1" && \

  uid=$(id -u "$(whoami)") && \
  gid=$(id -g "$(whoami)") && \

  dest_log="${dir}/compression.log"
  if test -f "${dest_log}"; then
    echo "\"${dest_log}\" file exists, executed by accident ?"
    exit 1
  fi


read -r -d '' batch_file <<"EOF" || true
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

      deshake_transforms="$(printf '%s' "${src_file}" | sha256sum | cut -d' ' -f1 | cut -c1-16).trf"

      if [ "%%deshake%%" == "1" ]; then
        echo "Performing deshake, phase 1" >> ${logfile}
        ffmpeg -i  "${src_file}" -vf "vidstabdetect=%%deshake_detection_opts%%:result=${deshake_transforms}" -f null -
      fi

      echo "Performing deshake, phase 2" >> ${logfile}
      ffmpeg -stats -i "${src_file}" \
        -c:v libx265 -crf 22 -c:a aac -b:a 128k  -max_muxing_queue_size 9999  %%deinterlace_opts%% %%deshake_processing_opts%% %%rescale%% %%vf_opts%% "${dst_file}"

      if [ -f "${deshake_transforms}" ]; then
        rm -f "${deshake_transforms}"
      fi

      echo "Processed: \"${src_file}\" =>  \"${dst_file}\"" >> ${logfile}

  done

  # self delete

  rm -- "$0"
EOF

  batch_file="${batch_file//%%select%%/${select}}"
  batch_file="${batch_file//%%rescale%%/${rescale}}"
  batch_file="${batch_file//%%deinterlace_opts%%/${deinterlace_opts}}"
  batch_file="${batch_file//%%vf_opts%%/${vf_opts}}"
  batch_file="${batch_file//%%deshake%%/${deshake:-0}}"
  batch_file="${batch_file//%%deshake_processing_opts%%/${deshake_processing_opts}}"
  batch_file="${batch_file//%%deshake_detection_opts%%/${deshake_detection_phase}}"
  #batch_file=$(sed "s,%%select%%,${select},g" <<<"${batch_file}")
  batch_temp_full="${dir}/${batch_temp}"
  echo "${batch_file}" >"${batch_temp_full}"
  

  chmod +x "${batch_temp_full}" && \
  docker run -d --volume "${dir}":/tmp -w="/tmp" --rm \
    --user "${uid}":"${gid}" \
    --entrypoint /bin/sh "${image}" --command "./${batch_temp}"
}

process_video "$@"
