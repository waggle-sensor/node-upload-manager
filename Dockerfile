FROM alpine:3.12
RUN apk add --no-cache openssh-client rsync bash
COPY . .
ENTRYPOINT ["/main.sh"]
