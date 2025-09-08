#!/bin/bash

# SSL Certificate Management Script
# Run this on your DigitalOcean droplet

set -e

show_help() {
    echo "🔒 SSL Certificate Manager for Potato"
    echo "===================================="
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show SSL certificate status"
    echo "  renew       - Renew Let's Encrypt certificates"
    echo "  test        - Test SSL configuration"
    echo "  backup      - Backup SSL certificates"
    echo "  restore     - Restore from backup"
    echo "  monitor     - Show SSL monitoring info"
    echo "  help        - Show this help"
    echo ""
}

check_ssl_status() {
    echo "🔍 SSL Certificate Status"
    echo "========================"
    echo ""
    
    # Check if Let's Encrypt certificates exist
    if [ -d "/etc/letsencrypt/live" ] && [ "$(ls -A /etc/letsencrypt/live 2>/dev/null)" ]; then
        echo "📋 Let's Encrypt Certificates:"
        sudo certbot certificates 2>/dev/null || echo "No Let's Encrypt certificates found"
        echo ""
    fi
    
    # Check self-signed certificates
    if [ -f "/etc/ssl/potato/potato-selfsigned.crt" ]; then
        echo "📋 Self-Signed Certificate:"
        echo "Location: /etc/ssl/potato/potato-selfsigned.crt"
        echo "Expires: $(sudo openssl x509 -in /etc/ssl/potato/potato-selfsigned.crt -noout -enddate | cut -d= -f2)"
        echo ""
    fi
    
    # Check Cloudflare origin certificate
    if [ -f "/etc/ssl/cloudflare/origin.crt" ]; then
        echo "📋 Cloudflare Origin Certificate:"
        echo "Location: /etc/ssl/cloudflare/origin.crt"
        echo "Expires: $(sudo openssl x509 -in /etc/ssl/cloudflare/origin.crt -noout -enddate | cut -d= -f2)"
        echo ""
    fi
    
    # Check Nginx SSL configuration
    echo "🌐 Nginx SSL Configuration:"
    if sudo nginx -t 2>/dev/null; then
        echo "✅ Nginx configuration is valid"
        
        # Check if SSL is configured
        if sudo grep -q "ssl_certificate" /etc/nginx/sites-available/potato 2>/dev/null; then
            echo "✅ SSL is configured in Nginx"
            
            # Show SSL certificate being used
            ssl_cert=$(sudo grep "ssl_certificate " /etc/nginx/sites-available/potato | head -1 | awk '{print $2}' | tr -d ';')
            if [ -f "$ssl_cert" ]; then
                echo "✅ SSL certificate file exists: $ssl_cert"
            else
                echo "❌ SSL certificate file not found: $ssl_cert"
            fi
        else
            echo "❌ SSL not configured in Nginx"
        fi
    else
        echo "❌ Nginx configuration has errors"
    fi
    
    echo ""
    echo "🔥 Firewall Status:"
    sudo ufw status | grep -E "(443|80)" || echo "HTTPS/HTTP ports not configured"
    
    echo ""
    echo "📊 Service Status:"
    echo "Nginx: $(sudo systemctl is-active nginx)"
    echo "Potato: $(sudo systemctl is-active potato)"
}

renew_certificates() {
    echo "🔄 Renewing SSL Certificates"
    echo "============================"
    echo ""
    
    if command -v certbot >/dev/null 2>&1; then
        echo "Renewing Let's Encrypt certificates..."
        sudo certbot renew
        
        if [ $? -eq 0 ]; then
            echo "✅ Certificate renewal completed"
            echo "🔄 Reloading Nginx..."
            sudo systemctl reload nginx
        else
            echo "❌ Certificate renewal failed"
        fi
    else
        echo "❌ Certbot not installed. Only Let's Encrypt certificates can be auto-renewed."
        echo ""
        echo "For self-signed certificates, run:"
        echo "  ./setup-https-selfsigned.sh"
    fi
}

test_ssl() {
    echo "🧪 Testing SSL Configuration"
    echo "============================"
    echo ""
    
    # Test Nginx configuration
    echo "Testing Nginx configuration..."
    if sudo nginx -t; then
        echo "✅ Nginx configuration is valid"
    else
        echo "❌ Nginx configuration has errors"
        return 1
    fi
    
    # Test SSL certificate
    echo ""
    echo "Testing SSL certificate..."
    
    # Get the domain/IP from Nginx config
    domain=$(sudo grep "server_name" /etc/nginx/sites-available/potato | grep -v "_" | head -1 | awk '{print $2}' | tr -d ';' || echo "localhost")
    
    if [ "$domain" = "localhost" ] || [ "$domain" = "_" ]; then
        # Use server IP for testing
        domain=$(curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")
    fi
    
    echo "Testing SSL connection to: $domain"
    
    # Test SSL connection
    if timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | grep -q "CONNECTED"; then
        echo "✅ SSL connection successful"
        
        # Get certificate info
        cert_info=$(timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
        if [ ! -z "$cert_info" ]; then
            echo "Certificate validity:"
            echo "$cert_info"
        fi
    else
        echo "❌ SSL connection failed"
        echo "This might be normal for self-signed certificates or if the domain isn't accessible externally"
    fi
}

backup_ssl() {
    echo "💾 Backing up SSL Certificates"
    echo "=============================="
    echo ""
    
    backup_dir="/opt/potato/ssl-backups/$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$backup_dir"
    
    # Backup Let's Encrypt certificates
    if [ -d "/etc/letsencrypt" ]; then
        echo "Backing up Let's Encrypt certificates..."
        sudo cp -r /etc/letsencrypt "$backup_dir/"
        echo "✅ Let's Encrypt certificates backed up"
    fi
    
    # Backup self-signed certificates
    if [ -d "/etc/ssl/potato" ]; then
        echo "Backing up self-signed certificates..."
        sudo cp -r /etc/ssl/potato "$backup_dir/"
        echo "✅ Self-signed certificates backed up"
    fi
    
    # Backup Cloudflare certificates
    if [ -d "/etc/ssl/cloudflare" ]; then
        echo "Backing up Cloudflare certificates..."
        sudo cp -r /etc/ssl/cloudflare "$backup_dir/"
        echo "✅ Cloudflare certificates backed up"
    fi
    
    # Backup Nginx configuration
    echo "Backing up Nginx configuration..."
    sudo cp /etc/nginx/sites-available/potato "$backup_dir/nginx-potato.conf"
    echo "✅ Nginx configuration backed up"
    
    echo ""
    echo "✅ Backup completed: $backup_dir"
    echo "Backup size: $(sudo du -sh "$backup_dir" | cut -f1)"
}

show_monitor() {
    echo "📊 SSL Monitoring Information"
    echo "============================="
    echo ""
    
    # Certificate expiration monitoring
    echo "🗓️ Certificate Expiration Dates:"
    echo "--------------------------------"
    
    # Let's Encrypt certificates
    if [ -d "/etc/letsencrypt/live" ] && [ "$(ls -A /etc/letsencrypt/live 2>/dev/null)" ]; then
        for cert_dir in /etc/letsencrypt/live/*/; do
            if [ -f "$cert_dir/cert.pem" ]; then
                domain=$(basename "$cert_dir")
                expiry=$(sudo openssl x509 -in "$cert_dir/cert.pem" -noout -enddate | cut -d= -f2)
                expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
                current_epoch=$(date +%s)
                days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                
                echo "Domain: $domain"
                echo "Expires: $expiry"
                echo "Days left: $days_left"
                
                if [ $days_left -lt 30 ]; then
                    echo "⚠️  WARNING: Certificate expires in less than 30 days!"
                elif [ $days_left -lt 7 ]; then
                    echo "🚨 CRITICAL: Certificate expires in less than 7 days!"
                fi
                echo ""
            fi
        done
    fi
    
    # Self-signed certificate
    if [ -f "/etc/ssl/potato/potato-selfsigned.crt" ]; then
        expiry=$(sudo openssl x509 -in /etc/ssl/potato/potato-selfsigned.crt -noout -enddate | cut -d= -f2)
        echo "Self-signed certificate expires: $expiry"
        echo ""
    fi
    
    # Auto-renewal status
    echo "🔄 Auto-renewal Status:"
    echo "----------------------"
    if command -v certbot >/dev/null 2>&1; then
        echo "Certbot installed: ✅"
        
        # Check if renewal timer is active
        if systemctl is-active --quiet certbot.timer 2>/dev/null; then
            echo "Auto-renewal timer: ✅ Active"
        else
            echo "Auto-renewal timer: ❌ Inactive"
        fi
        
        # Test renewal
        echo "Testing renewal (dry run)..."
        if sudo certbot renew --dry-run >/dev/null 2>&1; then
            echo "Renewal test: ✅ Passed"
        else
            echo "Renewal test: ❌ Failed"
        fi
    else
        echo "Certbot not installed: ❌"
    fi
    
    echo ""
    echo "📈 SSL Security Score:"
    echo "---------------------"
    echo "To check your SSL security rating, visit:"
    domain=$(sudo grep "server_name" /etc/nginx/sites-available/potato | grep -v "_" | head -1 | awk '{print $2}' | tr -d ';' 2>/dev/null || echo "your-domain.com")
    echo "https://www.ssllabs.com/ssltest/analyze.html?d=$domain"
}

# Main script logic
case "${1:-help}" in
    "status")
        check_ssl_status
        ;;
    "renew")
        renew_certificates
        ;;
    "test")
        test_ssl
        ;;
    "backup")
        backup_ssl
        ;;
    "monitor")
        show_monitor
        ;;
    "help"|*)
        show_help
        ;;
esac
EOF