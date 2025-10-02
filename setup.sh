#!/bin/bash
# Auto Setup Script for RDP Bot

echo "🔥 Setting up RDP Windows Installer Bot..."

# Update system
echo "📦 Updating system..."
apt update && apt upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."
apt install -y python3 python3-pip git wget curl

# Clone or create project directory
if [ ! -d "rdp-bot" ]; then
    echo "📁 Creating project directory..."
    mkdir rdp-bot
fi

cd rdp-bot

# Create scripts directory
echo "📁 Creating scripts directory..."
mkdir -p scripts

# Download or create bot.py
if [ ! -f "bot.py" ]; then
    echo "📥 Downloading bot.py..."
    curl -o bot.py "https://raw.githubusercontent.com/example/rdp-bot/main/bot.py"
fi

# Create requirements.txt
echo "📦 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
python-telegram-bot==20.7
paramiko==3.4.0
requests==2.31.0
EOF

# Create windows_config.json
echo "📁 Creating windows_config.json..."
cat > windows_config.json << 'EOF'
{
  "server_2019": {
    "name": "Windows Server 2019",
    "script": "install_windows.sh",
    "size": "15GB",
    "notes": "Standard Edition"
  },
  "server_2022": {
    "name": "Windows Server 2022",
    "script": "install_windows.sh",
    "size": "16GB",
    "notes": "Standard Edition"
  },
  "win_10": {
    "name": "Windows 10 Pro",
    "script": "install_windows.sh",
    "size": "12GB",
    "notes": "22H2 Version"
  },
  "win_11": {
    "name": "Windows 11 Pro",
    "script": "install_windows.sh",
    "size": "13GB",
    "notes": "23H2 Version"
  }
}
EOF

# Create install_windows.sh
echo "📁 Creating install scripts..."
cat > scripts/install_windows.sh << 'EOF'
#!/bin/bash
# [Script content from above - shortened for example]
echo "Windows install script"
EOF

# Make scripts executable
chmod +x scripts/*.sh

# Install Python packages
echo "🐍 Installing Python packages..."
pip3 install -r requirements.txt

# Setup complete
echo ""
echo "🎉 SETUP COMPLETED!"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Edit bot.py and set your BOT_TOKEN"
echo "2. Run: python3 bot.py"
echo "3. Start your bot on Telegram"
echo ""
echo "🔧 Bot Token: Get from @BotFather"
echo "🌐 Support: @your_channel"
echo ""

# Make setup script executable
chmod +x setup.sh
