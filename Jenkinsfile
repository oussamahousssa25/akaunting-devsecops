pipeline {
    agent any

    environment {
        COMPOSER_ALLOW_SUPERUSER = 1
        BUILD_VERSION = "${BUILD_NUMBER}-${new Date().format('yyyyMMddHHmmss')}"
        DOCKER_REPO = 'oussama25351/akaunting'
        IMAGE_TAG = "${BUILD_VERSION}"
    }

    stages {
        // ÉTAPE 1: Vérification de l'environnement
        stage('Vérifier Environnement') {
            steps {
                echo "========== 🚀 DÉMARRAGE DU PIPELINE =========="
                echo "Build Version: ${BUILD_VERSION}"
                sh '''
                    echo "=== ENVIRONNEMENT DISPONIBLE ==="
                    docker --version || echo "Docker non disponible"
                    echo "✅ Environnement vérifié"
                '''
            }
        }

        // ÉTAPE 2: Récupération du code (CORRIGÉ)
        stage('Checkout du Code') {
            steps {
                echo "========== 📂 RÉCUPÉRATION DU CODE =========="
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/oussamahousssa25/akaunting-devsecops.git',
                        credentialsId: ''
                    ]],
                    extensions: [[
                        $class: 'CloneOption',
                        shallow: true,
                        depth: 1
                    ]]
                ])
                sh '''
                    # Corriger les permissions Git sans erreur
                    git config --global --unset-all safe.directory 2>/dev/null || true
                    git config --global --add safe.directory "$(pwd)"
                    git config --global --add safe.directory "/var/jenkins_home/workspace/*"
                    git config --global --add safe.directory "/var/jenkins_home/workspace/@*"
                    echo "Permissions Git configurées"
                    ls -la
                '''
            }
        }

        // ÉTAPE 3: Installation des Dépendances PHP
        stage('Installer Dépendances PHP') {
            agent {
                docker {
                    image 'composer:2.9.5'
                    args '-u root:root'
                }
            }
            steps {
                sh '''
                    echo "========== 📦 INSTALLATION DES DÉPENDANCES =========="
                    
                    # Corriger permissions Git dans le conteneur
                    git config --global --unset-all safe.directory 2>/dev/null || true
                    git config --global --add safe.directory "$(pwd)"
                    
                    # Préparation environnement
                    mkdir -p storage/framework/{cache,sessions,views}
                    mkdir -p database bootstrap/cache
                    chmod -R 775 storage bootstrap/cache
                    
                    # Installation dépendances (sans scripts)
                    composer install \
                        --no-interaction \
                        --prefer-dist \
                        --optimize-autoloader \
                        --no-scripts \
                        --ignore-platform-reqs
                    
                    if [ -d "vendor" ]; then
                        echo "✅ Dépendances installées"
                        composer dump-autoload --optimize --no-scripts
                    else
                        echo "⚠ Dépendances non installées"
                    fi
                '''
            }
        }

        // ÉTAPE 4: Configuration Laravel
        stage('Configurer Application Laravel') {
            agent {
                docker {
                    image 'php:8.1-cli'
                    args '-u root:root'
                }
            }
            steps {
                sh '''
                    echo "========== ⚙️ CONFIGURATION LARAVEL PHP 8.1 =========="
                    cat > .env << EOF
APP_NAME="Akaunting"
APP_ENV=testing
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://localhost

DB_CONNECTION=sqlite
DB_DATABASE=database/database.sqlite

CACHE_DRIVER=array
SESSION_DRIVER=array
QUEUE_CONNECTION=sync

LOG_CHANNEL=stack
LOG_LEVEL=debug
EOF
                    
                    touch database/database.sqlite
                    chmod 666 database/database.sqlite
                    echo "✅ Configuration Laravel terminée"
                '''
            }
        }

        // ÉTAPE 5: Construction de l'image Docker
        stage('Build Docker Image PHP 8.1') {
            steps {
                script {
                    echo "========== 🐳 CONSTRUCTION IMAGE DOCKER PHP 8.1 =========="
                    
                    sh '''
                        # Vérifier le répertoire
                        echo "Répertoire de travail:"
                        pwd
                        ls -la
                        
                        # Créer Dockerfile si absent
                        if [ ! -f "Dockerfile" ]; then
                            echo "Création Dockerfile optimisé"
                            cat > Dockerfile << 'DOCKEREOF'
FROM php:8.1-apache

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip \
    libicu-dev \
    libpng-dev libjpeg-dev libfreetype6-dev \
    libxml2-dev libonig-dev libcurl4-openssl-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install pdo pdo_mysql bcmath intl zip gd mbstring xml curl \
 && a2enmod rewrite

# Installation de Composer
COPY --from=composer:2.9.5 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copier les fichiers de dépendances
COPY composer.json composer.lock ./

# Installer les dépendances (sans dev, sans scripts)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Copier le reste de l'application
COPY . .

# Configurer les permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache

# Configuration PHP
RUN echo 'memory_limit = 512M' > /usr/local/etc/php/conf.d/memory.ini

EXPOSE 80
CMD ["apache2-foreground"]
DOCKEREOF
                            echo "✅ Dockerfile créé"
                        else
                            echo "✅ Dockerfile existant trouvé"
                            cat Dockerfile
                        fi
                    '''
                    
                    sh """
                        echo "Construction: ${DOCKER_REPO}:${IMAGE_TAG}"
                        docker build -t ${DOCKER_REPO}:${IMAGE_TAG} .
                        docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:latest
                        
                        # Tester l'image
                        echo "Test de l'image..."
                        docker run --rm ${DOCKER_REPO}:${IMAGE_TAG} php --version
                        echo "✅ Image Docker construite"
                        
                        # Lister les images
                        echo "Images disponibles:"
                        docker images | grep ${DOCKER_REPO} || echo "Aucune image trouvée"
                    """
                }
            }
        }

        // ÉTAPE 6: Push vers Docker Hub
        stage('Push to Docker Hub') {
            steps {
                script {
                    echo "========== 📤 PUSH VERS DOCKER HUB =========="
                    
                    // Test sans credentials d'abord
                    sh """
                        echo "✅ Image Docker construite avec succès"
                        echo "Nom: ${DOCKER_REPO}:${IMAGE_TAG}"
                        echo "Tag latest: ${DOCKER_REPO}:latest"
                        echo ""
                        echo "Pour pousser vers Docker Hub:"
                        echo "1. Créez des credentials dans Jenkins avec l'ID 'dockerhub-creds'"
                        echo "2. Décommentez le code dans cette étape"
                        echo "3. Relancez le pipeline"
                    """
                    
                    /*
                    // À décommenter quand vos credentials seront configurés
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh '''
                            echo "Connexion à Docker Hub..."
                            echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                        '''
                        
                        sh """
                            echo "Pushing images..."
                            docker push ${DOCKER_REPO}:${IMAGE_TAG}
                            docker push ${DOCKER_REPO}:latest
                            docker logout
                            echo "✅ Images poussées avec succès"
                        """
                    }
                    */
                }
            }
        }
    }

    // SECTION POST-BUILD
    post {
        success {
            echo """
            ========== ✅ PIPELINE RÉUSSI ==========
            Build: ${BUILD_VERSION}
            Image: ${DOCKER_REPO}:${IMAGE_TAG}
            URL: https://hub.docker.com/r/${DOCKER_REPO}
            =========================================
            """
        }
        
        failure {
            echo """
            ========== ❌ PIPELINE EN ÉCHEC ==========
            Build: ${BUILD_VERSION}
            ==========================================
            """
        }
        
        always {
            echo """
            ========== 📊 RÉSUMÉ ==========
            Durée: ${currentBuild.durationString}
            Résultat: ${currentBuild.currentResult}
            =================================
            """
            // Nettoyage
            sh '''
                echo "Nettoyage..."
                docker container prune -f 2>/dev/null || true
                docker image prune -f 2>/dev/null || true
            '''
        }
    }
}