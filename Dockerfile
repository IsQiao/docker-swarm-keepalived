FROM ubuntu:24.04

ENV CLEANIMAGE_VERSION 2.0
ENV CLEANIMAGE_URL https://raw.githubusercontent.com/lhns/docker-cleanimage/$CLEANIMAGE_VERSION/cleanimage

# Default environment variables for operator mode
ENV KEEPALIVED_IMAGE=osixia/keepalived:2.0.20
ENV KEEPALIVED_INTERFACE=""
ENV KEEPALIVED_PASSWORD=""
ENV KEEPALIVED_ROUTER_ID="51"
ENV KEEPALIVED_IP=""
ENV KEEPALIVED_UNICAST_PEERS=""
ENV KEEPALIVED_VIRTUAL_IPS=""
ENV KEEPALIVED_GROUP=""
ENV KEEPALIVED_NOTIFY="/container/service/keepalived/assets/notify.sh"
ENV KEEPALIVED_COMMAND_LINE_ARGUMENTS="--log-detail --dump-conf"
ENV KEEPALIVED_STATE="BACKUP"

RUN apt-get update \
 && apt-get install -y ca-certificates curl \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
 $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y docker-ce-cli \
 && curl -sSfL -- "$CLEANIMAGE_URL" > "/usr/local/bin/cleanimage" \
 && chmod +x "/usr/local/bin/cleanimage" \
 && cleanimage

COPY ["entrypoint.sh", "/entrypoint.sh"]
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["osixia/keepalived:2.0.20"]
