#!/bin/bash

FILE=$1

LINHA1=`head -n 1 $FILE`

LINHA2=`echo $LINHA1 | sed -e 's/\ /_/g' | sed -e 's/,/\ /g'`

COUNT=1

for i in $LINHA2 ; do
	VALOR=`echo $i | cut -f 1 -d "=" | cut -f 2 -d "\""`

	if [ -z $VALOR ] ; then
		VALOR=ZZZZ
	fi

	if [ $VALOR = "action" ] ; then
		VAL_ACTION=$COUNT
	fi

	if [ $VALOR = "app" ] ; then
		VAL_APP=$COUNT
	fi

	if [ $VALOR = "dstip" ] ; then
		VAL_DSTIP=$COUNT
	fi

	if [ $VALOR = "dstport" ] ; then
		VAL_DSTPORT=$COUNT
	fi

	if [ $VALOR = "srcip" ] ; then
		VAL_SRCIP=$COUNT
	fi

	if [ $VALOR = "srcport" ] ; then
		VAL_SRCPORT=$COUNT
	fi


	COUNT=$((COUNT+1))
done

echo "action : $VAL_ACTION"
echo "app : $VAL_APP"
echo "dstip : $VAL_DSTIP"
echo "dstport : $VAL_DSTPORT"
echo "srcip : $VAL_SRCIP"
echo "srcport : $VAL_SRCPORT"

input="$FILE"
while IFS= read -r line
do
  ACTION=`echo "$line" | cut -f $VAL_ACTION -d ","`
  APP=`echo "$line" | cut -f $VAL_APP -d ","`
  DSTIP=`echo "$line" | cut -f $VAL_DSTIP -d ","`
  DSTPORT=`echo "$line" | cut -f $VAL_DSTPORT -d ","`
  SRCIP=`echo "$line" | cut -f $VAL_SRCIP -d ","`
  SRCPORT=`echo "$line" | cut -f $VAL_SRCPORT -d ","`
  echo "$SRCIP:$SRCPORT:$DSTIP:$DSTPORT:$APP:$ACTION" >> $1.sorted.csv
done < "$input"
