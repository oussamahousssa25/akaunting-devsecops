FROM php:8.2-apache

# Installer les dépendances système et extensions PHP (CORRIGÉ)
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip \
    libicu-dev \
    libpng-dev libjpeg-dev libfreetype6-dev \
    libxml2-dev libonig-dev libcurl4-openssl-dev \
    git curl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install pdo pdo_mysql bcmath intl zip gd mbstring xml curl \
 && a2enmod rewrite headers \
 && rm -rf /var/lib/apt/lists/*

# Installer Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Apache docroot -> public (pour Laravel/Akaunting)
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
 && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

WORKDIR /var/www/html

# Copier l'application
COPY . .

# Installer les dépendances Composer (production)
RUN if [ -f "composer.json" ]; then \
    composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Permissions Laravel/Akaunting (CORRIGÉ)
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache \
    && chmod -R 775 /var/www/html  # Permissions générales

# Variables d'environnement
ENV APP_DEBUG=false
ENV APP_ENV=production

EXPOSE 80

CMD ["apache2-foreground"]