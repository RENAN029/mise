set -e

sudo pacman -S --noconfirm noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-noto-nerd noto-fonts-extra ttf-jetbrains-mono
sudo pacman -S --noconfirm ffmpeg gst-plugins-ugly gst-plugins-good gst-plugins-base gst-plugins-bad gst-libav gstreamer
sudo pacman -S --noconfirm gdu nvidia-open intel-ucode git neovim fastfetch btop ufw fwupd flatpak yt-dlp aria2 earlyoom
sudo pacman -S --noconfirm cosmic-session cosmic-terminal cosmic-files cosmic-store xdg-user-dirs smartmontools openssh

sudo pacman -S --noconfirm gamemode fuse dnsmasq apparmor 
git clone https://github.com/maximilionus/lucidglyph.git
systemctl enable cosmic-greeter earlyoom dnsmasq apparmor 
cd lucidglyph
sudo ./lucidglyph.sh install
cd ..
rm -rf lucidglyph

sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst"
sudo pacman -U --noconfirm "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"
sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
sudo sed -i '/Color/a ILoveCandy' /etc/pacman.conf
sudo sed -i '/^ParallelDownloads/d' /etc/pacman.conf
sudo sed -i '/ILoveCandy/a ParallelDownloads = 15' /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf

sudo pacman -Syu --noconfirm 
sudo pacman -Scc --noconfirm
echo "sudo pacman -S nix yay ananicy-cpp clamav irqbalance cups pnpm mise mangohud distrobox docker gamescope httpie iwd"     
cd ..
rm -rf jq
