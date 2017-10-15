FROM alpine:3.6

RUN apk update && apk add curl

COPY entrypoint.sh /
COPY pipelines /pipelines

ENTRYPOINT /entrypoint.sh
