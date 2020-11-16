FROM alpine
RUN apk add rsync
COPY node-upload-manager.sh node-upload-manager.sh
CMD ["sh", "node-upload-manager.sh"]
