# ============================================================
# CHẠY CODE NÀY TRỰC TIẾP TRÊN GOOGLE COLAB
# Không cần tải file, copy/paste và chạy!
# ============================================================

print("🚀 Đang khởi động Windows 7 VM...")
print("=" * 60)

# Tạo bash script inline
bash_script = """#!/bin/bash
set -e

echo "📦 Installing packages..."
apt-get update -qq > /dev/null 2>&1

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    qemu-system-x86 \
    qemu-utils \
    wget \
    curl \
    git \
    python3-pip \
    net-tools > /dev/null 2>&1

echo "🔌 Installing websockify..."
pip3 install -q websockify > /dev/null 2>&1

echo "🌐 Installing noVNC..."
if [ ! -d "/opt/novnc" ]; then
    git clone -q https://github.com/novnc/noVNC.git /opt/novnc
    git clone -q https://github.com/novnc/websockify /opt/novnc/utils/websockify
fi

echo "💾 Setting up Windows 7..."
mkdir -p /root/win7vm
cd /root/win7vm

# Download Windows 7 ISO
if [ ! -f "win7.iso" ]; then
    echo "📥 Downloading Tiny Windows 7 (700MB)..."
    wget -q --show-progress -O win7.iso \
        "https://archive.org/download/tiny-7-rev-01/Tiny7Rev01.iso"
fi

# Create disk
if [ ! -f "win7.qcow2" ]; then
    echo "💿 Creating 20GB virtual disk..."
    qemu-img create -f qcow2 win7.qcow2 20G > /dev/null 2>&1
fi

# Kill old processes
pkill -9 qemu-system 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
sleep 2

# Calculate RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
VM_RAM=$((TOTAL_RAM * 60 / 100))
[ $VM_RAM -gt 3072 ] && VM_RAM=3072
[ $VM_RAM -lt 1536 ] && VM_RAM=1536

echo "🖥️ Starting Windows 7 VM (${VM_RAM}MB RAM)..."

# Check if installed
BOOT_OPT="-cdrom win7.iso -boot d"
[ -f "installed.flag" ] && BOOT_OPT=""

# Start QEMU
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 2 \
    -m ${VM_RAM}M \
    -drive file=win7.qcow2,format=qcow2,if=virtio \
    $BOOT_OPT \
    -vnc 0.0.0.0:0 \
    -device VGA,vgamem_mb=64 \
    -net nic,model=rtl8139 \
    -net user \
    -rtc base=localtime \
    -usb -device usb-tablet \
    > /tmp/qemu.log 2>&1 &

QEMU_PID=$!
echo $QEMU_PID > /tmp/qemu.pid
sleep 5

if ! ps -p $QEMU_PID > /dev/null; then
    echo "❌ QEMU failed!"
    exit 1
fi

echo "✅ QEMU started (PID: $QEMU_PID)"

# Start noVNC
echo "🌍 Starting noVNC..."
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /tmp/novnc.log 2>&1 &
sleep 5

# Install Cloudflare
if ! command -v cloudflared &> /dev/null; then
    echo "☁️ Installing Cloudflare..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1
    rm cloudflared-linux-amd64.deb
fi

echo "🚀 Starting tunnel..."
cloudflared tunnel --url http://localhost:6080 > /tmp/tunnel.log 2>&1 &
sleep 15

# Get URL
PUBLIC_URL=""
for i in {1..30}; do
    [ -f /tmp/tunnel.log ] && PUBLIC_URL=$(grep -o 'https://.*\.trycloudflare.com' /tmp/tunnel.log | head -1)
    [ ! -z "$PUBLIC_URL" ] && break
    sleep 1
done

# Output result
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         ✅ WINDOWS 7 VM ĐÃ KHỞI ĐỘNG THÀNH CÔNG!          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ ! -z "$PUBLIC_URL" ]; then
    echo "🌐 URL công khai:"
    echo ""
    echo "   👉 $PUBLIC_URL/vnc.html"
    echo ""
    echo "   Copy link trên vào trình duyệt!"
else
    echo "⚠️ Chưa lấy được URL. Kiểm tra:"
    echo "   cat /tmp/tunnel.log | grep trycloudflare"
fi

echo ""
echo "📱 Local: http://localhost:6080/vnc.html"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  💡 HƯỚNG DẪN:                                              ║"
echo "║  1. Mở URL → Click Connect                                 ║"
echo "║  2. Lần đầu: Cài Windows 7 (10-15 phút)                    ║"
echo "║  3. Sau khi cài xong:                                      ║"
echo "║     !touch /root/win7vm/installed.flag                     ║"
echo "║  4. Lần sau sẽ boot thẳng vào Windows!                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Status:"
echo "   • QEMU:   $(ps -p $QEMU_PID >/dev/null && echo '✅' || echo '❌')"
echo "   • VNC:    $(netstat -tuln | grep -q ':5900' && echo '✅' || echo '❌')"
echo "   • noVNC:  $(netstat -tuln | grep -q ':6080' && echo '✅' || echo '❌')"
echo "   • Tunnel: $(pgrep cloudflared >/dev/null && echo '✅' || echo '❌')"
echo ""
echo "⚡ VM đang chạy trong background!"
"""

# Lưu script vào file
import os
with open('/tmp/win7_setup.sh', 'w') as f:
    f.write(bash_script)

os.chmod('/tmp/win7_setup.sh', 0o755)

print("✅ Script đã tạo xong!")
print("🔄 Đang chạy script...")
print("=" * 60)
print()

# Chạy script
import subprocess
import time

# Chạy và hiển thị output real-time
process = subprocess.Popen(
    ['bash', '/tmp/win7_setup.sh'],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True
)

# Đọc output
for line in process.stdout:
    print(line, end='')

process.wait()

print()
print("=" * 60)
print("✅ Hoàn tất! Kiểm tra URL ở trên để truy cập Windows 7!")
print()
print("📌 Lệnh hữu ích:")
print("   • Xem log QEMU:   !cat /tmp/qemu.log")
print("   • Xem log tunnel: !cat /tmp/tunnel.log")
print("   • Xem PID:        !cat /tmp/qemu.pid")
print("   • Dừng VM:        !kill $(cat /tmp/qemu.pid)")
