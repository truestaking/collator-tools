#!/bin/bash

TMP_FILE=$(date +%s | md5sum | grep -Eo [0-9a-z]{17})

if ! which bc 2>/dev/null
    then
        echo "please install bc"
        exit;
fi
if ! which jq 2>/dev/null
    then
        echo "please install jq"
        exit;
fi

if ! echo $1 | grep -q [0-9]
then
	echo "usage: moonbeam_round_success.sh <round> "
	exit;
fi

get_author() {
HEX=$(echo "obase=16; $BLOCK" | bc)
DATA="{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"0x$HEX\", true],\"id\":1}"
AUTHOR=$(curl --silent -X POST --data  "$DATA" --header 'Content-Type: application/json' localhost:9933 | jq '.result.author' )
}

ROUND=$1
ROUND_INC=$(($ROUND - 278))
BLOCK_ADJ=$((1800 * $ROUND_INC))
MIN_BLOCK=$((496200 + BLOCK_ADJ))
MAX_BLOCK=$(($MIN_BLOCK + 1799))
BOOK_END=$(($MAX_BLOCK + 1))

echo "determining timestamps and fetching logs from journalctl"
START=$(journalctl -u moonbeam | grep -v Relaychain | grep -m 1 "Imported \#$MIN_BLOCK" | grep -Eo "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}")
END=$(journalctl -u moonbeam --since "$START" | grep -v Relaychain | grep -m 1 "Imported \#$BOOK_END" | grep -Eo "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}")
journalctl -u moonbeam --since "$START" --until "$END" | grep -v Relaychain > $TMP_FILE

echo "Round $ROUND begins with block $MIN_BLOCK at $START and ends with block $MAX_BLOCK at $END"
MINE=0
TOTAL=0

declare -A COLLATOR_PRIMARY  #array for primary slots
declare -A COLLATOR_SECONDARY #array for secondary slots
declare -A COLLATOR_SUCCESS #array for block success
COLLATORS=($(cat $TMP_FILE | grep Eligible | grep -Eo [0-9a-z]{42} | sort -u ))

#initialze arrays
for collator in ${COLLATORS[@]}
do
	COLLATOR_PRIMARY[$collator]=0
	COLLATOR_SECONDARY[$collator]=0
	COLLATOR_SUCCESS[$collator]=0
done

#get primary chances
for ((c=$MIN_BLOCK; c<=$MAX_BLOCK; c++))
do

#comment to disable display progress on the console
    echo -ne "$c"'\r'

	tmp=$(cat $TMP_FILE | grep 'Imported\|Eligible' | grep -B1 "Imported \#$c" | grep -v Imported | head -n 1 | grep -Eo [0-9a-z]{42})
	(( COLLATOR_PRIMARY[$tmp]++ ))
# get secondary chances right here (easy to exclude the primary opportunities)
	for i in `cat $TMP_FILE | grep 'Imported\|Eligible' | grep -B1 "Imported \#$c" | grep -v Imported | grep -v $tmp | grep -Eo [0-9a-z]{42}`; do
		(( COLLATOR_SECONDARY[$i]++ ))
	done
    BLOCK=$c
	get_author
	(( COLLATOR_SUCCESS[$AUTHOR]++ ))
done
echo "Collator, success rate, primary chances, total success"
for collator in ${COLLATORS[@]}
do
    P_CHANCES=${COLLATOR_PRIMARY[$collator]}
    S_CHANCES=${COLLATOR_SECONDARY[$collator]}
    HITS=${COLLATOR_SUCCESS[$collator]}
    SUCCESS=$(echo "scale=2;($HITS / $P_CHANCES)*100" | bc | cut -f 1 -d ".")

    echo "$collator,$SUCCESS%,$P_CHANCES,$HITS"
done
rm -f $TMP_FILE
