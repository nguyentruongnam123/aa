#!/bin/bash
# Windows 7 VM cho Google Colab - Fixed PTY issue
# Chạy trong background, không cần PTY

set -e

# Redirect tất cả output để không cần PTY
exec 1>/tmp/install.log 2>&1

echo "Starting Windows 7 VM installation..."

# Update system
apt-get update -qq

# Install packages
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    qemu-system-x86 \
    qemu-utils \
    curl \
    wget \
    git \
    python3-pip \
    net-tools

# Install websockify
pip3 install -q websockify

# Clone noVNC
if [ ! -d "/opt/novnc" ]; then
    git clone -q https://github.com/novnc/noVNC.git /opt/novnc
    git clone -q https://github.com/novnc/websockify /opt/novnc/utils/websockify
fi

# Create directory
mkdir -p /root/win7vm
cd /root/win7vm

# Download Tiny Windows 7 ISO (700MB)
if [ ! -f "win7.iso" ]; then
    echo "Downloading Windows 7 ISO..."
    wget -q -O win7.iso "https://archive.org/download/tiny-7-rev-01/Tiny7Rev01.iso" || exit 1
fi

# Create virtual disk
if [ ! -f "win7.qcow2" ]; then
    qemu-img create -f qcow2 win7.qcow2 20G
fi

# Kill old processes
pkill -9 qemu-system 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
sleep 2

# Get RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
VM_RAM=$((TOTAL_RAM * 60 / 100))
if [ $VM_RAM -gt 3072 ]; then
    VM_RAM=3072
fi
if [ $VM_RAM -lt 1536 ]; then
    VM_RAM=1536
fi

# Start QEMU
echo "Starting Windows 7 VM with ${VM_RAM}MB RAM..."

# Check if Windows is installed
if [ -f "installed.flag" ]; then
    BOOT_OPT=""
else
    BOOT_OPT="-cdrom win7.iso -boot d"
fi

nohup qemu-system-x86_64 \
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

# Check QEMU
if ! ps -p $QEMU_PID > /dev/null 2>&1; then
    echo "QEMU failed to start!"
    cat /tmp/qemu.log
    exit 1
fi

# Start noVNC
nohup /opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /tmp/novnc.log 2>&1 &
sleep 5

# Install Cloudflare Tunnel
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
fi

# Start Cloudflare Tunnel
nohup cloudflared tunnel --url http://localhost:6080 > /tmp/tunnel.log 2>&1 &
sleep 10

# Save info to status file
cat > /tmp/vm_status.txt << EOF
╔════════════════════════════════════════════════════════════╗
║           ✅ WINDOWS 7 VM ĐÃ KHỞI ĐỘNG THÀNH CÔNG!        ║
╚════════════════════════════════════════════════════════════╝

🌐 URL truy cập:
EOF

# Get Cloudflare URL
for i in {1..30}; do
    if [ -f /tmp/tunnel.log ]; then
        PUBLIC_URL=$(grep -o 'https://.*\.trycloudflare.com' /tmp/tunnel.log | head -1)
        if [ ! -z "$PUBLIC_URL" ]; then
            echo "" >> /tmp/vm_status.txt
            echo "   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" >> /tmp/vm_status.txt
            echo "   ┃  👉 $PUBLIC_URL/vnc.html" >> /tmp/vm_status.txt
            echo "   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" >> /tmp/vm_status.txt
            break
        fi
    fi
    sleep 1
done

cat >> /tmp/vm_status.txt << EOF

📱 Local URL: http://localhost:6080/vnc.html

╔════════════════════════════════════════════════════════════╗
║  💡 HƯỚNG DẪN:                                              ║
║                                                            ║
║  1. Mở URL trên → Click "Connect"                          ║
║  2. Nếu lần đầu: Cài Windows 7 (10-15 phút)                ║
║  3. Nếu đã cài: Login và sử dụng                           ║
║                                                            ║
║  📌 Sau khi cài xong Windows, chạy lệnh:                   ║
║     touch /root/win7vm/installed.flag                      ║
║                                                            ║
║  ⚡ Tips:                                                   ║
║  • Cài Windows như bình thường                             ║
║  • Chọn Custom installation                                ║
║  • Format disk và install                                  ║
║  • Bỏ qua Product Key                                      ║
╚════════════════════════════════════════════════════════════╝

📊 VM Info:
   • Windows 7 VM
   • RAM: ${VM_RAM}MB
   • Disk: 20GB
   • CPU: 2 cores
   • QEMU PID: $QEMU_PID

📊 Status:
   • QEMU:   $(ps -p $QEMU_PID >/dev/null && echo '✅ Running' || echo '❌ Stopped')
   • VNC:    $(netstat -tuln 2>/dev/null | grep -q ':5900' && echo '✅ Running' || echo '❌ Stopped')
   • noVNC:  $(netstat -tuln 2>/dev/null | grep -q ':6080' && echo '✅ Running' || echo '❌ Stopped')
   • Tunnel: $(pgrep cloudflared >/dev/null && echo '✅ Running' || echo '❌ Stopped')

📋 Log files:
   • Installation: cat /tmp/install.log
   • QEMU:        cat /tmp/qemu.log
   • Tunnel:      cat /tmp/tunnel.log
   • noVNC:       cat /tmp/novnc.log

⚡ VM đang chạy trong background!
   Để xem thông tin: cat /tmp/vm_status.txt
   Để dừng VM: kill $(cat /tmp/qemu.pid)
EOF

# Output to stdout for Colab
cat /tmp/vm_status.txt

echo ""
echo "✅ Script completed! VM is running in background."
echo "   Check /tmp/vm_status.txt for URL and info."
