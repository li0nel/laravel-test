# Install node
FROM node:14.16.0-buster AS node

WORKDIR /var/www/html

COPY . .

RUN npm ci && npm run prod

COPY . .

FROM php:8-fpm-buster

# Copy composer.lock and composer.json
COPY composer.json /var/www/html

# Set working directory
WORKDIR /var/www/html

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    default-mysql-client \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    libzip-dev \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    cron

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install extensions
RUN docker-php-ext-install pdo_mysql zip exif pcntl
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Add user for laravel application
# RUN groupadd -g 1000 www
# RUN useradd -u 1000 -ms /bin/bash -g www www

# Copy existing application directory contents
COPY . /var/www/html/
RUN composer install

# Copy node modules
COPY --from=node /var/www/html/node_modules ./node_modules/
COPY --from=node /usr/local/bin/* /usr/local/bin/

# Copy existing application directory permissions
# COPY --chown=www:www . /var/www/html

ADD deploy/cron/artisan-schedule-run /etc/cron.d/artisan-schedule-run
RUN chmod 0644 /etc/cron.d/artisan-schedule-run
RUN chmod +x /etc/cron.d/artisan-schedule-run
RUN touch /var/log/cron.log

RUN mkdir storage/logs
RUN touch storage/logs/laravel.log

# RUN chown -R www-data:www-data /var/www
RUN chmod -R 777 /var/www/html/storage/

# Change current user to www
# USER www

RUN echo APP_KEY= > .env && php artisan key:generate --force

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["/bin/sh", "-c", "cd /var/www/html && php artisan migrate --force && php-fpm"]
