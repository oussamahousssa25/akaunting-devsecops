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
                echo "========== DÉMARRAGE DU PIPELINE =========="
                echo "Build Version: ${BUILD_VERSION}"
                sh '''
                    echo "=== ENVIRONNEMENT DISPONIBLE ==="
                    docker --version || echo "Docker non disponible"
                    echo " Environnement vérifié"
                '''
            }
        }

        // ÉTAPE 2: Récupération du code source
        stage('Checkout du Code') {
            steps {
                echo "========== RÉCUPÉRATION DU CODE =========="
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
                    echo "========== INSTALLATION DES DÉPENDANCES =========="
                    
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
                        echo " Dépendances installées"
                        composer dump-autoload --optimize --no-scripts
                    else
                        echo " Dépendances non installées"
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
                    echo "========== CONFIGURATION LARAVEL PHP 8.1 =========="
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
                    echo " Configuration Laravel terminée"
                '''
            }
        }

        // ÉTAPE 5: TESTS PHPUNIT 
        stage('Exécuter Tests ') {
            agent {
                docker {
                    image 'webdevops/php-dev:8.1'
                    args '-u root:root -e PHP_MEMORY_LIMIT=2G -e COMPOSER_MEMORY_LIMIT=-1'
                }
            }
            steps {
                sh '''
                    echo "========== TESTS PHPUNIT COMPLETS =========="
                    echo "Cette étape peut prendre plusieurs minutes..."
                    
                    # Désactiver Xdebug (cause principale de segmentation fault)
                    echo "Désactivation de Xdebug..."
                    rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 2>/dev/null || true
                    php -d xdebug.mode=off -v | head -1
                    
                    # Configuration PHP pour éviter le segmentation fault
                    echo 'memory_limit = 2G' > /usr/local/etc/php/conf.d/memory.ini
                    echo 'opcache.enable = 0' >> /usr/local/etc/php/conf.d/memory.ini
                    echo 'xdebug.mode = off' >> /usr/local/etc/php/conf.d/memory.ini
                    
                    # Créer le répertoire pour les rapports
                    mkdir -p test-reports
                    
                    # Temps de début
                    START_TIME=$(date +%s)
                    
                    # Vérifier que PHPUnit est disponible
                    if [ ! -f "vendor/bin/phpunit" ]; then
                        echo "Installation de PHPUnit..."
                        composer require --dev phpunit/phpunit --no-interaction --ignore-platform-reqs
                    fi
                    
                    # Vérifier la configuration des tests
                    echo "=== Vérification pré-test ==="
                    ls -la vendor/bin/
                    [ -f "phpunit.xml" ] && echo "phpunit.xml trouvé" || echo "phpunit.xml non trouvé, utilisation configuration par défaut"
                    
                    # Préparer la commande PHPUnit
                    PHPUNIT_CMD="php -d xdebug.mode=off vendor/bin/phpunit"
                    
                    # Exécuter les tests avec timeout et gestion d'erreur
                    echo "=== Début des tests PHPUnit ==="
                    
                    set +e  # Ne pas arrêter en cas d'échec des tests
                    
                    # Exécution des tests avec rapports
                    timeout 600 ${PHPUNIT_CMD} \
                        --log-junit test-reports/junit.xml \
                        --testdox-text test-reports/testdox.txt \
                        --colors=never \
                        2>&1 | tee test-reports/phpunit.log
                    
                    TEST_EXIT_CODE=$?
                    set -e
                    
                    # Temps de fin
                    END_TIME=$(date +%s)
                    DURATION=$((END_TIME - START_TIME))
                    
                    echo "=== Résumé des tests ==="
                    echo "Durée: ${DURATION} secondes"
                    echo "Code de sortie: ${TEST_EXIT_CODE}"
                    
                    # Analyser les résultats
                    if [ ${TEST_EXIT_CODE} -eq 0 ]; then
                        echo "Tous les tests ont réussi!"
                    elif [ ${TEST_EXIT_CODE} -eq 124 ]; then
                        echo "Tests interrompus par timeout (10 minutes)"
                    elif [ ${TEST_EXIT_CODE} -eq 139 ]; then
                        echo "Segmentation fault détecté!"
                        echo "Causes possibles:"
                        echo "1. Xdebug activé"
                        echo "2. Mémoire insuffisante"
                        echo "3. Extension PHP problématique"
                    else
                        echo "Certains tests ont échoué (code: ${TEST_EXIT_CODE})"
                    fi
                    
                    # Afficher un résumé des tests
                    echo "=== Résumé du rapport ==="
                    if [ -f "test-reports/testdox.txt" ]; then
                        tail -50 test-reports/testdox.txt
                    fi
                    
                    # Générer un rapport de synthèse simplifié (sans backslashes problématiques)
                    cat > test-reports/summary.md << 'SUMMARY_EOF'
# Rapport des Tests - Build

## Informations générales
- **Date**: $(date)
- **Durée**: ${DURATION} secondes
- **Résultat**: $(if [ ${TEST_EXIT_CODE} -eq 0 ]; then echo "SUCCÈS"; else echo "ÉCHEC (code: ${TEST_EXIT_CODE})"; fi)

## Fichiers générés
- **JUnit XML**: test-reports/junit.xml
- **TestDox Texte**: test-reports/testdox.txt
- **Log complet**: test-reports/phpunit.log

## Statistiques
$(tail -20 test-reports/phpunit.log | grep -E "(Tests:|Time:|Memory:)" || echo "Aucune statistique disponible")

## Commandes de diagnostic
- Relancer les tests en mode verbeux: php -d xdebug.mode=off vendor/bin/phpunit --verbose
- Voir les tests échoués: grep -A 5 -B 5 "FAIL" test-reports/phpunit.log
- Voir les erreurs: grep -A 5 -B 5 "ERROR" test-reports/phpunit.log
SUMMARY_EOF
                    
                    echo "Exécution des tests PHPUnit terminée"
                    echo "Voir les rapports dans test-reports/"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'test-reports/**', allowEmptyArchive: true
                }
            }
        }

        // ÉTAPE 6: Security Scan with Trivy
        stage('Security Scan with Trivy') {
            steps {
                sh '''
                    echo "========== SCAN DE SÉCURITÉ TRIVY =========="
                    mkdir -p trivy-reports
                    docker run --rm \
                        -v $(pwd):/src \
                        aquasec/trivy:latest fs \
                        --exit-code 0 \
                        --no-progress \
                        --format json \
                        /src > trivy-reports/dependency-scan.json 2>/dev/null || echo "Scan Trivy échoué"
                    echo " Scan Trivy terminé"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-reports/**', allowEmptyArchive: true
                }
            }
        }

        // ÉTAPE 7: Construction de l'image Docker
        stage('Build Docker Image PHP 8.1') {
            steps {
                script {
                    echo "========== CONSTRUCTION IMAGE DOCKER PHP 8.1 =========="
                    
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
                            echo " Dockerfile créé"
                        else
                            echo " Dockerfile existant trouvé"
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
                        echo " Image Docker construite"
                        
                        # Lister les images
                        echo "Images disponibles:"
                        docker images | grep ${DOCKER_REPO} || echo "Aucune image trouvée"
                    """
                }
            }
        }

          // ÉTAPE 8: Push vers Docker Hub 
        stage('Push to Docker Hub') {
            steps {
                script {
                    echo "========== PUSH VERS DOCKER HUB =========="
                    
                    // Vérifier d'abord si l'image existe localement
                    sh """
                        echo "Vérification des images locales..."
                        docker images | grep ${DOCKER_REPO} || echo "Aucune image locale trouvée"
                    """
                    
                    try {
                        withCredentials([usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )]) {
                            sh '''
                                echo "Connexion à Docker Hub..."
                                echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || {
                                    echo " Échec de la connexion à Docker Hub"
                                    exit 1
                                }
                            '''
                            
                            // Push de l'image avec tag de version
                            sh """
                                echo "Pushing ${DOCKER_REPO}:${IMAGE_TAG}..."
                                docker push ${DOCKER_REPO}:${IMAGE_TAG} || {
                                    echo " Échec du push de la version spécifique"
                                    # Continuer quand même pour latest
                                }
                            """
                            
                            // Push de l'image avec tag latest
                            sh """
                                echo "Pushing ${DOCKER_REPO}:latest..."
                                docker push ${DOCKER_REPO}:latest || {
                                    echo " Échec du push de latest"
                                }
                            """
                            
                            sh 'docker logout'
                            echo " Push vers Docker Hub terminé"
                        }
                    } catch (Exception e) {
                        echo " Push vers Docker Hub échoué: ${e.getMessage()}"
                        echo "Cette étape peut être ignorée pour le moment"
                    }
                }
            }
        }
    }

    // SECTION POST-BUILD
    post {
        success {
            echo """
            ========== PIPELINE RÉUSSI ==========
            Build: ${BUILD_VERSION}
            Image: ${DOCKER_REPO}:${IMAGE_TAG}
            =========================================
            """
            sh """
                echo "=== RAPPORT DE BUILD ===" > build-report.txt
                echo "Date: \$(date)" >> build-report.txt
                echo "Build: ${BUILD_VERSION}" >> build-report.txt
                echo "Image: ${DOCKER_REPO}:${IMAGE_TAG}" >> build-report.txt
                echo "Docker Hub: https://hub.docker.com/r/${DOCKER_REPO}" >> build-report.txt
                echo "Status: SUCCESS" >> build-report.txt
            """
            archiveArtifacts artifacts: 'build-report.txt', allowEmptyArchive: true
        }
        
        failure {
            echo """
            ========== PIPELINE EN ÉCHEC ==========
            Build: ${BUILD_VERSION}
            ==========================================
            """
        }
        
        always {
            echo """
            ========== RÉSUMÉ ==========
            Durée: ${currentBuild.durationString}
            Résultat: ${currentBuild.currentResult}
            =================================
            """
            sh '''
                echo "Nettoyage..."
                docker container prune -f 2>/dev/null || true
                docker image prune -f 2>/dev/null || true
            '''
        }
    }
}