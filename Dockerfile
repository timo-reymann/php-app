FROM busybox as sources
WORKDIR /files
RUN mkdir -p etc/nginx \
    && mkdir -p usr/local/etc \
    && mkdir -p usr/bin

# Copy over configuration
COPY nginx*.conf etc/nginx/
COPY php_fpm.ini etc/php/php-fpm.conf

# Copy over scripts
COPY scripts/* usr/bin/

FROM chainguard/wolfi-base
LABEL org.opencontainers.image.title="php-app"
LABEL org.opencontainers.image.description="Docker image for running PHP apps in a single container with nginx and PHP-fpm"
LABEL org.opencontainers.image.ref.name="main"
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.vendor="Timo Reymann <mail@timo-reymann.de>"
LABEL org.opencontainers.image.authors="Timo Reymann <mail@timo-reymann.de>"
LABEL org.opencontainers.image.url="https://github.com/timo-reymann/php-app"
LABEL org.opencontainers.image.documentation="https://github.com/timo-reymann/php-app"
LABEL org.opencontainers.image.source="https://github.com/timo-reymann/php-app.git"
HEALTHCHECK --start-period=2s --retries=4 --timeout=10s CMD curl -f http://localhost:8080 > /dev/null || exit 1
EXPOSE 8080

ARG USER_UID=1002
ARG USER_GUID=1002

# Install nginx
RUN apk add --no-cache nginx

# Install multirun
# renovate: datasource=github-releases depName=nicolas-van/multirun
ARG MULTIRUN_VERSION=1.1.3
RUN apk add --no-cache curl \
    && curl -Ls https://github.com/nicolas-van/multirun/releases/download/${MULTIRUN_VERSION}/multirun-x86_64-linux-gnu-${MULTIRUN_VERSION}.tar.gz | tar xvz \
    && chmod +x multirun \
    && mv multirun /bin

# Install php
# renovate: datasource=docker depName=php
ARG PHP_VERSION=8.3
ENV PHP_VERSION=${PHP_VERSION}
RUN apk add --no-cache nginx curl php-${PHP_VERSION} php-${PHP_VERSION}-opcache php-${PHP_VERSION}-fpm php-${PHP_VERSION}-zip php-${PHP_VERSION}-gd \
    && adduser -D -u ${USER_UID} application \
    # Create /app
    && mkdir -p /app  \
    && touch /app/.keep \
    # Create home directory
    && touch /home/application/.keep \
    # Fix permissions
    && chown -R application:application \
        /etc/nginx \
        /var/lib/nginx/logs \
        /app

COPY --from=sources --chown=application:application /files /

USER application

# Setup entrypoint and pwd
WORKDIR /app
ENTRYPOINT ["/bin/multirun", "-v", "nginx", "php-fpm"]
