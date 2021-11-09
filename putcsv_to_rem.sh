#!/bin/bash
# <<putcsv_to_rem.sh>>
# crea il file csv con le informazioni sul controllo di qualita' dei dati
# contenute nel DB METEO, lo trasferisce su FTP
# aggiorna opportunamente la tabella DQCinDBUNICO all'interno del DB METEO.
#
# STORIA
# 2010-03-11 CL. versione originale <putcsv_to_ftp.sh>.
# 2015-12-18 MR MS modificato per allineare totalmente le flag col REM2
# 2020-02-03 MR MS modificato per docker
#==============================================================================
FTP=/usr/bin/ftp
TEMP=temp
ARCHIVIO=archivio
CREACSV_R=creaCSVwithDQCinfo.R
R=/usr/bin/Rscript
SED=/bin/sed
MYSQL=/usr/bin/mysql

#------------------------------------------------------------------------------
# [] Pulizia preliminare directory temporanea
rm -f $TEMP/*.csv
# [] Applicativo R che crea il file .csv da trasferire
$R --vanilla $CREACSV_R $TEMP
STATO=$?
echo ""
echo "------------------------------------------"
echo "STATO USCITA DA "$CREACSV_R" ====> "$STATO
echo "------------------------------------------"
echo ""
# [] Copia file
# se si sono verificate anomalie (exit status = 1) allora esci ...
if [ "$STATO" -eq 1 ]
then
  exit 1
else
# ...altrimenti se tutto e' andato benone allora trasferisci
  # ci deve essere un solo file .csv in $TEMP, per cui questo ciclo e' una finta...
  # solo per recuperare il nome del file
  for FILE in $TEMP/*.csv
  do
    NOMEFILE=$FILE
  done
  echo $NOMEFILE
  # numero di record presenti nel file
  NRECORDS=`cat $NOMEFILE | wc -l`
#  echo $NRECORDS
  # data di riferimento per il trasferimento
  DATA=`echo $NOMEFILE | awk -F "_" '{print $NF }' | awk -F "." '{print $1 }'`
#  echo $DATA
  ANNO=${DATA:0:4}
  MESE=${DATA:4:2}
  GIORNO=${DATA:6:2}
  ORA=${DATA:8:2}
  MINUTO=${DATA:10:2}
  SECONDO=${DATA:12:2}
  echo "data di riferimento per il trasferimento = "$ANNO/$MESE/$GIORNO" "$ORA:$MINUTO:$SECONDO
  NOME=`echo $NOMEFILE | awk -F "/" '{print $NF }'`
# echo $NOME
# converione fine linea: UNIX -> DOS
  $SED 's/$'"/`echo \\\r`/" -i $NOMEFILE

############################################
echo "copio file su ftp  "

ncftpput -u $FTP_USR -p $FTP_PWD -t 60 $FTP_SERV $FTP_DIR $NOMEFILE

  STATOcopy=$?
## se si sono verificate anomalie (exit status = 1) allora esci ...
    if [ "$STATOcopy" -ne 0 ]
    then
      echo "ATTENZIONE: copia file non riuscita"
      $MYSQL -u $MYSQL_USR -p$MYSQL_PWD -D $MYSQL_DBNAME -h $MYSQL_HOST -P $MYSQL_PORT -e "insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('$ANNO/$MESE/$GIORNO $ORA:$MINUTO:$SECONDO',-10,$NRECORDS,'$NOME','putcsv_to_rem','`date +%Y/%m/%d" "%H:%M:%S`')"
    else
      echo "SUCCESSO: copia file eseguita con successo "
      $MYSQL -u $MYSQL_USR -p$MYSQL_PWD -D $MYSQL_DBNAME -h $MYSQL_HOST -P $MYSQL_PORT -e "insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('$ANNO/$MESE/$GIORNO $ORA:$MINUTO:$SECONDO',1,$NRECORDS,'$NOME','putcsv_to_rem','`date +%Y/%m/%d" "%H:%M:%S`')"
    fi
fi

# archivia il file nella directory di archivio
mv $NOMEFILE $ARCHIVIO/$NOME

exit 0
