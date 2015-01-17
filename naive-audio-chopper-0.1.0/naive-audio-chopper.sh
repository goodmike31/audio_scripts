# author: Michał Junczyk
# license: Creative Commons Attribution 3.0 Unported License (CC BY 3.0)

SHELL_SCRIPTS_DIR="/cygdrive/d/engineering-projects/audio-db-tools/scripts/shell"
TODAY=$(date "+%Y%m%d")
ENDP_CORRECT=0.1
OVERLAP=2

if [ "$1" == "test" ]; then
	echo "Test mode"
	input="$SHELL_SCRIPTS_DIR/test-input/audio-test-5min.wav";
	echo "Test input $input"
	output_dir="$SHELL_SCRIPTS_DIR/test-output";
else
	if [ -z "$2" ]; then
		echo "missing input arguments. Usage: $0 <input_file> <output_dir> [ <segment_duration> <startpoint> <endpoint>]"
		exit 1;
	fi
	
	input="$1"
	filename=$(basename $input .wav);
	output_dir="$2/$TODAY-$filename"
fi

if [ ! -e "$input" ]; then
	echo "File does not exist. Exiting..."
	exit 1;
fi

mkdir -p $output_dir;

if [ -z "$3" ]; then
	segment_duration=30
fi

if [ -z "$4" ]; then
	startp=0;
fi

if [ -z "$5" ]; then
	endp=0;
fi

duration=$(sox "$input" -n stat 2>&1 | grep "Length" | tr -d ' ' | cut -d  ':' -f 2);
#echo duration $duration;

startp=0

for i in {1..10}; do
	endp=$(echo "$startp $segment_duration" | awk '{print $1+$2}');
	
	time_left=$(echo "$duration $startp $ENDP_CORRECT" | awk '{print $1-$2-$3}');
	is_full_segment=$(echo "$time_left $segment_duration" | awk '{print $1>=$2}');
	#echo $is_full_segment;
	if [ "$is_full_segment" -eq 1 ]; then 
		echo -e "\n# trim segment #$i"
		sox "$input" "$output_dir/$filename-$i.wav" trim $startp $segment_duration;
	else
		echo -e "\n# trim last segment #$i and exit"
		echo "Duration of last segment: $time_left"
		sox "$input" "$output_dir/$filename-$i.wav" trim $startp $time_left ;
		exit 0;
	fi
	echo "start $startp end $endp"
	startp=$(echo "$endp $OVERLAP" | awk '{print $1-$2}');
done;