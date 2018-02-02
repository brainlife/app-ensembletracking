FROM brainlife/mcr:neurodebian1604-r2017a
MAINTAINER Lindsey Kitchell <kitchell@indiana.edu>

RUN apt-get update
RUN apt-get -y install sudo python jq
RUN sudo apt-get update
RUN sudo apt-get install -y mrtrix

ADD mrtrix.conf /etc/mrtrix.conf

WORKDIR /output

#for singularity
RUN ldconfig && mkdir -p /N/u /N/home /N/dc2 /N/soft

#ENTRYPOINT ["/app/ensembletracking.sh"]
 





