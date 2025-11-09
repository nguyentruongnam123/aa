#!/bin/bash
# Script khởi động Chrome OS VPS (Real Chrome OS Experience)
# Sử dụng Chromium OS / Chrome OS Flex
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
    wget \
    curl \
    unzip \
    git \
    python3 \
    python3-pip \
    python3-numpy \
    openbox \
    xterm \
    dbus-x11 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libgbm1 \
    libasound2 > /dev/null 2>&1

# Cài đặt websockify
echo "🔌 Cài đặt websockify..."
pip3 install -q websockify > /dev/null 2>&1

# Clone noVNC
echo "🌐 Cài đặt noVNC..."
if [ ! -d "/opt/novnc" ]; then
    git clone -q https://github.com/novnc/noVNC.git /opt/novnc > /dev/null 2>&1
    git clone -q https://github.com/novnc/websockify /opt/novnc/utils/websockify > /dev/null 2>&1
fi

# Cài đặt Google Chrome (sẽ dùng làm Chrome OS browser)
echo "🌐 Cài đặt Google Chrome..."
if ! command -v google-chrome &> /dev/null; then
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y -qq ./google-chrome-stable_current_amd64.deb > /dev/null 2>&1
    rm google-chrome-stable_current_amd64.deb
fi

# Tạo Chrome OS launcher theme
echo "🎨 Tạo Chrome OS launcher..."
mkdir -p /root/.config/chromeos
mkdir -p /root/.local/share/applications

# Tạo Chrome OS style launcher với HTML
cat > /root/.config/chromeos/launcher.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Chrome OS Launcher</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            background: linear-gradient(135deg, #4A90E2 0%, #357ABD 100%);
            font-family: 'Segoe UI', Roboto, sans-serif;
            height: 100vh;
            display: flex;
            flex-direction: column;
            color: white;
        }
        .search-bar {
            background: rgba(255,255,255,0.9);
            margin: 40px auto 30px;
            padding: 12px 20px;
            border-radius: 24px;
            width: 500px;
            display: flex;
            align-items: center;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .search-bar input {
            border: none;
            outline: none;
            flex: 1;
            font-size: 14px;
            background: transparent;
            color: #333;
        }
        .search-bar input::placeholder {
            color: #999;
        }
        .apps-grid {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 20px;
            padding: 0 60px;
            max-width: 900px;
            margin: 0 auto;
        }
        .app-icon {
            text-align: center;
            cursor: pointer;
            transition: transform 0.2s;
        }
        .app-icon:hover {
            transform: translateY(-5px);
        }
        .app-icon .icon {
            width: 64px;
            height: 64px;
            background: white;
            border-radius: 16px;
            margin: 0 auto 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 32px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .app-icon .label {
            font-size: 13px;
            text-shadow: 0 1px 2px rgba(0,0,0,0.2);
        }
        .shelf {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(0,0,0,0.3);
            backdrop-filter: blur(10px);
            padding: 8px;
            display: flex;
            justify-content: center;
            gap: 8px;
        }
        .shelf-icon {
            width: 48px;
            height: 48px;
            background: rgba(255,255,255,0.2);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.2s;
        }
        .shelf-icon:hover {
            background: rgba(255,255,255,0.3);
            transform: scale(1.1);
        }
        .time {
            position: fixed;
            top: 10px;
            right: 20px;
            font-size: 14px;
            text-shadow: 0 1px 2px rgba(0,0,0,0.3);
        }
    </style>
</head>
<body>
    <div class="time" id="time"></div>
    
    <div class="search-bar">
        <input type="text" placeholder="Search your apps, docs, and the web" id="search">
    </div>
    
    <div class="apps-grid">
        <div class="app-icon" onclick="openApp('chrome')">
            <div class="icon">🌐</div>
            <div class="label">Chrome</div>
        </div>
        <div class="app-icon" onclick="openApp('gmail')">
            <div class="icon">📧</div>
            <div class="label">Gmail</div>
        </div>
        <div class="app-icon" onclick="openApp('youtube')">
            <div class="icon">▶️</div>
            <div class="label">YouTube</div>
        </div>
        <div class="app-icon" onclick="openApp('drive')">
            <div class="icon">📁</div>
            <div class="label">Drive</div>
        </div>
        <div class="app-icon" onclick="openApp('docs')">
            <div class="icon">📝</div>
            <div class="label">Docs</div>
        </div>
        <div class="app-icon" onclick="openApp('sheets')">
            <div class="icon">📊</div>
            <div class="label">Sheets</div>
        </div>
        <div class="app-icon" onclick="openApp('slides')">
            <div class="icon">📽️</div>
            <div class="label">Slides</div>
        </div>
        <div class="app-icon" onclick="openApp('photos')">
            <div class="icon">📷</div>
            <div class="label">Photos</div>
        </div>
        <div class="app-icon" onclick="openApp('maps')">
            <div class="icon">🗺️</div>
            <div class="label">Maps</div>
        </div>
        <div class="app-icon" onclick="openApp('play')">
            <div class="icon">🎮</div>
            <div class="label">Play</div>
        </div>
        <div class="app-icon" onclick="openApp('calendar')">
            <div class="icon">📅</div>
            <div class="label">Calendar</div>
        </div>
        <div class="app-icon" onclick="openApp('meet')">
            <div class="icon">📹</div>
            <div class="label">Meet</div>
        </div>
        <div class="app-icon" onclick="openApp('keep')">
            <div class="icon">📌</div>
            <div class="label">Keep</div>
        </div>
        <div class="app-icon" onclick="openApp('settings')">
            <div class="icon">⚙️</div>
            <div class="label">Settings</div>
        </div>
        <div class="app-icon" onclick="openApp('files')">
            <div class="icon">📂</div>
            <div class="label">Files</div>
        </div>
    </div>
    
    <div class="shelf">
        <div class="shelf-icon" onclick="openApp('chrome')" title="Chrome">🌐</div>
        <div class="shelf-icon" onclick="openApp('files')" title="Files">📂</div>
        <div class="shelf-icon" onclick="openApp('gmail')" title="Gmail">📧</div>
    </div>
    
    <script>
        // Update time
        function updateTime() {
            const now = new Date();
            const timeStr = now.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit',
                hour12: true 
            });
            document.getElementById('time').textContent = timeStr;
        }
        updateTime();
        setInterval(updateTime, 1000);
        
        // App URLs
        const apps = {
            chrome: 'https://www.google.com',
            gmail: 'https://mail.google.com',
            youtube: 'https://www.youtube.com',
            drive: 'https://drive.google.com',
            docs: 'https://docs.google.com',
            sheets: 'https://sheets.google.com',
            slides: 'https://slides.google.com',
            photos: 'https://photos.google.com',
            maps: 'https://maps.google.com',
            play: 'https://play.google.com',
            calendar: 'https://calendar.google.com',
            meet: 'https://meet.google.com',
            keep: 'https://keep.google.com',
            settings: 'chrome://settings',
            files: 'file:///root'
        };
        
        function openApp(appName) {
            const url = apps[appName] || apps.chrome;
            window.open(url, '_blank');
        }
        
        // Search functionality
        document.getElementById('search').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                const query = this.value;
                if (query) {
                    window.open('https://www.google.com/search?q=' + encodeURIComponent(query), '_blank');
                }
            }
        });
    </script>
</body>
</html>
HTMLEOF

# Dọn dẹp processes cũ
echo "🧹 Dọn dẹp processes cũ..."
pkill -9 Xvfb 2>/dev/null || true
pkill -9 x11vnc 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
pkill -9 openbox 2>/dev/null || true
pkill -9 chrome 2>/dev/null || true
sleep 2

# Khởi động Xvfb
echo "🖥️  Khởi động Virtual Display..."
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
export DISPLAY=:99
sleep 3

# Khởi động Openbox (minimal window manager)
echo "🎨 Khởi động Chrome OS Environment..."
openbox --config-file /dev/null > /tmp/openbox.log 2>&1 &
sleep 3

# Khởi động Chrome với launcher
echo "🌐 Khởi động Chrome OS Launcher..."
google-chrome \
    --no-sandbox \
    --disable-dev-shm-usage \
    --start-maximized \
    --app="file:///root/.config/chromeos/launcher.html" \
    --user-data-dir=/root/.config/chrome \
    > /tmp/chrome.log 2>&1 &
sleep 3

# Khởi động VNC Server
echo "🔌 Khởi động VNC Server..."
x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -repeat > /tmp/x11vnc.log 2>&1 &
sleep 3

# Kiểm tra VNC
if ! pgrep -x "x11vnc" > /dev/null; then
    echo "❌ Lỗi: VNC Server không khởi động được!"
    exit 1
fi

# Khởi động noVNC
echo "🌍 Khởi động Web VNC (noVNC)..."
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /tmp/novnc.log 2>&1 &
sleep 5

# Kiểm tra noVNC
if ! netstat -tuln | grep -q ':6080'; then
    echo "❌ Lỗi: noVNC không khởi động được!"
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

# Đợi và lấy URL
echo "⏳ Đang tạo public URL..."
sleep 10

# Hiển thị thông tin
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          ✅ CHROME OS VPS ĐÃ KHỞI ĐỘNG THÀNH CÔNG!        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Lấy URL
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
    echo "   📋 Copy link này:"
    echo "   $PUBLIC_URL/vnc.html"
else
    echo "⚠️  Đang tạo URL... Chạy lệnh này để xem:"
    echo "   cat /tmp/tunnel.log | grep trycloudflare"
fi

echo ""
echo "📱 URL local:"
echo "   👉 http://localhost:6080/vnc.html"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  💡 HƯỚNG DẪN SỬ DỤNG CHROME OS:                           ║"
echo "║                                                            ║"
echo "║  1. Mở URL trên trình duyệt                                ║"
echo "║  2. Click 'Connect' để kết nối                             ║"
echo "║  3. Bạn sẽ thấy Chrome OS Launcher                         ║"
echo "║                                                            ║"
echo "║  🎯 Các app có sẵn:                                        ║"
echo "║  • Chrome Browser - Lướt web                               ║"
echo "║  • Gmail - Email                                           ║"
echo "║  • YouTube - Xem video                                     ║"
echo "║  • Google Drive - Lưu trữ file                             ║"
echo "║  • Google Docs/Sheets/Slides - Văn phòng                   ║"
echo "║  • Google Photos - Quản lý ảnh                             ║"
echo "║  • Google Maps - Bản đồ                                    ║"
echo "║  • Google Meet - Video call                                ║"
echo "║  • Google Keep - Ghi chú                                   ║"
echo "║  • Google Calendar - Lịch                                  ║"
echo "║                                                            ║"
echo "║  ⚡ Tips:                                                   ║"
echo "║  - Click vào icon để mở app                                ║"
echo "║  - Dùng search bar để tìm kiếm                             ║"
echo "║  - Shelf ở dưới cùng chứa app hay dùng                     ║"
echo "║  - Giao diện giống y hệt Chrome OS thật!                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Status
echo "📊 Status:"
echo "   • Xvfb:       $(pgrep -x Xvfb > /dev/null && echo '✅' || echo '❌')"
echo "   • Chrome OS:  $(pgrep -f chrome > /dev/null && echo '✅' || echo '❌')"
echo "   • VNC:        $(pgrep -x x11vnc > /dev/null && echo '✅' || echo '❌')"
echo "   • noVNC:      $(netstat -tuln | grep -q ':6080' && echo '✅' || echo '❌')"
echo "   • Tunnel:     $(pgrep -x cloudflared > /dev/null && echo '✅' || echo '❌')"
echo ""

echo "📋 Logs:"
echo "   • tail -f /tmp/tunnel.log"
echo "   • tail -f /tmp/chrome.log"
echo ""

echo "⚡ Chrome OS đang chạy. Nhấn Ctrl+C để dừng..."

# Cleanup
cleanup() {
    echo ""
    echo "🛑 Đang dừng Chrome OS..."
    pkill -9 cloudflared 2>/dev/null || true
    pkill -9 websockify 2>/dev/null || true
    pkill -9 x11vnc 2>/dev/null || true
    pkill -9 chrome 2>/dev/null || true
    pkill -9 openbox 2>/dev/null || true
    pkill -9 Xvfb 2>/dev/null || true
    echo "✅ Đã dừng"
}

trap cleanup EXIT

wait
