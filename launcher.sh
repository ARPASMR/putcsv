#!/bin/bash
#
# 2020-01-31 MR & MS
########################################

numsec=600 # 10 minuti 

# mount della cartella windows del REM
mount -t cifs -o username=$USER_REM,password=$PASSWORD_REM "$SHARE_REM" /mnt

while [ 1 ]
do
  if [ $SECONDS -ge $numsec ]
  then
    SECONDS=0
      #eseguo lo script ma solo se la cartella è montata
      if mountpoint -q /mnt 
      then
         ./putcsv.sh
         STATO=$?
         echo "STATO USCITA SCRIPT ====> "$STATO
         if [ "$STATO" -gt 0 ] # se si sono verificate anomalie esci 
         then
           exit 1
         fi
         sleep $numsec
      else 
         echo "share windows non correttamente montata, rieseguo mount"
         mount -t cifs -o username=$USER_REM,password=$PASSWORD_REM "$SHARE_REM" /mnt
         STATO=$?
         echo "STATO USCITA MOUNT ====> "$STATO
         if [ "$STATO" -gt 0 ] # se si sono verificate anomalie esci 
         then
           exit 1
         fi
      fi
  fi
done
