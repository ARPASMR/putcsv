FROM arpasmr/r-base
RUN apt-get update
RUN apt-get install -y cifs-utils
RUN apt-get install -y mysql-client
COPY . /usr/local/src/myscripts
WORKDIR /usr/local/src/myscripts
RUN chmod a+x *.sh
CMD ["./launcher.sh"]
