#!/usr/bin/env bash

set -euo pipefail

  usage() {
    echo "Usage: ${0##*/} -d|dir <dir_with_video_files> -s|--select *.ext -r|--rescale 1920 -i|--deinterlace -v|--vf --deshake <profile> -e|--encoding h265|av1"
    exit 1
  }

function process_video() {
  local this_script
  local this_dir
  local deshake_profiles
  local batch_template

  this_script=$(readlink -f "${0}")
  this_dir=$(dirname "${this_script}")

  deshake_profiles="${this_dir}/deshake.yaml"
  batch_template="${this_dir}/batch_template.sh"


  opts=$(getopt -o s:d:r:ive: --long select:,dir:,rescale:,deinterlace,vf,deshake:,encoding: -n 'parse-options' -- "$@")
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
  local encoding="h265"

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
      shift 2
      ;;
    -e | --encoding)
      encoding="$2"
      shift 2
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

  local codec_v codec_extra codec_a codec_ext
  case "${encoding}" in
  h265)
    codec_v="libx265" codec_extra="-crf 22" codec_a="aac" codec_ext="h265.mp4"
    ;;
  av1)
    # libaom: the vetalca/ffmpeg image is built without libsvtav1
    codec_v="libaom-av1" codec_extra="-crf 30 -b:v 0 -cpu-used 4 -row-mt 1" codec_a="libopus" codec_ext="av1.mkv"
    ;;
  *)
    echo "Unknown encoding '${encoding}', expected h265 or av1" >&2
    usage
    ;;
  esac

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


  batch_file=$(<"${batch_template}")

  batch_file="${batch_file//%%select%%/${select}}"
  batch_file="${batch_file//%%rescale%%/${rescale}}"
  batch_file="${batch_file//%%deinterlace_opts%%/${deinterlace_opts}}"
  batch_file="${batch_file//%%vf_opts%%/${vf_opts}}"
  batch_file="${batch_file//%%deshake%%/${deshake:-0}}"
  batch_file="${batch_file//%%deshake_processing_opts%%/${deshake_processing_opts}}"
  batch_file="${batch_file//%%deshake_detection_opts%%/${deshake_detection_phase}}"
  batch_file="${batch_file//%%codec_v%%/${codec_v}}"
  batch_file="${batch_file//%%codec_extra%%/${codec_extra}}"
  batch_file="${batch_file//%%codec_a%%/${codec_a}}"
  batch_file="${batch_file//%%codec_ext%%/${codec_ext}}"
  batch_temp_full="${dir}/${batch_temp}"
  echo "${batch_file}" >"${batch_temp_full}"
  

  chmod +x "${batch_temp_full}" && \
  docker run -d --volume "${dir}":/tmp -w="/tmp" --rm \
    --user "${uid}":"${gid}" \
    --entrypoint /bin/sh "${image}" --command "./${batch_temp}"
}

process_video "$@"
