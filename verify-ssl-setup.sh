#!/bin/bash

# Verify existing SSL setup for musicscience.uk
# Run this on your DigitalOcean droplet

set -e

DOMAIN="musicscience.uk"
WWW_DOMAIN="www.musicscience.uk"

echo "🔍 Verifying SSL setup for $DOMAIN"
echo "=================================="

echo ""
echo "📋 1. Certificate Status:"
echo "-------------------------"
sudo certbot certificates

echo ""
echo "📄 2. Certificate Details:"
echo "-------------------------"
if [ -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" ]; then
    echo "✅ Certificate file exists"
    echo "Certificate details:"
    sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -text | grep -A 2 "Subject:"
    echo ""
    echo "Expiration date:"
    sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -enddate
    echo ""
    echo "Subject Alternative Names:"
    sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -text | grep -A 1 "Subject Alternative Name" || echo "None found"
else
    echo "❌ Certificate file not found"
fi

echo ""
echo "🌐 3. Nginx Configuration:"
echo "-------------------------"
echo "Current Nginx config for Potato:"
if [ -f "/etc/nginx/sites-available/potato" ]; then
    echo "✅ Potato Nginx config exists"
    
    # Check if SSL is configured
    if grep -q "ssl_certificate" /etc/nginx/sites-available/potato; then
        echo "✅ SSL is configured in Nginx"
        echo ""
        echo "SSL certificate paths:"
        grep "ssl_certificate" /etc/nginx/sites-available/potato
    else
        echo "❌ SSL not configured in Nginx"
    fi
    
    echo ""
    echo "Server names configured:"
    grep "server_name" /etc/nginx/sites-available/potato || echo "No server names found"
    
    echo ""
    echo "Listen directives:"
    grep "listen" /etc/nginx/sites-available/potato || echo "No listen directives found"
    
else
    echo "❌ Potato Nginx config not found"
fi

echo ""
echo "🧪 4. Testing Nginx Configuration:"
echo "---------------------------------"
if sudo nginx -t; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration has errors"
fi

echo ""
echo "🔥 5. Firewall Status:"
echo "---------------------"
sudo ufw status | grep -E "(443|80)" || echo "HTTPS/HTTP ports not in firewall rules"

echo ""
echo "📊 6. Service Status:"
echo "--------------------"
echo "Nginx: $(sudo systemctl is-active nginx)"
echo "Potato: $(sudo systemctl is-active potato)"

echo ""
echo "🌐 7. Testing HTTPS Connection:"
echo "------------------------------"
echo "Testing connection to $DOMAIN..."
if timeout 10 curl -I "https://$DOMAIN" 2>/dev/null | head -1; then
    echo "✅ HTTPS connection successful"
else
    echo "❌ HTTPS connection failed"
fi

echo ""
echo "Testing connection to $WWW_DOMAIN..."
if timeout 10 curl -I "https://$WWW_DOMAIN" 2>/dev/null | head -1; then
    echo "✅ HTTPS connection successful"
else
    echo "❌ HTTPS connection failed"
fi

echo ""
echo "🔄 8. Auto-renewal Status:"
echo "-------------------------"
echo "Certbot timer status:"
if systemctl is-active --quiet certbot.timer; then
    echo "✅ Auto-renewal timer is active"
    echo "Next renewal check:"
    systemctl list-timers certbot.timer --no-pager | grep certbot || echo "Timer info not available"
else
    echo "❌ Auto-renewal timer is not active"
fi

echo ""
echo "Testing renewal (dry run):"
if sudo certbot renew --dry-run >/dev/null 2>&1; then
    echo "✅ Renewal test passed"
else
    echo "❌ Renewal test failed"
fi

echo ""
echo "💡 9. Recommendations:"
echo "---------------------"

# Check if server_name matches the domain
if grep -q "server_name.*$DOMAIN" /etc/nginx/sites-available/potato; then
    echo "✅ Domain is configured in Nginx"
else
    echo "⚠️  Consider updating Nginx server_name to include $DOMAIN"
fi

# Check if both domains are in the certificate
if sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -text 2>/dev/null | grep -q "$WWW_DOMAIN"; then
    echo "✅ Both $DOMAIN and $WWW_DOMAIN are in the certificate"
else
    echo "⚠️  Check if both domains are properly configured"
fi

echo ""
echo "🎯 Next Steps:"
echo "-------------"
echo "1. Visit https://$DOMAIN to test your annotation tool"
echo "2. Visit https://$WWW_DOMAIN to test the www version"
echo "3. Check for any mixed content warnings in browser console"
echo "4. Consider running SSL security test: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"

echo ""
echo "Verification complete! 🔒✅"
EOF