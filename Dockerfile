FROM alpine
RUN apk add openssh-client rsync
COPY node-upload-agent.sh node-upload-agent.sh
ENTRYPOINT ["sh", "node-upload-agent.sh"]
