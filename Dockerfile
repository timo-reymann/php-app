FROM php:8.1.13-fpm

HEALTHCHECK --start-period=5s --retries=4 --timeout=10s CMD curl -f http://localhost:8080 > /dev/null || exit 1
EXPOSE 8080

ARG USER_UID=1002
ARG USER_GUID=1002
# renovate: datasource=github-releases depName=nicolas-van/multirun
ARG MULTIRUN_VERSION=1.1.3
# renovate: datasource=repology depName=debian_11/org.nginx.Nginx versioning=loose
ARG NGINX_VERSION=1.18.0

# Install base
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        lsb-release \
        gnupg2 && \
    echo "deb https://nginx.org/packages/debian/ `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62 && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
        zip \
        unzip \
        libzip-dev \
        libonig-dev \
        git \
        nginx=${NGINX_VERSION}* && \
    rm -rf /etc/nginx/conf.d/* && \
    rm -rf /var/lib/apt/lists/* && \
    # Install multirun
    curl -Ls https://github.com/nicolas-van/multirun/releases/download/${MULTIRUN_VERSION}/multirun-x86_64-linux-gnu-${MULTIRUN_VERSION}.tar.gz | tar xvz && \
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

# Copy over scripts
COPY --chown=application:application scripts/* /usr/bin/

USER application

# Setup entrypoint and pwd
WORKDIR /app
ENTRYPOINT ["/bin/multirun", "-v", "nginx", "php-fpm"]
