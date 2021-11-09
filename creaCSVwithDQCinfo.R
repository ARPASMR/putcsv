#==============================================================================
#   << creaCSVwithDQCinfo.R >>
#
# Crea il file csv con le info provenienti dal controllo della qualita' dei 
# dati da trasferire nel DBunico
#
# STORIA
# 25/02/2010     CL. codice originale
# 18/12/2015     MR e MS adeguamento all'allineamento DBmeteo / nuovo REM
# 01/04/2020     MR e MS dockerizzazione 
#==============================================================================


library(DBI)
library(RMySQL)

neverstop<-function(){
  cat("EE..ERRORE durante l'esecuzione dello script!! Messaggio d'Errore prodotto:\n")
  quit()
}
options(show.error.messages=TRUE,error=neverstop)

#--------------------------------------------------------------------------
input_ext <- commandArgs()
percorso <- input_ext[7]
datafile<-toString(format(Sys.time(), "%Y%m%d%H%M%S"))
YYYY<-substring(datafile,1,4)
MMM <-substring(datafile,5,6)
DD  <-substring(datafile,7,8)
hh  <-substring(datafile,9,10)
mm  <-substring(datafile,11,12)
DATA_ACT<-paste(YYYY,"-",MMM,"-",DD," ",hh,":",mm,sep="")
file_out<-paste(percorso,'/dqc_feedback_',datafile,'.csv',sep='')
#validatori<-c("MR","EB","US","LC","MS","CHR","PPA","SDP","MCI","MIC","GC","SGR")
adqc<-c("aggior_ftp","aggiornamento_f","DMA-DV.R","DMA-PA.R","DMA-PP.R","DMA-RG.R","DMA-RN.R","DMA-T.R","DMA-UR.R","DMA-VV.R")
# log info
cat("CREA CSV files CON LE info su Data Quality Control ", date()," \n\n")
print(paste(" data attuale = ",DATA_ACT))
print(paste("                      riga di comando = ",input_ext,sep=""))
print(paste(" percorso dove salvare file di output = ",percorso,sep=""))
print(paste("                       file di output = ",file_out,sep=""))
#___________________________________________________
#    COLLEGAMENTO AL DB
#___________________________________________________
cat("collegamento al DB...")
#definisco driver
drv<-dbDriver("MySQL")
conn<-try(dbConnect(drv, user=as.character(Sys.getenv("MYSQL_USR")), password=as.character(Sys.getenv("MYSQL_PWD")), dbname=as.character(Sys.getenv("MYSQL_DBNAME")), host=as.character(Sys.getenv("MYSQL_HOST")),port=as.numeric(Sys.getenv("MYSQL_PORT")) ))
#____________________________________________________________
# Richiedi al DB elenco validatori 
#____________________________________________________________
q <- try(dbGetQuery(conn, "select distinct(Acronimo) from Utenti where LivelloUtente in ('amministratore','gestoreDati');"),silent=TRUE)
# se la richiesta fallisce allora esci con codice 1
if (inherits(q,"try-error")) {
  print("ERRORE: impossibile eseguire correttamente la query di estrazione elenco utenti")
}
validatori<-q$Acronimo
print(validatori)
#____________________________________________________________
# Richiedi al DB ultima data e ora di esportazione (DATA_INI)
#____________________________________________________________
query<-paste("select max(DataInvio) from DQCinDBUNICO_invio where StatoInvio=1",sep="")
#cat ( " query > ", query," \n")
q <- try(dbGetQuery(conn, query),silent=TRUE)
# se la richiesta fallisce allora esci con codice 1
if (inherits(q,"try-error")) {
  print("ERRORE: impossibile eseguire correttamente la query seguente:")
  print(query)
  print("Messaggio d'errore prodotto:")
  print(paste(q,"\n"))
  # inserisci codice -1 nella tabella DQCinDBUNICO_invio
  print("inserimento di codice StatoInvio=-1 in DQCinDBUNICO_invio")
  insert<-paste("insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('",
                DATA_ACT,"',-1,0,'nessuno','creaCSVwithDQCinfo.R','",
                toString(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),"')",sep="")
     esecuzione <- try(dbGetQuery(conn, insert),silent=TRUE)
       if (inherits(esecuzione,"try-error")) {
        print("ERRORE: impossibile eseguire correttamente la query seguente:")
        print(insert)
        print("chiudo DB")
        dbDisconnect(conn)
        rm(conn)
        dbUnloadDriver(drv)
        print("Uscita con codice d'errore = 1")
        quit(status=1)
      }
  print("chiudo DB")
  dbDisconnect(conn)
  rm(conn)
  dbUnloadDriver(drv)
  print("Uscita con codice d'errore = 1")
  quit(status=1)
}
# se la richiesta genera 0 elementi, ovvero non si e' mai esportato nulla, allora...
lung_q<-length(q[1][!is.na(q)])
if (lung_q!=1) {
  print("ERRORE: tabella DQCinDBUNICO_invio vuota?!?")
  # inserisci codice -2 nella tabella DQCinDBUNICO_invio
  print("inserimento di codice StatoInvio=-2 in DQCinDBUNICO_invio")
  insert<-paste("insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('",
                DATA_ACT,"',-2,0,'nessuno','creaCSVwithDQCinfo.R','",
                toString(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),"')",sep="")
     esecuzione <- try(dbGetQuery(conn, insert),silent=TRUE)
       if (inherits(esecuzione,"try-error")) {
        print("ERRORE: impossibile eseguire correttamente la query seguente:")
        print(insert)
        print("chiudo DB")
        dbDisconnect(conn)
        rm(conn)
        dbUnloadDriver(drv)
        print("Uscita con codice d'errore = 1")
        quit(status=1)
      }
  print(" in tabella DQCinDBUNICO_invio non sono registrati record, quindi data ultimo invio non acquisita.")
} else {
  DATA_INI<-q[1]
#  DATA_INI<-'2012-05-11 07:30'
  print(paste("Ultima marca temporale per cui l'applicativo e' stato eseguito con successo = ",DATA_INI))
  print(paste("Per cui si considereranno solo record che presentano variazioni posteriori a ",DATA_INI))
}
# controlli fra DATA_ACT e DATA_INI
#________________________________________________________
# richiedi al DB tutti i record da inserire nel .csv 
# ovvero i record in DQCinDBunico che appartengono alle reti INM e Aria 
# e che siano appartenenti alle tipologie di competenza del meteo
# e che siano misure con marca temporale di almeno 5 ore prima per tempi passaggio staging-consolidata nel rem
#________________________________________________________
    query<-paste("select DQCinDBUNICO_dati.IDsensore, DQCinDBUNICO_dati.Data_e_ora, DQCinDBUNICO_dati.Misura, DQCinDBUNICO_dati.Flag_manuale_DBunico, DQCinDBUNICO_dati.Flag_manuale, DQCinDBUNICO_dati.Flag_automatica,DQCinDBUNICO_dati.Autore from DQCinDBUNICO_dati,A_Sensori,A_Stazioni where DQCinDBUNICO_dati.IDsensore=A_Sensori.IDsensore and A_Sensori.IDstazione=A_Stazioni.IDstazione and  DQCinDBUNICO_dati.Misura is not NULL and  DQCinDBUNICO_dati.Flag_manuale_DBunico not in (1,2) and A_Stazioni.IDrete in (1,4) and A_Sensori.NOMEtipologia in ('T','UR','PA','VV','VVP','VVS','DV','DVP','DVS','RG','RN') and DQCinDBUNICO_dati.Data_e_ora < DATE_SUB(NOW(), INTERVAL 5 HOUR) ",sep="")
    cat ( " query > ", query," \n")
    q <- try(dbGetQuery(conn, query),silent=TRUE)
#   se la richiesta fallisce allora esci con codice 1
    if (inherits(q,"try-error")) {
      print("ERRORE: impossibile eseguire correttamente la query seguente:")
      print(query)
      print("Messaggio d'errore prodotto:")
      print(paste(q,"\n"))
      # inserisci codice -3 nella tabella DQCinDBUNICO_invio
      print("inserimento di codice StatoInvio=-3 in DQCinDBUNICO_invio")
      insert<-paste("insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('",
                    DATA_ACT,"',-3,0,'nessuno','creaCSVwithDQCinfo.R','",
                    toString(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),"')",sep="")
      esecuzione <- try(dbGetQuery(conn, insert),silent=TRUE)
       if (inherits(esecuzione,"try-error")) {
        print("ERRORE: impossibile eseguire correttamente la query seguente:")
        print(insert)
        print("chiudo DB")
        dbDisconnect(conn)
        rm(conn)
        dbUnloadDriver(drv)
        print("Uscita con codice d'errore = 1")
        quit(status=1)
      }
      print("chiudo DB")
      dbDisconnect(conn)
      rm(conn)
      dbUnloadDriver(drv)
      print("Uscita con codice d'errore = 1")
      quit(status=1)
    }
#    print(q)
############################# 
#
    flag_delete <- 0  # sarà posta uguale a uno su fallimento della query di delete da DQCinDBUNICO_dati
    print("lunghezza ciclo")
    print(length(q$IDsensore)) 
    if (length(q$IDsensore)!=0) {
     ii<-1
     while(ii<(length(q$IDsensore)+1)){
      flag_rem2 <- NULL
      #temp# semaforo <- 0
      if(q$Autore[ii] %in% validatori){ # CASO IN CUI CAMBIA LA FLAG_MANUALE  
       #
       # casi che non devono verificarsi 
       if(q$Flag_manuale[ii]=="M") cat("ATTENZIONE, validatore assegna flag manuale Missing!! \n")
       if(q$Flag_automatica[ii]=="F" && (q$Flag_manuale_DBunico[ii] %in% c(-1,0,1,2))) cat("ATTENZIONE, se cambia la flag manuale  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," sono stati incoerenti!! \n")
       if(q$Flag_automatica[ii]=="P" && q$Flag_manuale_DBunico[ii]==5 ) cat("ATTENZIONE, se cambia la flag manuale  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," sono stati incoerenti!! \n")
       #
       # casi da inserire nel csv 
       if(q$Flag_manuale[ii]=="G" && q$Flag_automatica[ii]=="F") flag_rem2 = 10200
       if(q$Flag_manuale[ii]=="E" && q$Flag_automatica[ii]=="F") flag_rem2 = -10200
       if(q$Flag_manuale[ii]=="G" && q$Flag_automatica[ii]=="P") flag_rem2 = 10100
       if(q$Flag_manuale[ii]=="E" && q$Flag_automatica[ii]=="P") flag_rem2 = -10100
      #
      }else if(q$Autore[ii] %in% adqc){  # CASO IN CUI CAMBIA LA FLAG_AUTOMATICA
       # casi che non devono verificarsi 
       if(q$Flag_manuale[ii]=="G" && q$Flag_automatica[ii]=="F" && q$Flag_manuale_DBunico[ii] %in% c(-1,0,1,2,5,100,101,102)) cat("ATTENZIONE, se cambia la flag automatica  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," e ", q$Flag_manuale[ii]," sono stati incoerenti!! \n")
       if(q$Flag_manuale[ii]=="M" && q$Flag_automatica[ii]=="F" && q$Flag_manuale_DBunico[ii] %in% c(-102,-101,-100,100,101,102)) cat("ATTENZIONE, se cambia la flag automatica  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," e ", q$Flag_manuale[ii]," sono stati incoerenti!! \n")
       if(q$Flag_manuale[ii]=="E" && q$Flag_automatica[ii]=="F" && q$Flag_manuale_DBunico[ii] %in% c(-102,-101,-100,-1,0,1,2,5)) cat("ATTENZIONE, se cambia la flag automatica  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," e ", q$Flag_manuale[ii]," sono stati incoerenti!! \n" )
       if(q$Flag_manuale[ii]=="G" && q$Flag_automatica[ii]=="P" && q$Flag_manuale_DBunico[ii] %in% c(-1,0,1,2,5,100,101,102)) cat("ATTENZIONE, se cambia la flag automatica  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," e ", q$Flag_manuale[ii]," sono stati incoerenti!! \n")
       if(q$Flag_manuale[ii]=="M" && q$Flag_automatica[ii]=="P" && q$Flag_manuale_DBunico[ii] %in% c(-102,-101,-100,100,101,102)) cat("ATTENZIONE, se cambia la flag automatica  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," e ", q$Flag_manuale[ii]," sono stati incoerenti!! \n")
       if(q$Flag_manuale[ii]=="E" && q$Flag_automatica[ii]=="P" && q$Flag_manuale_DBunico[ii] %in% c(-102,-101,-100,-1,0,1,2,5)) cat("ATTENZIONE, se cambia la flag automatica  ",q$Flag_automatica[ii]," e ", q$Flag_manuale_DBunico[ii]," e ", q$Flag_manuale[ii]," sono stati incoerenti!! \n")
       #
       # casi da inserire nel csv 
       if(q$Flag_manuale[ii]=="G" && q$Flag_automatica[ii]=="F") flag_rem2 = 10200
       if(q$Flag_manuale[ii]=="M" && q$Flag_automatica[ii]=="F") flag_rem2 = -200
       if(q$Flag_manuale[ii]=="M" && q$Flag_automatica[ii]=="F") flag_rem2 = -200
       if(q$Flag_manuale[ii]=="E" && q$Flag_automatica[ii]=="F") flag_rem2 = -10200 
       if(q$Flag_manuale[ii]=="G" && q$Flag_automatica[ii]=="P") flag_rem2 = 10100 
       if(q$Flag_manuale[ii]=="M" && q$Flag_automatica[ii]=="P") flag_rem2 = 100 
       if(q$Flag_manuale[ii]=="E" && q$Flag_automatica[ii]=="P") flag_rem2 = -10100 
      }
      date_nel_DB<-as.POSIXct(strptime(q$Data_e_ora[ii],format="%Y-%m-%d %H:%M:%S"),"UTC")
      date_riformattate <- format(date_nel_DB,"%Y/%m/%d %H:00")
      record<-paste(q$IDsensore[ii],",",date_riformattate,",",flag_rem2)
#  cat(q$IDsensore,q$Flag_manuale,q$Flag_automatica,aux,'/n',file=file_out,sep=",")
  
      # se flag_rem2 è definita scrittura su file csv (in append se non è la prima del ciclo, semaforo=1)
      #temp# if(is.numeric(flag_rem2)==TRUE && semaforo==0){
      if(is.numeric(flag_rem2)==TRUE){
      #temp# RetCode<-try(write.table(record,file=file_out,na="-999", sep=",",quote=F,row.names=F,col.names=F),silent=TRUE)
      #temp# semaforo <- 1
      #temp#}else if (is.numeric(flag_rem2)==TRUE && semaforo==1){
       RetCode<-try(write.table(record,file=file_out,na="-999", sep=",",quote=F,row.names=F,col.names=F,append=TRUE),silent=TRUE)
#
      if (inherits(RetCode,"try-error")) {
        print("ERRORE: impossibile scrivere sul file esterno:")
        print(file_out)
        print("Messaggio d'errore prodotto:")
        print(RetCode)
        # inserisci codice -4 nella tabella DQCinDBUNICO_invio
        print("inserimento di codice StatoInvio=-4 in DQCinDBUNICO_invio")
        insert<-paste("insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('",
                      DATA_ACT,"',-4,0,'nessuno','creaCSVwithDQCinfo.R','",
                      toString(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),"')",sep="")
        esecuzione <- try(dbGetQuery(conn, insert),silent=TRUE)
          if (inherits(esecuzione,"try-error")) {
           print("ERRORE: impossibile eseguire correttamente la query seguente:")
           print(insert)
           print("chiudo DB")
           dbDisconnect(conn)
           rm(conn)
           dbUnloadDriver(drv)
           print("Uscita con codice d'errore = 1")
           quit(status=1)
         }
        print("chiudo DB")
        dbDisconnect(conn)
        rm(conn)
        dbUnloadDriver(drv)
        print("Uscita con codice d'errore = 1")
        quit(status=1)
      }
     }

#________________________________________________________
#  cancella da DQCinDBMETEO_dati il record 
#________________________________________________________
    query<-paste("delete from DQCinDBUNICO_dati where IDsensore=",q$IDsensore[ii]," and Data_e_ora='", q$Data_e_ora[ii],"'",sep="")
    cat ( " query > ", query," \n")
      cancello <- try(dbGetQuery(conn, query),silent=TRUE)
       if (inherits(cancello,"try-error")) {
             print("ERRORE: impossibile eseguire correttamente la query seguente:")
             print(query)
             flag_delete <- 1
           }
     ii <- ii + 1
     }  #fine while
    }  #fine if (length(q$IDsensore)!=0)
#
#________________________________________________________
#   segnalo eventuali problemi nella cancellazione dei record da DQCinDBUNICO_dati 
#________________________________________________________
    if (flag_delete==1) {
      print("ERRORE: impossibile eseguire correttamente la query seguente:")
      print(query)
      print("Messaggio d'errore prodotto:")
      print(paste(q,"\n"))
      # inserisci codice -5 nella tabella DQCinDBUNICO_invio
      print("inserimento di codice StatoInvio=-5 in DQCinDBUNICO_invio")
      insert<-paste("insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('",
                    DATA_ACT,"',-5,0,'nessuno','creaCSVwithDQCinfo.R','",
                    toString(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),"')",sep="")
        esecuzione <- try(dbGetQuery(conn, insert),silent=TRUE)
          if (inherits(esecuzione,"try-error")) {
           print("ERRORE: impossibile eseguire correttamente la query seguente:")
           print(insert)
           print("chiudo DB")
           dbDisconnect(conn)
           rm(conn)
           dbUnloadDriver(drv)
           print("Uscita con codice d'errore = 1")
           quit(status=1)
          }
      print("chiudo DB")
      dbDisconnect(conn)
      rm(conn)
      dbUnloadDriver(drv)
      print("Uscita con codice d'errore = 1")
      quit(status=1)
    }
#    print(q)
#________________________________________________________
#  cancella da DQCinDBMETEO_dati i record residui da non inviare (delle reti o tipologie non di ns competenza) 
#________________________________________________________
    query<-paste("delete from DQCinDBUNICO_dati where (DQCinDBUNICO_dati.IDsensore in (select IDsensore from A_Sensori,A_Stazioni where A_Sensori.IDstazione=A_Stazioni.IDstazione and  (A_Stazioni.IDrete not in (1,4) or A_Sensori.NOMEtipologia not in ('T','PP','UR','PA','VV','VVP','VVS','DV','DVP','DVS','RG','RN')))) or (DQCinDBUNICO_dati.Flag_manuale_DBunico in (1,2))",sep="")
    cat ( " query > ", query," \n")
    q <- try(dbGetQuery(conn, query),silent=TRUE)
#   se la richiesta fallisce allora esci con codice 1
    if (inherits(q,"try-error")) {
      print("ERRORE: impossibile eseguire correttamente la query seguente:")
      print(query)
      print("Messaggio d'errore prodotto:")
      print(paste(q,"\n"))
      # inserisci codice -5 nella tabella DQCinDBUNICO_invio
      print("inserimento di codice StatoInvio=-5 in DQCinDBUNICO_invio")
      insert<-paste("insert into DQCinDBUNICO_invio (DataInvio,StatoInvio,RecordInviati,NomeFile,Autore,Data) values  ('",
                    DATA_ACT,"',-5,0,'nessuno','creaCSVwithDQCinfo.R','",
                    toString(format(Sys.time(), "%Y-%m-%d %H:%M:%S")),"')",sep="")
        esecuzione <- try(dbGetQuery(conn, insert),silent=TRUE)
          if (inherits(esecuzione,"try-error")) {
           print("ERRORE: impossibile eseguire correttamente la query seguente:")
           print(insert)
           print("chiudo DB")
           dbDisconnect(conn)
           rm(conn)
           dbUnloadDriver(drv)
           print("Uscita con codice d'errore = 1")
           quit(status=1)
          }
      print("chiudo DB")
      dbDisconnect(conn)
      rm(conn)
      dbUnloadDriver(drv)
      print("Uscita con codice d'errore = 1")
      quit(status=1)
    }
############################# 

#___________________________________________________
#    DISCONNESSIONE DAL DB
#___________________________________________________
# chiudo db
cat ( "chiudo DB \n" )
dbDisconnect(conn)
rm(conn)
dbUnloadDriver(drv)
#
cat ( "PROGRAMMA ESEGUITO CON SUCCESSO alle ", date()," \n" )
quit(status=0)

