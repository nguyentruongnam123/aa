#!/bin/bash
# Script chạy Windows 7 THẬT 100% trên VPS
# Sử dụng QEMU với Windows 7 pre-installed image

set -e

echo "🪟 Đang khởi động Windows 7 Real VM..."

# Kiểm tra RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 3000 ]; then
    echo "⚠️  Cảnh báo: RAM thấp (${TOTAL_RAM}MB). Cần ít nhất 3GB!"
    echo "   Có thể chạy nhưng sẽ rất chậm..."
fi

# Update và cài đặt packages
echo "📦 Cài đặt dependencies..."
apt-get update -qq > /dev/null 2>&1

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    qemu-system-x86 \
    qemu-utils \
    curl \
    wget \
    aria2 \
    p7zip-full \
    git \
    python3 \
    python3-pip \
    net-tools > /dev/null 2>&1

# Cài websockify
echo "🔌 Cài đặt websockify..."
pip3 install -q websockify > /dev/null 2>&1

# Clone noVNC
echo "🌐 Cài đặt noVNC..."
if [ ! -d "/opt/novnc" ]; then
    git clone -q https://github.com/novnc/noVNC.git /opt/novnc > /dev/null 2>&1
    git clone -q https://github.com/novnc/websockify /opt/novnc/utils/websockify > /dev/null 2>&1
fi

# Tạo thư mục
mkdir -p /root/win7vm
cd /root/win7vm

# Download Windows 7 pre-installed QCOW2 image
echo "💿 Đang tải Windows 7 Image..."

if [ ! -f "win7.qcow2" ]; then
    echo "   Đang tải Windows 7 Pre-installed (2-3GB)..."
    echo "   Vui lòng đợi 5-10 phút..."
    
    # Sử dụng Windows 7 Lite từ archive.org
    # Hoặc tạo image nhỏ từ ISO
    
    # Option 1: Download pre-made image (nếu có)
    wget -q --show-progress -O win7.7z \
        "https://archive.org/download/windows-7-lite-vm/win7-lite.7z" 2>/dev/null || \
    {
        echo ""
        echo "❌ Không thể tải image tự động."
        echo ""
        echo "📥 Giải pháp thay thế:"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "OPTION 1: Tải Windows 7 QCOW2 thủ công"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Bước 1: Tải Windows 7 QCOW2 từ một trong các nguồn:"
        echo "  • https://archive.org/details/windows-7-qcow2"
        echo "  • https://drive.google.com (tìm 'windows 7 qcow2')"
        echo ""
        echo "Bước 2: Upload file .qcow2 lên server"
        echo "  cp /path/to/windows7.qcow2 /root/win7vm/win7.qcow2"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "OPTION 2: Tạo từ ISO (chậm hơn, ~15 phút)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "# Tải Windows 7 ISO"
        echo "wget -O win7.iso 'https://archive.org/download/tiny-7-rev-01/Tiny7Rev01.iso'"
        echo ""
        echo "# Tạo disk"
        echo "qemu-img create -f qcow2 win7.qcow2 20G"
        echo ""
        echo "# Cài Windows (dùng VNC để điều khiển)"
        echo "qemu-system-x86_64 -m 2048 -cdrom win7.iso -hda win7.qcow2 -boot d -vnc :0"
        echo ""
        echo "# Sau khi cài xong, chạy lại script này"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "OPTION 3: Dùng Windows 10 thay vì Windows 7"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Windows 10 có sẵn image và dễ tải hơn:"
        echo "wget -O win10.qcow2 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-qemu/qemu-ga-win-100.0.0-1.el7ev/virtio-win-0.1.189.iso'"
        echo ""
        exit 1
    }
    
    # Giải nén nếu tải được
    if [ -f "win7.7z" ]; then
        echo "📦 Đang giải nén..."
        7z x -y win7.7z > /dev/null 2>&1
        rm win7.7z
    fi
fi

# Kiểm tra file image
if [ ! -f "win7.qcow2" ]; then
    echo ""
    echo "❌ Không tìm thấy Windows 7 image!"
    echo ""
    echo "📌 TẠO NHANH WINDOWS 7 IMAGE:"
    echo ""
    echo "# Tạo disk trống 20GB"
    qemu-img create -f qcow2 win7.qcow2 20G
    echo "✅ Đã tạo disk trống 20GB"
    echo ""
    echo "⚠️  Bạn cần cài Windows 7 lần đầu."
    echo "   Script sẽ boot từ ISO để cài đặt..."
    echo ""
    
    # Tải Tiny7 ISO (nhẹ)
    if [ ! -f "win7.iso" ]; then
        echo "📥 Đang tải Windows 7 ISO (700MB)..."
        wget -q --show-progress -O win7.iso \
            "https://archive.org/download/tiny-7-rev-01/Tiny7Rev01.iso" || \
        {
            echo "❌ Không tải được ISO!"
            echo "Vui lòng tải thủ công và đặt vào: /root/win7vm/win7.iso"
            exit 1
        }
    fi
    
    BOOT_ISO="-cdrom win7.iso -boot d"
    echo ""
    echo "🔄 Sẽ BOOT từ ISO để CÀI WINDOWS..."
else
    echo "✅ Đã có Windows 7 image"
    BOOT_ISO=""
fi

# Dọn dẹp processes
echo "🧹 Dọn dẹp processes cũ..."
pkill -9 qemu-system 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
sleep 2

# Khởi động QEMU
echo "🚀 Đang khởi động Windows 7 VM..."

# Tính toán RAM allocation (tối đa 70% RAM hệ thống)
VM_RAM=$((TOTAL_RAM * 70 / 100))
if [ $VM_RAM -gt 4096 ]; then
    VM_RAM=4096
fi
if [ $VM_RAM -lt 2048 ]; then
    VM_RAM=2048
fi

echo "   RAM cho VM: ${VM_RAM}MB"

# Chạy QEMU với VNC
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 2 \
    -m ${VM_RAM}M \
    -drive file=win7.qcow2,format=qcow2,if=virtio \
    $BOOT_ISO \
    -vnc 0.0.0.0:0,password=off \
    -device VGA,vgamem_mb=128 \
    -net nic,model=virtio \
    -net user \
    -rtc base=localtime \
    -usb \
    -device usb-tablet \
    -device usb-kbd \
    -device usb-mouse \
    > /tmp/qemu.log 2>&1 &

QEMU_PID=$!
echo "   QEMU PID: $QEMU_PID"
sleep 5

# Kiểm tra QEMU
if ! ps -p $QEMU_PID > /dev/null 2>&1; then
    echo "❌ QEMU không khởi động được!"
    echo "📋 Log:"
    cat /tmp/qemu.log
    exit 1
fi

echo "✅ QEMU đã khởi động"

# Khởi động noVNC
echo "🌍 Khởi động noVNC..."
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /tmp/novnc.log 2>&1 &
sleep 5

if ! netstat -tuln | grep -q ':6080'; then
    echo "❌ noVNC lỗi!"
    cat /tmp/novnc.log
    exit 1
fi

echo "✅ noVNC đã khởi động"

# Cloudflare Tunnel
echo "☁️  Khởi động Cloudflare Tunnel..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1
    rm cloudflared-linux-amd64.deb
fi

cloudflared tunnel --url http://localhost:6080 > /tmp/tunnel.log 2>&1 &
sleep 10

# Hiển thị kết quả
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           ✅ WINDOWS 7 THẬT ĐÃ KHỞI ĐỘNG!                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Lấy URL
PUBLIC_URL=""
for i in {1..20}; do
    if [ -f /tmp/tunnel.log ]; then
        PUBLIC_URL=$(grep -o 'https://.*\.trycloudflare.com' /tmp/tunnel.log | head -1)
        [ ! -z "$PUBLIC_URL" ] && break
    fi
    sleep 1
done

if [ ! -z "$PUBLIC_URL" ]; then
    echo "🌐 URL truy cập:"
    echo ""
    echo "   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "   ┃  👉 $PUBLIC_URL/vnc.html"
    echo "   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo ""
fi

echo "📱 Local: http://localhost:6080/vnc.html"
echo ""

if [ ! -z "$BOOT_ISO" ]; then
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🔧 LẦN ĐẦU - CÀI ĐẶT WINDOWS 7:                          ║"
    echo "║                                                            ║"
    echo "║  1. Mở URL trên → Click Connect                            ║"
    echo "║  2. Thấy màn hình setup Windows 7                          ║"
    echo "║  3. Làm theo hướng dẫn cài đặt                             ║"
    echo "║  4. Chọn Custom → Format disk → Install                    ║"
    echo "║  5. Đợi 10-15 phút cài đặt                                 ║"
    echo "║  6. Tạo user/password                                      ║"
    echo "║  7. Lần sau sẽ boot thẳng vào Windows!                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
else
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🪟 WINDOWS 7 THẬT - READY!                                ║"
    echo "║                                                            ║"
    echo "║  • Mở URL → Click Connect                                  ║"
    echo "║  • Đợi Windows boot (30-60s)                               ║"
    echo "║  • Login và sử dụng như PC thật!                           ║"
    echo "║                                                            ║"
    echo "║  ✨ Có thể làm mọi thứ:                                    ║"
    echo "║  • Cài phần mềm Windows                                    ║"
    echo "║  • Lướt web, xem video                                     ║"
    echo "║  • Chơi game nhẹ                                           ║"
    echo "║  • Dùng Office, Photoshop...                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
fi

echo ""
echo "📊 VM Info:"
echo "   • OS:        Windows 7"
echo "   • RAM:       ${VM_RAM}MB"
echo "   • CPU:       2 cores"
echo "   • Disk:      20GB"
echo "   • QEMU PID:  $QEMU_PID"
echo ""

echo "📊 Status:"
echo "   • QEMU:   $(ps -p $QEMU_PID >/dev/null && echo '✅' || echo '❌')"
echo "   • VNC:    $(netstat -tuln | grep -q ':5900' && echo '✅' || echo '❌')"
echo "   • noVNC:  $(netstat -tuln | grep -q ':6080' && echo '✅' || echo '❌')"
echo "   • Tunnel: $(pgrep cloudflared >/dev/null && echo '✅' || echo '❌')"
echo ""

echo "⚡ Windows 7 đang chạy. Ctrl+C để tắt..."

cleanup() {
    echo ""
    echo "🛑 Đang shutdown Windows 7..."
    kill -TERM $QEMU_PID 2>/dev/null || true
    sleep 5
    kill -9 $QEMU_PID 2>/dev/null || true
    pkill -9 cloudflared 2>/dev/null || true
    pkill -9 websockify 2>/dev/null || true
    echo "✅ Đã tắt"
}

trap cleanup EXIT

while ps -p $QEMU_PID > /dev/null; do
    sleep 5
done

echo "❌ VM đã dừng!"
