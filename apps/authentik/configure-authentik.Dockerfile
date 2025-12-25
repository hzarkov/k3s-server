FROM alpine:3.19
RUN apk add --no-cache bash curl jq
COPY configure-authentik.sh /configure-authentik.sh
RUN chmod +x /configure-authentik.sh
ENTRYPOINT ["/configure-authentik.sh"]
