FROM brainlife/mcr:neurodebian1604-r2017a
MAINTAINER Lindsey Kitchell <kitchell@indiana.edu>

RUN apt-get update
RUN apt-get -y install sudo python jq
RUN sudo apt-get update
RUN sudo apt-get install -y mrtrix

ADD . /app

WORKDIR /output

RUN ldconfig

ENTRYPOINT ["/app/ensembletracking.sh"]
 





