FROM alpine
RUN apk add openssh-client rsync
COPY node-upload-agent.sh node-upload-agent.sh
CMD ["sh", "node-upload-agent.sh"]
