#!/bin/bash
# Setup Node.js Communication Layer for ai-trading-machine

set -e

echo "🔧 Setting up SjAgent Communication Layer"
echo "========================================"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ NPM version: $(npm --version)"

# Navigate to communication directory
cd "$(dirname "$0")"

# Install dependencies
echo "📦 Installing Node.js dependencies..."
npm install

# Copy environment file
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✅ Created .env file from template"
    echo "⚠️  Please edit .env file with your configuration"
fi

# Create logs directory
mkdir -p logs

echo ""
echo "🎉 SjAgent Communication Layer setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env file with your configuration"
echo "2. Start the server: npm start"
echo "3. Open browser: http://localhost:3000"
echo "4. Test WebSocket connection"
echo ""
echo "🚀 Ready for real-time cluster communication!"