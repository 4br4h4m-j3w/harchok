#!/bin/bash

set -e
echo "Проверяем Интернет подключение..."
if ping -c 5 google.com > /dev/null 2>&1; then
    echo "Успех. Интернет есть."
else
    echo "Интернет соединения нет. Проверьте сетевые настройки."
    exit
fi

echo "Начинаем кастомную установку Arch Linux"

read -p "Введите название устройства (например, /dev/nvme0n1): " device
echo
read -p "Введите имя пользователя: " username
echo
read -s -p "Введите пароль: " password
echo
read -s -p "Введите пароль от root: " root_password
echo
read -p "Введите название хоста: " hostname
echo
echo "Размечаем диск..."
parted -s "$device" mklabel gpt
parted -s "$device" mkpart ESP fat32 1MiB 600MiB
parted -s "$device" set 1 boot on
parted -s "$device" mkpart primary 600MiB 100%
partprobe "$device" > /dev/null || partx -u "$device" > /dev/null || true
sleep 2

echo "Форматируем загрузочный раздел..."
mkfs.vfat -F32 "${device}p1"

echo "Начинаем шифрование LUKS..."
cryptsetup -q luksFormat "${device}p2"

echo "Открываем зашифрованное устройство..."
cryptsetup luksOpen "${device}p2" crypt

echo "Форматируем как btrfs..."
mkfs.btrfs -n 32k -L arch /dev/mapper/crypt
mount /dev/mapper/crypt /mnt

echo "Создаем subvolumes..."
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

echo "Перемонтируем по-правильному..."
mount -o compress=zstd:5,noatime,commit=300,subvol=@ /dev/mapper/crypt /mnt
mkdir -p /mnt/{home,.snapshots,boot}
mount -o compress=zstd:5,noatime,commit=300,subvol=@home /dev/mapper/crypt /mnt/home
mount "${device}p1" /mnt/boot

echo "Устанавливаем основные пакеты..."
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware \
    intel-ucode amd-ucode btrfs-progs cryptsetup efibootmgr ntfs-3g exfat-utils xf86-video-amdgpu
    
pacstrap /mnt micro git fish xorg \
    networkmanager wget terminus-font bspwm sxhkd sddm alacritty atuin bat docker docker-compose \
    
pacstrap /mnt dunst feh flameshot lazydocker lsd network-manager-applet nm-connection-editor \
    noto-fonts-cjk noto-fonts-emoji pavucontrol polybar ranger redshift rofi tabiew thunar \
    thunar-media-tags-plugin thunar-volman ttf-daddytime-mono-nerd ttf-iosevka-nerd ttf-jetbrains-mono ttf-liberation\
    
pacstrap /mnt ttf-jetbrains-mono-nerd ttf-roboto zathura zathura-djvu zathura-pdf-mupdf  unrar unzip udiskie tmux \
    thunar-archive-plugin playerctl pamixer oculante jq file-roller fd dysk \
    cloc cava blueman bluez bluez-utils 7zip pipewire pipewire-alsa pipewire-audio \
    pipewire-jack pipewire-pulse ruff go arandr kubectl

echo "Генерируем fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "Устанавливаем AUR пакеты..."
arch-chroot /mnt /bin/bash <<EOF
git clone https://aur.archlinux.org/paru.git
sudo cd paru && makepkg -si
sudo cd .. && rm -rf paru

paru -S telegram-desktop spotify-launcher sddm-silent-theme neofetch \
hyx visual-studio-code-bin steam google-chrome ssh-ggh --noconfirm
EOF

echo "Настраиваем окружение..."
arch-chroot /mnt /bin/bash <<EOF
set -ex
useradd -m -G wheel,users -s /bin/fish "$username"
echo "$username:$password" | chpasswd
echo "root:$root_password" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
timedatectl set-timezone 'Europe/Moscow'
hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Virtual console (tty)
loadkeys ruwin_alt_sh-UTF-8
setfont ter-v32b
echo 'KEYMAP="ruwin_alt_sh-UTF-8"' > /etc/vconsole.conf
echo 'FONT="ter-v32b"' >> /etc/vconsole.conf

# Hostname
echo "${hostname}" > /etc/hostname

# Enable services
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable docker
systemctl enable bluetooth

# Initramfs
sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
sed -i 's|^MODULES=()|MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)|' /etc/mkinitcpio.conf
mkinitcpio -P

# Systemd-boot
bootctl install
EOF

echo "Настраиваем загрузчик..."
luks_uuid=$(blkid -o value -s UUID "${device}p2")
cat > /mnt/boot/loader/entries/arch.conf <<EOF
title Arch Linux
initrd /initramfs-linux-lts.img
linux /vmlinuz-linux-lts
options rd.luks.name=${luks_uuid}=crypt rd.luks.options=discard root=/dev/mapper/crypt rootflags=subvol=@ rw idle=halt nohz=off processor.max_cstate=1 amd_pstate=disable nvme_core.default_ps_max_latency_us=0
EOF

cat > /mnt/boot/loader/loader.conf <<EOF
timeout 5
editor no
default arch
console-mode max
EOF

sed -i '/^#\s*\[multilib\]/ { s/^#//; n; s/^#//; }' /mnt/etc/pacman.conf

echo "Копируем конфиги..."
cp -r /root/configs/. "/mnt/home/${username}/"
cp /root/configs/sddm.conf /mnt/etc/

arch-chroot /mnt /bin/bash <<EOF
set -ex
chown -R "${username}:${username}" "/home/${username}/"
chmod -R 777 "/home/${username}/"
fc-cache -fv
betterlockscreen -u "/home/${username}/Wallpapers/fallout_vault_boy_2-wallpaper-2560x1600.jpg"
/usr/share/sddm/themes/silent/change_avatar.sh $username "/home/${username}/Pictures/Avatars/vigilante.jpg"

chmod +x "/home/${username}/Code/install_vsix.sh"
cd "/home/${username}/Code/"
su - "$username" -c "./install_vsix.sh"
cp ./settings.json "/home/${username}/.configs/Code/User/"
EOF

echo "Закрываем LUKS раздел..."
umount -R /mnt
cryptsetup close crypt

echo "Установка завершена, можно перезагружаться"
