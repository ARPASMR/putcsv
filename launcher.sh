#!/bin/bash
#
# 2020-01-31 MR & MS
########################################

numsec=600 # 10 minuti 

while [ 1 ]
do
  if [ $SECONDS -ge $numsec ]
  then
    SECONDS=0
         ./putcsv.sh
         STATO=$?
         echo "STATO USCITA SCRIPT ====> "$STATO
         if [ "$STATO" -gt 0 ] # se si sono verificate anomalie esci 
         then
           exit 1
         fi
         sleep $numsec
  fi
done
