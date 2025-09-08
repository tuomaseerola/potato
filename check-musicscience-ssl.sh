#!/bin/bash

# Quick SSL status check for musicscience.uk
# Run this on your DigitalOcean droplet

echo "🔍 Quick SSL Status Check for musicscience.uk"
echo "============================================="

echo ""
echo "📋 Certificate Status:"
echo "---------------------"
sudo certbot certificates | grep -A 10 "musicscience.uk" || echo "No certificates found for musicscience.uk"

echo ""
echo "🌐 HTTPS Test:"
echo "-------------"
echo "Testing https://musicscience.uk..."
if curl -I https://musicscience.uk 2>/dev/null | head -1; then
    echo "✅ HTTPS working"
else
    echo "❌ HTTPS not working"
fi

echo ""
echo "Testing https://www.musicscience.uk..."
if curl -I https://www.musicscience.uk 2>/dev/null | head -1; then
    echo "✅ WWW HTTPS working"
else
    echo "❌ WWW HTTPS not working"
fi

echo ""
echo "🔄 HTTP Redirect Test:"
echo "---------------------"
echo "Testing HTTP to HTTPS redirect..."
if curl -I http://musicscience.uk 2>/dev/null | grep -q "301\|302"; then
    echo "✅ HTTP redirects to HTTPS"
else
    echo "❌ HTTP redirect not working"
fi

echo ""
echo "📊 Services:"
echo "-----------"
echo "Nginx: $(sudo systemctl is-active nginx)"
echo "Potato: $(sudo systemctl is-active potato)"

echo ""
echo "🎯 Your annotation tool should be accessible at:"
echo "  https://musicscience.uk/annotation"
echo "  https://www.musicscience.uk/annotation"

echo ""
echo "💡 For detailed analysis, run: ./verify-ssl-setup.sh"
echo "🔧 To optimize SSL settings, run: ./optimize-existing-ssl.sh"
EOF