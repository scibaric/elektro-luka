#!/bin/bash
set -euo pipefail

DOMAIN="elektro-luka.com"
EMAIL="sebastijan.cibaric@gmail.com"
COMPOSE="podman compose"

mkdir -p /var/www/certbot

case "${1:-}" in
    init)
        # Clean up any previous failed attempts
        $COMPOSE down 2>/dev/null || true
        podman stop -t 2 elektro-luka 2>/dev/null || true
        podman rm -f elektro-luka 2>/dev/null || true

        # Start nginx with HTTP-only config for ACME challenge
        NGINX_CONF=nginx-initial.conf $COMPOSE up -d nginx

        # Verify nginx is actually running
        if ! podman ps --format '{{.Names}}' | grep -q 'elektro-luka'; then
            echo "Error: nginx failed to start. Check 'podman logs elektro-luka'."
            exit 1
        fi

        # Verify ACME challenge path is reachable
        mkdir -p /var/www/certbot/.well-known/acme-challenge
        echo "acme-test-ok" > /var/www/certbot/.well-known/acme-challenge/_test
        HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/.well-known/acme-challenge/_test || true)
        rm -f /var/www/certbot/.well-known/acme-challenge/_test
        if [ "$HTTP_CODE" != "200" ]; then
            echo "Error: ACME challenge path returned HTTP $HTTP_CODE (expected 200)."
            echo "Nginx logs:"
            podman logs --tail 20 elektro-luka
            exit 1
        fi
        echo "ACME challenge path verified (HTTP 200)."

        $COMPOSE run --rm certbot certonly \
            --webroot --webroot-path=/var/www/certbot \
            --email "$EMAIL" --agree-tos --no-eff-email \
            -d "$DOMAIN" -d "www.$DOMAIN"
        # Restart with full SSL config
        $COMPOSE down
        $COMPOSE up -d nginx
        echo "Certificate obtained — site is live at https://$DOMAIN"
        ;;
    renew)
        $COMPOSE run --rm certbot renew --quiet
        $COMPOSE exec nginx nginx -s reload
        ;;
    *)
        echo "Usage: $0 {init|renew}"
        exit 1
        ;;
esac
