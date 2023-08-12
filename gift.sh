#!/usr/bin/env bash
#
# Tools needed
# 1. lossless-cut for cutting video
# 2. gifski (cargo install gifski)
#
# Steps
# 1. Convert video to 50fps (ffmpeg)
# 2. Extract frames (ffmpeg)
# 3. Convert to gif (gifski)
#
usage() {
      echo "Usage $0 [-i input.mkv] [-o output.gif] [-r fps] [-q 0-100]"
      exit 1
    }

fps=50
quality=100

while getopts ":i:o:r:q:" option; do
  case $option in
    i)
      input="$OPTARG"
      ;;
    o)
      output="$OPTARG"
      ;;
    r)
      fps="$OPTARG"
      ;;
    q)
      quality="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z "${input}" ] || [ -z "${output}" ]; then
  usage
fi

outputfilename="${output%.*}"

workdir="/tmp/workdir-${input}-gif"
workingvideo="$workdir/video.${fps}fps.mkv"

rm -rf "$workdir"
mkdir -p "$workdir"

# Convert to $fps fps
#ffmpeg -i ${input} -filter:v fps=fps=${fps} ${workingvideo}
ffmpeg -i "${input}" -r ${fps} "${workingvideo}"

# Extract frames
#
ffmpeg -i "${workingvideo}" "$workdir/frames.%05d.png"

# Convert to gif
#
gifski -Q ${quality} --fps ${fps} -W 1440 --output "${outputfilename}.q${quality}.${fps}fps.gif" ${workdir}/*png
# Autocreate q90 (which is the gifski default)
gifski -Q 90 --fps ${fps} -W 1440 --output "${outputfilename}.q90.${fps}fps.gif" ${workdir}/*png
