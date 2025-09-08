#!/bin/bash

# Diagnose SSL certificate trust issues for musicscience.uk
# Run this on your DigitalOcean droplet

set -e

DOMAIN="musicscience.uk"
WWW_DOMAIN="www.musicscience.uk"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo "🔍 Diagnosing SSL Certificate Issues for $DOMAIN"
echo "================================================"

echo ""
echo "📊 1. Server Information:"
echo "------------------------"
echo "Domain: $DOMAIN"
echo "WWW Domain: $WWW_DOMAIN"
echo "Server IP: $SERVER_IP"

echo ""
echo "🌐 2. DNS Resolution Check:"
echo "--------------------------"
echo "Checking DNS resolution for $DOMAIN..."
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null || echo "FAILED")
echo "$DOMAIN resolves to: $DOMAIN_IP"

echo ""
echo "Checking DNS resolution for $WWW_DOMAIN..."
WWW_IP=$(dig +short "$WWW_DOMAIN" 2>/dev/null || echo "FAILED")
echo "$WWW_DOMAIN resolves to: $WWW_IP"

echo ""
echo "DNS Status:"
if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
    echo "✅ $DOMAIN correctly points to this server"
else
    echo "❌ $DOMAIN points to $DOMAIN_IP but server IP is $SERVER_IP"
fi

if [ "$WWW_IP" = "$SERVER_IP" ]; then
    echo "✅ $WWW_DOMAIN correctly points to this server"
else
    echo "❌ $WWW_DOMAIN points to $WWW_IP but server IP is $SERVER_IP"
fi

echo ""
echo "📋 3. Certificate Files Check:"
echo "------------------------------"
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "✅ Certificate directory exists: /etc/letsencrypt/live/$DOMAIN"
    
    echo ""
    echo "Certificate files:"
    ls -la "/etc/letsencrypt/live/$DOMAIN/"
    
    echo ""
    echo "Certificate details:"
    if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
        echo "Subject:"
        sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -subject
        
        echo ""
        echo "Issuer:"
        sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -issuer
        
        echo ""
        echo "Validity dates:"
        sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -dates
        
        echo ""
        echo "Subject Alternative Names (SAN):"
        sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -text | grep -A 1 "Subject Alternative Name" || echo "No SAN found"
        
        echo ""
        echo "Certificate fingerprint:"
        sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -fingerprint -sha256
    else
        echo "❌ Certificate file not found"
    fi
else
    echo "❌ Certificate directory not found: /etc/letsencrypt/live/$DOMAIN"
fi

echo ""
echo "🌐 4. Nginx Configuration Analysis:"
echo "----------------------------------"
if [ -f "/etc/nginx/sites-available/potato" ]; then
    echo "Current Nginx configuration:"
    echo ""
    echo "Server names:"
    grep "server_name" /etc/nginx/sites-available/potato || echo "No server names found"
    
    echo ""
    echo "SSL certificate paths:"
    grep "ssl_certificate" /etc/nginx/sites-available/potato || echo "No SSL certificates configured"
    
    echo ""
    echo "Listen directives:"
    grep "listen" /etc/nginx/sites-available/potato || echo "No listen directives found"
else
    echo "❌ Nginx configuration file not found"
fi

echo ""
echo "🧪 5. SSL Connection Test:"
echo "-------------------------"
echo "Testing SSL connection to $DOMAIN:443..."
if timeout 10 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null > /tmp/ssl_test_$DOMAIN.txt; then
    echo "✅ SSL connection successful"
    
    echo ""
    echo "Certificate presented by server:"
    grep "subject=" /tmp/ssl_test_$DOMAIN.txt || echo "Subject not found"
    grep "issuer=" /tmp/ssl_test_$DOMAIN.txt || echo "Issuer not found"
    
    echo ""
    echo "Certificate chain verification:"
    if openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -text | grep -q "Let's Encrypt"; then
        echo "✅ Let's Encrypt certificate detected"
    else
        echo "❌ Not a Let's Encrypt certificate or verification failed"
    fi
    
    rm -f /tmp/ssl_test_$DOMAIN.txt
else
    echo "❌ SSL connection failed"
fi

echo ""
echo "🔍 6. Certificate Chain Analysis:"
echo "--------------------------------"
echo "Checking certificate chain for $DOMAIN..."
if timeout 10 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" -showcerts </dev/null 2>/dev/null > /tmp/chain_test.txt; then
    cert_count=$(grep -c "BEGIN CERTIFICATE" /tmp/chain_test.txt)
    echo "Certificates in chain: $cert_count"
    
    if [ $cert_count -ge 2 ]; then
        echo "✅ Certificate chain appears complete"
    else
        echo "❌ Certificate chain may be incomplete"
    fi
    
    rm -f /tmp/chain_test.txt
else
    echo "❌ Could not retrieve certificate chain"
fi

echo ""
echo "🔄 7. Certbot Status:"
echo "--------------------"
echo "Certbot certificates:"
sudo certbot certificates 2>/dev/null || echo "Certbot command failed"

echo ""
echo "Recent certbot logs:"
if [ -f "/var/log/letsencrypt/letsencrypt.log" ]; then
    echo "Last 10 lines from certbot log:"
    sudo tail -10 /var/log/letsencrypt/letsencrypt.log
else
    echo "No certbot log file found"
fi

echo ""
echo "🚨 8. Common Issues Analysis:"
echo "----------------------------"

# Check for common issues
issues_found=0

# Issue 1: Wrong certificate file
if [ -f "/etc/nginx/sites-available/potato" ]; then
    cert_path=$(grep "ssl_certificate " /etc/nginx/sites-available/potato | head -1 | awk '{print $2}' | tr -d ';')
    if [ ! -f "$cert_path" ]; then
        echo "❌ ISSUE: SSL certificate file not found: $cert_path"
        issues_found=$((issues_found + 1))
    fi
fi

# Issue 2: DNS mismatch
if [ "$DOMAIN_IP" != "$SERVER_IP" ] || [ "$WWW_IP" != "$SERVER_IP" ]; then
    echo "❌ ISSUE: DNS does not point to this server"
    echo "   Domain IP: $DOMAIN_IP, WWW IP: $WWW_IP, Server IP: $SERVER_IP"
    issues_found=$((issues_found + 1))
fi

# Issue 3: Certificate expired or invalid
if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    if ! sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -checkend 0 >/dev/null 2>&1; then
        echo "❌ ISSUE: Certificate has expired"
        issues_found=$((issues_found + 1))
    fi
fi

# Issue 4: Wrong domain in certificate
if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    if ! sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -text | grep -q "$DOMAIN"; then
        echo "❌ ISSUE: Certificate does not contain the domain $DOMAIN"
        issues_found=$((issues_found + 1))
    fi
fi

echo ""
echo "💡 9. Recommended Actions:"
echo "-------------------------"

if [ $issues_found -eq 0 ]; then
    echo "✅ No obvious issues found. The problem might be:"
    echo "   - Certificate chain incomplete"
    echo "   - Intermediate certificate missing"
    echo "   - Browser cache issues"
    echo ""
    echo "Try regenerating the certificate:"
    echo "   sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN --force-renewal"
else
    echo "Found $issues_found issue(s). Recommended actions:"
    echo ""
    echo "1. Fix DNS issues (if any) and wait for propagation"
    echo "2. Regenerate the certificate:"
    echo "   sudo certbot delete --cert-name $DOMAIN"
    echo "   sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN"
    echo "3. Restart nginx: sudo systemctl restart nginx"
fi

echo ""
echo "🔧 10. Quick Fix Commands:"
echo "-------------------------"
echo "# Delete existing certificate and recreate:"
echo "sudo certbot delete --cert-name $DOMAIN"
echo "sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN"
echo ""
echo "# Or force renewal:"
echo "sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN --force-renewal"
echo ""
echo "# Test configuration:"
echo "sudo nginx -t && sudo systemctl restart nginx"

echo ""
echo "Diagnosis complete! 🔍✅"
EOF