FROM alpine:3.12
WORKDIR /app
RUN apk add --no-cache openssh-client rsync bash
COPY . .
ENTRYPOINT ["/app/main.sh"]
