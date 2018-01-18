FROM brainlife/mcr:neurodebian1604-r2017a
MAINTAINER Lindsey Kitchell <kitchell@indiana.edu>

RUN apt-get update 
RUN apt-get install -y mrtrix python jq 

ADD . /app

WORKDIR /output

RUN ldconfig

ENTRYPOINT ["/app/ensembletracking.sh"]
 





