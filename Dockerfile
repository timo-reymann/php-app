FROM busybox AS sources
WORKDIR /files
RUN mkdir -p etc/nginx \
    && mkdir -p usr/local/etc \
    && mkdir -p bin \
    && mkdir -p etc/nginx/conf.d

# Copy over configuration
COPY nginx*.conf etc/nginx/
COPY php_fpm.ini etc/php/php-fpm.conf

# Copy over scripts
COPY scripts/* bin/

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
RUN apk add --no-cache \
      php-${PHP_VERSION} \
      php-${PHP_VERSION}-opcache \
      php-${PHP_VERSION}-openssl \
      php-${PHP_VERSION}-mysqli \
      php-${PHP_VERSION}-pdo \
      php-${PHP_VERSION}-mbstring \
      php-${PHP_VERSION}-phar \
      php-${PHP_VERSION}-fpm \
      php-${PHP_VERSION}-zip \
      php-${PHP_VERSION}-gd \
      php-${PHP_VERSION}-simplexml \
      php-${PHP_VERSION}-xml \
      php-${PHP_VERSION}-dom \
      php-${PHP_VERSION}-curl \
      php-${PHP_VERSION}-ctype \
      php-${PHP_VERSION}-mysqlnd \
      php-${PHP_VERSION}-pdo_mysql \
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
