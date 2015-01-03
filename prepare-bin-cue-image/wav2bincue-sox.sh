#!/bin/bash

# author: Michael Junczyk
# info: http://maschinelearning.wordpress.com/2015/01/02/preparing-audio-cd-master-image-for-cd-replication-on-windows/

ROOT_DIR="$PWD"

# directory to be processed
INPUT_DIR="$ROOT_DIR/$1"
if [ -z "$INPUT_DIR" ]; then \
	echo -e "\nPlease specify the relative path to directory with WAV files.\nExiting" >&2
	exit 1>&2;
fi

# output_dir
OUTPUT_DIR="$ROOT_DIR/$2"
mkdir -p "$OUTPUT_DIR"

# processing params
SOX_FLAGS="\-c 2 -e signed-integer -b 16 -r 44100"

# album information SPECIFIED_BY_USER
PERFORMER="Kisiel & Me?How?"
ALBUM_TITLE="Po drugiej stronie srebra"

PERFORMER_DASH=$(echo $PERFORMER | tr ' ' '-' | tr '?' '_')
ALBUM_TITLE_DASH=$(echo $ALBUM_TITLE | tr ' ' '-')

#output_files
OUTPUT_FILENAME="$PERFORMER_DASH"-"$ALBUM_TITLE_DASH-MASTER"
MASTER_BIN_FILENAME="$OUTPUT_FILENAME".bin
MASTER_CUE_FILENAME="$OUTPUT_FILENAME".cue

OUTPUT_BIN="$OUTPUT_DIR"/"$MASTER_BIN_FILENAME"
OUTPUT_CUE="$OUTPUT_DIR"/"$MASTER_CUE_FILENAME"

cd "$INPUT_DIR"

# check availability of audio files
wav_files=$(ls *.wav)
nr_of_files=$(echo -e "$wav_files" | wc -l)

if [ "$nr_of_files" -eq "0" ]; then \
	echo -e "\nNo audio files in the $DIR directory. Exiting" >&2
	exit 2>&2;
fi

echo -e "\nGenerating image for $nr_of_files files:\n$wav_files"

#create temporary directories
TMP_DIR="$ROOT_DIR/tmp"
TEST_DIR="$OUTPUT_DIR/test-wav-file"

mkdir -p "$TMP_DIR" "$TEST_DIR"

cd "$ROOT_DIR"
# prepare silence file to be inserted between tracks on CD (optional)
# set silence duration in seconds
#SILENCE_DURATION=1 
#SILENCE_FILE=tmp/silence.raw
#sox -t raw -c 2 -e signed-integer -b 16 -r 44100 /dev/zero $SILENCE_FILE trim 0 $SILENCE_DURATION

#SILENCE=tmp/silence.raw
#sox -t raw -c 2 -e signed-integer -b 16 -r 44100 /dev/zero $SILENCE trim 0 $DURATION

cd "$INPUT_DIR"

# convert audio to raw stereo, 44.1 kHz / 16 bits files
for file in *.wav; do 
  filename=`basename "$file" .wav`; 
  echo "Converting WAV file: $filename.wav to RAW"; 
  sox "$file" -c 2 -e signed-integer -b 16 -r 44100 "$TMP_DIR/$filename".raw;
done

cd "$ROOT_DIR"

# combine raw files into BIN file
# remove old BIN file
rm -fv "$OUTPUT_BIN"

cd "$TMP_DIR"
for file in *.raw; do 
  filename=`basename "$file" .raw`; 
  echo "Combining RAW file: $filename.raw"; 
  cat "$file" >>  $OUTPUT_BIN ; 
done

cd "$ROOT_DIR"

# Create CUE file
# initialize variables
index=1; decimal=00; minute_seconds=00:00; total_duration=0;

# get BIN file filename
# generate CD-TEXT information
echo -e "PERFORMER $PERFORMER
TITLE $ALBUM_TITLE
FILE $MASTER_BIN_FILENAME BINARY" >"$OUTPUT_CUE"

cd "$INPUT_DIR"
# generate tracks information
for file in *.wav; do 
  title=`basename "$file" .wav | cut -d '-' -f 2`  
  index_pad=$(printf %02d $index)
  duration=$(soxi -D "$file")
  echo "  TRACK $index_pad AUDIO" >> "$OUTPUT_CUE"
  echo "    TITLE \"$title\"" >> "$OUTPUT_CUE"
  echo "    PERFORMER $PERFORMER" >> "$OUTPUT_CUE"
  echo "    INDEX 01 $minute_seconds:$decimal"  >> "$OUTPUT_CUE"
  total_duration=$(echo "$total_duration $duration" | awk '{print $1 + $2}') 
  decimal=$(echo "$total_duration" | cut -d '.' -f 2 | tail -c 3)
  minute_seconds=$(date -d "00:00 $total_duration seconds" +'%M:%S')
  ((index++))
done

# change CUE file encoding to Windows ANSI
iconv -f utf8 -t Windows-1250 "$OUTPUT_CUE" > "$OUTPUT_CUE.windows-1250"
iconv -f utf8 -t utf16 "$OUTPUT_CUE" > "$OUTPUT_CUE.utf16"
#mv "$OUTPUT_CUE.ansi" "$OUTPUT_CUE"

# prepare zip package with CUE/BIN and MD5 sum
TODAY=$(date +%Y%m%d)
ZIP_PACKAGE="$OUTPUT_FILENAME"-$TODAY.zip

cd "$OUTPUT_DIR" && rm -vf "$ZIP_PACKAGE" && \
zip "$ZIP_PACKAGE" "$MASTER_BIN_FILENAME" "$MASTER_CUE_FILENAME" "$MASTER_CUE_FILENAME.windows-1250" "$MASTER_CUE_FILENAME.utf16" && \
md5sum "$ZIP_PACKAGE" > "$ZIP_PACKAGE".md5

cd "$ROOT_DIR"
rm -rf "$TMP_DIR"

# testing
# convert BIN file to WAV file
sox -t raw -e signed-integer -c 2 -b 16 -r 44100 "$OUTPUT_BIN" -t wav -c 2 -e signed-integer -b 16 -r 44100 "$TEST_DIR/$OUTPUT_FILENAME.wav"

echo -e "\nSuccesful completion!\nSee $TEST_DIR for WAV file.\nSee $OUTPUT_DIR for ZIP package with BIN/CUE/MD5 files"
