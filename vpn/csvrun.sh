#!/bin/bash

. ./variaveis.cfg

CSVFILE=$1
CSV_TMP=`$CMD_MKTEMP`

while IFS= read -r line
do
  CSV_USER=`$CMD_ECHO "$line" | $CMD_CUT -f 1 -d "," | $CMD_CUT -f 2 -d "\""`
  CSV_IP=`$CMD_ECHO "$line" | $CMD_CUT -f 2 -d "," | $CMD_CUT -f 2 -d "\""`
  CSV_DATE=`$CMD_ECHO "$line" | $CMD_CUT -f 3 -d "," | $CMD_CUT -f 2 -d "\""`
  $CMD_ECHO $CSV_USER $CSV_IP $CSV_DATE >> $CSV_TMP
  ./$CMD_VPN $CSV_USER $CSV_DATE $CSV_IP >>$CSV_TMP 2>>$CSV_TMP
  $CMD_MAIL $RCPTMAIL -s "VPN $CSV_USER" < $CSV_TMP
  $CMD_RM -f $CSV_TMP
done < "$CSVFILE"
