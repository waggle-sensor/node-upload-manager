FROM alpine:3.12
RUN apk add --no-cache openssh-client rsync
COPY node-upload-agent.sh node-upload-agent.sh
ENTRYPOINT ["/bin/sh", "node-upload-agent.sh"]
