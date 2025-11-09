#!/bin/bash
# Script khởi động Chrome OS VPS - FIXED VERSION
# Có thể chạy trên Colab, GitHub Actions, hoặc VPS Linux

set -e

echo "🔧 Đang cài đặt Chrome OS VPS..."

# Update system
apt-get update -qq > /dev/null 2>&1

# Cài đặt dependencies cơ bản
echo "📦 Cài đặt packages cơ bản..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    xvfb \
    x11vnc \
    xfce4 \
    xfce4-terminal \
    wget \
    curl \
    unzip \
    git \
    python3 \
    python3-pip \
    python3-numpy > /dev/null 2>&1

# Cài đặt websockify từ pip (quan trọng!)
echo "🔌 Cài đặt websockify..."
pip3 install -q websockify > /dev/null 2>&1

# Clone noVNC từ GitHub (cách đúng để cài noVNC)
echo "🌐 Cài đặt noVNC..."
if [ ! -d "/opt/novnc" ]; then
    git clone -q https://github.com/novnc/noVNC.git /opt/novnc > /dev/null 2>&1
    git clone -q https://github.com/novnc/websockify /opt/novnc/utils/websockify > /dev/null 2>&1
fi

# Cài đặt Chrome
echo "🌐 Cài đặt Google Chrome..."
if ! command -v google-chrome &> /dev/null; then
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y -qq ./google-chrome-stable_current_amd64.deb > /dev/null 2>&1
    rm google-chrome-stable_current_amd64.deb
fi

# Dọn dẹp các process cũ nếu có
echo "🧹 Dọn dẹp processes cũ..."
pkill -9 Xvfb 2>/dev/null || true
pkill -9 x11vnc 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
pkill -9 startxfce4 2>/dev/null || true
sleep 2

# Khởi động Xvfb
echo "🖥️  Khởi động Virtual Display..."
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
export DISPLAY=:99
sleep 3

# Khởi động Desktop Environment
echo "🎨 Khởi động Desktop Environment..."
startxfce4 > /dev/null 2>&1 &
sleep 5

# Khởi động VNC Server
echo "🔌 Khởi động VNC Server..."
x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -repeat > /tmp/x11vnc.log 2>&1 &
sleep 3

# Kiểm tra VNC đã chạy chưa
if ! pgrep -x "x11vnc" > /dev/null; then
    echo "❌ Lỗi: VNC Server không khởi động được!"
    exit 1
fi

# Khởi động noVNC với websockify
echo "🌍 Khởi động Web VNC (noVNC)..."
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /tmp/novnc.log 2>&1 &
sleep 5

# Kiểm tra noVNC đã chạy chưa
if ! netstat -tuln | grep -q ':6080'; then
    echo "❌ Lỗi: noVNC không khởi động được!"
    echo "📋 Log noVNC:"
    cat /tmp/novnc.log
    exit 1
fi

# Cài đặt Cloudflare Tunnel
echo "☁️  Cài đặt Cloudflare Tunnel..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1
    rm cloudflared-linux-amd64.deb
fi

# Khởi động Tunnel
echo "🚀 Khởi động Public Tunnel..."
cloudflared tunnel --url http://localhost:6080 > /tmp/tunnel.log 2>&1 &

# Đợi tunnel khởi động và lấy URL
echo "⏳ Đang tạo public URL..."
sleep 10

# Hiển thị thông tin
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          ✅ CHROME OS VPS ĐÃ KHỞI ĐỘNG THÀNH CÔNG!        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Lấy URL từ log với retry
PUBLIC_URL=""
for i in {1..20}; do
    if [ -f /tmp/tunnel.log ]; then
        PUBLIC_URL=$(grep -o 'https://.*\.trycloudflare.com' /tmp/tunnel.log | head -1)
        if [ ! -z "$PUBLIC_URL" ]; then
            break
        fi
    fi
    sleep 1
done

if [ ! -z "$PUBLIC_URL" ]; then
    echo "🌐 URL công khai (Cloudflare Tunnel):"
    echo ""
    echo "   ┌────────────────────────────────────────────────────┐"
    echo "   │  👉 $PUBLIC_URL/vnc.html"
    echo "   └────────────────────────────────────────────────────┘"
    echo ""
    echo "   📋 Copy link này vào trình duyệt:"
    echo "   $PUBLIC_URL/vnc.html"
else
    echo "⚠️  Chưa lấy được public URL, kiểm tra log:"
    echo "   cat /tmp/tunnel.log"
    echo ""
    echo "   Hoặc sử dụng local URL nếu bạn đang chạy local:"
fi

echo ""
echo "📱 URL local (nếu chạy trên máy của bạn):"
echo "   👉 http://localhost:6080/vnc.html"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  💡 HƯỚNG DẪN SỬ DỤNG:                                     ║"
echo "║                                                            ║"
echo "║  1. Mở URL trên trình duyệt                                ║"
echo "║  2. Click 'Connect' để kết nối                             ║"
echo "║  3. Bạn sẽ thấy desktop XFCE4                              ║"
echo "║  4. Mở Chrome: Applications > Web Browser                  ║"
echo "║  5. File Manager: Applications > File Manager              ║"
echo "║  6. Terminal: Applications > Terminal Emulator             ║"
echo "║                                                            ║"
echo "║  ⚡ Tips:                                                   ║"
echo "║  - Nhấn F11 để fullscreen                                  ║"
echo "║  - Clipboard có thể copy/paste giữa local và remote        ║"
echo "║  - Right-click để mở menu                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Hiển thị status
echo "📊 Status các services:"
echo "   • Xvfb (Display):  $(pgrep -x Xvfb > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   • XFCE4 (Desktop): $(pgrep -f startxfce4 > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   • x11vnc (VNC):    $(pgrep -x x11vnc > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   • noVNC (Web):     $(netstat -tuln | grep -q ':6080' && echo '✅ Running on :6080' || echo '❌ Not running')"
echo "   • Cloudflared:     $(pgrep -x cloudflared > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo ""

# Log files
echo "📋 Log files để debug:"
echo "   • Tunnel log:  tail -f /tmp/tunnel.log"
echo "   • VNC log:     tail -f /tmp/x11vnc.log"
echo "   • noVNC log:   tail -f /tmp/novnc.log"
echo ""

# Giữ script chạy
echo "⚡ VPS đang chạy. Nhấn Ctrl+C để dừng..."
echo "   (Script sẽ tự động cleanup khi dừng)"
echo ""

# Trap để cleanup khi exit
cleanup() {
    echo ""
    echo "🛑 Đang dừng services..."
    pkill -9 cloudflared 2>/dev/null || true
    pkill -9 websockify 2>/dev/null || true
    pkill -9 x11vnc 2>/dev/null || true
    pkill -9 startxfce4 2>/dev/null || true
    pkill -9 Xvfb 2>/dev/null || true
    echo "✅ Đã dừng tất cả services"
}

trap cleanup EXIT

# Keep running
wait
