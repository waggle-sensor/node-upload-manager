FROM alpine
RUN apk add rsync
COPY node-upload-agent.sh node-upload-agent.sh
CMD ["sh", "node-upload-agent.sh"]
