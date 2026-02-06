## Custom Arch ISO

Arch Linux ISO with stable version of linux kernel (linux-lts).

Features:
- LUKS encryption;
- BTRFS;
- BSPWM configs;

### Build

```bash
cd ..
sudo mkarchiso -v -r -w /tmp/archiso -o <target_device_for_iso> harchok/
```
