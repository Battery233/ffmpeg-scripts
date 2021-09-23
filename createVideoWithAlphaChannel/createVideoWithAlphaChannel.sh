#!/bin/bash
##################### Doc #####################
# args
# $1 .zip location
# $2 fps
# $3 bit rate (K/s)
# $4 ffmpeg bin location

# error code
# 0:ok
# 1:not a zip file
# 2:no legit PNG files found
# 3:unsupported OS
# 4:homebrew not found
# 5:option err
# 6:png file does not contain alpha channel (sub shell)
##################### Doc #####################

# -h help menu
while getopts ":h" optname; do
  case "$optname" in
  "h")
    echo "createVideoWithAlphaChannel can convert sequential frames (PNG) with alpha channel into an mp4 video with separated RGB&A views (for Android/IOS)"
    printf 'Args: ./createVideoWithAlphaChannel.sh <.zip which contains the frames> <FPS> <bit rate> <ffmpeg bin location>\n'
    echo "e.g.: ./createVideoWithAlphaChannel.sh demo.zip 25 3000 /usr/local/bin/ffmpeg"
    exit 0
    ;;
  *)
    echo "Wrong options. Try -h"
    exit 5
    ;;
  esac
done

set -e # quit on err
ffmpeg=$4

# OS env setup
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  tmpLocation="/data/ffmpeg/tmp_$(date +%s)"

elif [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v "$ffmpeg" >/dev/null; then
    if ! command -v "brew" >/dev/null; then
      echo "Homebrew required to install ffmpeg!"
      exit 4
    fi
    brew install ffmpeg
    ffmpeg="ffmpeg"
  fi
  if ! command -v "identify" >/dev/null; then
    if ! command -v "brew" >/dev/null; then
      echo "Homebrew required to install imagemagick!"
      exit 4
    fi
    brew install imagemagick
  fi

  tmpLocation="$(pwd)/tmp_$(date +%s)"

elif [[ "$OSTYPE" == "cygwin" ]]; then
  # POSIX compatibility layer and Linux environment emulation for Windows
  echo "require linux-gnu/cygwin env, found $OSTYPE"
  exit 3
elif [[ "$OSTYPE" == "msys" ]]; then
  # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
  echo "require linux-gnu/cygwin env, found $OSTYPE"
  exit 3
elif [[ "$OSTYPE" == "win32" ]]; then
  # I'm not sure this can happen.
  echo "require linux-gnu/cygwin env, found $OSTYPE"
  exit 3
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  echo "require linux-gnu/cygwin env, found $OSTYPE"
  exit 3
else
  echo "require linux-gnu/cygwin env, found $OSTYPE"
  exit 3
fi

# file extraction
if [[ $1 == *".zip" ]]; then
  mkdir -p "$tmpLocation"
  echo "Created dir at $tmpLocation"
  echo "Unzipping file..."
  unzip "$1" -d "$tmpLocation" >/dev/null
else
  echo "Not a zip file"
  exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  rm -rf "$tmpLocation"/__MACOSX
fi

# thread pool
thread_num=8

tmp_fifofile="./$$.fifo"
mkfifo "$tmp_fifofile"
exec 6<>"$tmp_fifofile"

for ((i = 0; i < "$thread_num"; i++)); do
  echo
done >&6
rm $tmp_fifofile

counter=0 # num of PNGs

startProcessingImg=$(date +%s)
echo "Processing img alpha channels..."
for file in "$tmpLocation"/"$(ls "$tmpLocation")"/*.png; do # doing $(ls "$tmpLocation") in case the file path contains non ascii chars
  {
    read -r -u6
    if ! identify -format '%[channels]' "$file" | grep -q 'a'; then
      echo "Image $file does not contain alpha channel"
      echo >&6
      exit 6
    fi

    seq="$(printf "%05d\n" "$counter")"
    mv "$file" "$tmpLocation/$seq.png"
    echo >&6
  } &

  counter=$((counter + 1))
done

wait
exec 6>&- # close fd6

echo Time taken to process img is $(($(date +%s) - startProcessingImg)) seconds.

if [ 0 -eq $counter ]; then
  echo "0 png files found in zip!"
  exit 2
else
  echo "$counter PNG files will be used!"
fi

{
  echo "Creating alpha layer of the video now..."
  $ffmpeg -i "$tmpLocation/%05d.png" -r "$2" -b:v "$3"k -vf "alphaextract,fps=$2" "$tmpLocation/alpha.mov" &>/dev/null
  echo "Creating alpha layer of the video done!"
} &

{
  echo "Creating RGB layer of the video now..."
  $ffmpeg -i "$tmpLocation/%05d.png" -r "$2" -b:v "$3"k -vf "fps=$2" "$tmpLocation/rgb.mov" &>/dev/null
  echo "Creating RGB layer of the video done!"
} &

echo "Waiting for two processes to finish"
wait

echo "Generating result video now..."
$ffmpeg -i "$tmpLocation/alpha.mov" -i "$tmpLocation/rgb.mov" \
  -filter_complex "[0:v]pad=iw*2:ih[int]; [int][1:v]overlay=W/2:0[vid]" \
  -map "[vid]" \
  -c:v libx264 \
  -crf 23 \
  -y \
  "$1.mp4" &>/dev/null

wait
echo "Purging tmp files..."
rm -r "$tmpLocation"

echo "Job done! File:"
echo "$(pwd)/$1.mp4"

exit 0
