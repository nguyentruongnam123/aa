#!/bin/bash
# Script khởi động Chrome OS VPS đơn giản
# Có thể chạy trên Colab, GitHub Actions, hoặc VPS Linux

set -e

echo "🔧 Đang cài đặt Chrome OS VPS..."

# Update system
apt-get update -qq > /dev/null 2>&1

# Cài đặt dependencies
echo "📦 Cài đặt packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    xfce4 \
    xfce4-terminal \
    wget \
    curl \
    unzip > /dev/null 2>&1

# Cài đặt Chrome
echo "🌐 Cài đặt Google Chrome..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt-get install -y -qq ./google-chrome-stable_current_amd64.deb > /dev/null 2>&1
rm google-chrome-stable_current_amd64.deb

# Khởi động Xvfb
echo "🖥️  Khởi động Virtual Display..."
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
sleep 2

# Khởi động Desktop Environment
echo "🎨 Khởi động Desktop..."
DISPLAY=:99 startxfce4 > /dev/null 2>&1 &
sleep 3

# Khởi động VNC Server
echo "🔌 Khởi động VNC Server..."
x11vnc -display :99 -nopw -listen 0.0.0.0 -forever -shared -bg -o /tmp/x11vnc.log

# Khởi động noVNC
echo "🌍 Khởi động Web VNC..."
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /dev/null 2>&1 &
sleep 3

# Cài đặt Cloudflare Tunnel
echo "☁️  Cài đặt Cloudflare Tunnel..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1
rm cloudflared-linux-amd64.deb

# Khởi động Tunnel
echo "🚀 Khởi động Public Tunnel..."
cloudflared tunnel --url http://localhost:6080 > /tmp/tunnel.log 2>&1 &

# Đợi tunnel khởi động
sleep 8

# Hiển thị thông tin
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          ✅ CHROME OS VPS ĐÃ KHỞI ĐỘNG THÀNH CÔNG!        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 URL công khai (Cloudflare Tunnel):"
echo ""

# Lấy URL từ log
if [ -f /tmp/tunnel.log ]; then
    PUBLIC_URL=$(grep -o 'https://.*\.trycloudflare.com' /tmp/tunnel.log | head -1)
    if [ ! -z "$PUBLIC_URL" ]; then
        echo "   👉 $PUBLIC_URL/vnc.html"
        echo ""
        echo "   Hoặc copy link này:"
        echo "   $PUBLIC_URL/vnc.html"
    else
        echo "   ⏳ Đang tạo URL, vui lòng đợi..."
        echo "   Kiểm tra file: cat /tmp/tunnel.log"
    fi
fi

echo ""
echo "📱 URL local (nếu chạy trên máy của bạn):"
echo "   👉 http://localhost:6080/vnc.html"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  💡 HƯỚNG DẪN SỬ DỤNG:                                     ║"
echo "║  1. Mở URL trên trình duyệt                                ║"
echo "║  2. Click 'Connect' để kết nối                             ║"
echo "║  3. Sử dụng Chrome browser trong desktop                   ║"
echo "║  4. File Manager: Menu > System > File Manager             ║"
echo "║  5. Terminal: Menu > System > Terminal                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Kiểm tra log nếu cần
echo "📋 Log files:"
echo "   - Tunnel: tail -f /tmp/tunnel.log"
echo "   - VNC: tail -f /tmp/x11vnc.log"
echo ""

# Giữ script chạy
echo "⚡ VPS đang chạy. Nhấn Ctrl+C để dừng..."
wait
