FROM alpine:3.7

RUN apk add --no-cache redis sed bash

COPY redis-master.conf /redis-master.conf
COPY redis-slave.conf /redis-slave.conf
COPY run.sh /run.sh

RUN chmod a+x /run.sh
CMD [ "/run.sh" ]

ENTRYPOINT [ "bash", "-c" ]
