FROM alpine:3.12
RUN apk add --no-cache openssh-client rsync
COPY . .
ENTRYPOINT ["/bin/sh", "node-upload-agent.sh"]
