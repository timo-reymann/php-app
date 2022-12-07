FROM php:8.1.13-fpm

EXPOSE 8080

ARG USER_UID=1002
ARG USER_GUID=1002
# renovate: datasource=github-releases depName=nicolas-van/multirun
ARG MULTIRUN_VERSION=1.0.0
# renovate: datasource=repology depName=npackd_stable/org.nginx.Nginx versioning=loose
ARG NGINX_VERSION=1.23.2

# Install base
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        gnupg2 && \
    echo "deb https://nginx.org/packages/debian/ buster nginx" > /etc/apt/sources.list.d/nginx.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62 && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
        zip \
        unzip \
        libzip-dev \
        libonig-dev \
        git \
        nginx=${VERSION_NGINX}* && \
    rm -rf /etc/nginx/conf.d/* && \
    rm -rf /var/lib/apt/lists/* && \
    # Install multirun
    curl -Ls https://github.com/nicolas-van/multirun/releases/download/${VERSION_MULTIRUN}/multirun-glibc-${VERSION_MULTIRUN}.tar.gz | tar xvz && \
    chmod +x multirun && \
    mv multirun /bin && \
    # Setup unprivileged user
    groupadd -g ${USER_GUID} application && \
    useradd -u ${USER_UID} --gid ${USER_GUID} application && \
    # Create /app
    mkdir -p /app && \
    touch /app/.keep && \
    # Create home directory
    mkdir /home/application && \
    touch /home/application/.keep && \
    # Fix permissions
    chown -R application:application \
        /etc/nginx \
        /home/application \
        /var/log/nginx \
        /app

# Install php extensions
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev && \
    # gd
    docker-php-ext-configure gd \
        --enable-gd \
        --with-freetype \
        --with-jpeg && \
    rm -rf /var/lib/apt/lists/* &&\
    # Install dependencies
    docker-php-ext-install \
        opcache \
        mysqli \
        pdo_mysql \
        zip \
        gd && \
    # Setup php config
    rm -rf /usr/local/etc/php-fpm* && \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Copy over configuration
COPY --chown=application:application nginx*.conf /etc/nginx/
COPY --chown=application:application php_fpm.ini /usr/local/etc/php-fpm.conf

USER application

# Setup entrypoint and pwd
WORKDIR /app
ENTRYPOINT ["/bin/multirun", "-v", "nginx", "php-fpm"]
