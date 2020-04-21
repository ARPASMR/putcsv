#!/bin/bash
#
# 2020-01-31 MR & MS
########################################
export https_proxy="http://proxy2:8080"
export http_proxy="http://proxy2:8080"

numsec=3600 # 1 ora 
 ./putcsv_to_rem.sh
while [ 1 ]
do
  if [ $SECONDS -ge $numsec ]
  then
    SECONDS=0
         ./putcsv_to_rem.sh
         STATO=$?
         echo "STATO USCITA SCRIPT ====> "$STATO
         if [ "$STATO" -gt 0 ] # se si sono verificate anomalie esci 
         then
           exit 1
         fi
         sleep $numsec
  fi
done
