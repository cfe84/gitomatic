FROM docker:cli
RUN apk add --no-cache \
    bash \
    inotify-tools \
    && rm -rf /var/cache/apk/*
WORKDIR /app
RUN git config --global --add safe.directory '*'
RUN git config --global advice.detachedHead false
COPY *.sh ./
COPY tasks ./tasks
ENTRYPOINT ["bash", "./monitor.sh"]