Boot cmd
===============

# gummiboot

`$ gummiboot status
Boot Loader Binaries:
          ESP: /dev/disk/by-partuuid/e553201f-387b-453f-bfd4-77ebaeee06c3
         File: └─/EFI/gummiboot/gummibootx64.efi (gummiboot 48)
         File: └─/EFI/Boot/bootx64.efi (gummiboot 48)

Boot Loader Entries in EFI Variables:
        Title: Linux Boot Manager
           ID: 0x0003
       Status: active, boot-order
    Partition: /dev/disk/by-partuuid/e553201f-387b-453f-bfd4-77ebaeee06c3
         File: └─/EFI/gummiboot/gummibootx64.efi

        Title: Windows Boot Manager
           ID: 0x0000
       Status: active, boot-order
    Partition: /dev/disk/by-partuuid/e553201f-387b-453f-bfd4-77ebaeee06c3
         File: └─/EFI/Microsoft/Boot/bootmgfw.efi`

# fdisk

`$ fdisk --list
Disque /dev/sda : 465,8 GiB, 500107862016 octets, 976773168 secteurs
Unités : secteur de 1 × 512 = 512 octets
Taille de secteur (logique / physique) : 512 octets / 4096 octets
taille d'E/S (minimale / optimale) : 4096 octets / 4096 octets
Type d'étiquette de disque : gpt
Identifiant de disque : 2D977C64-FC19-4B65-951E-BE9C6BBD190D

Périphérique    Début       Fin  Secteurs Taille Type
/dev/sda1         2048    206847    204800   100M Système EFI
/dev/sda2       206848   2050047   1843200   900M Environnement de récupération Windows
/dev/sda3      2050048   2312191    262144   128M Réservé Microsoft
/dev/sda4      2312192 393017343 390705152 186,3G Données de base Microsoft
/dev/sda5    393017344 771973119 378955776 180,7G Données de base Microsoft
/dev/sda6    771973120 974725119 202752000  96,7G Système de fichiers Linux
/dev/sda7    974725120 976773119   2048000  1000M Partition d'échange Linux`


# efibootmgr

`$ efibootmgr
BootCurrent: 0003
Timeout: 2 seconds
BootOrder: 0003,0000
Boot0000* Windows Boot Manager
Boot0003* Linux Boot Manager`

# mount

`$ mount
proc on /proc type proc (rw,relatime)
sysfs on /sys type sysfs (rw,relatime)
devtmpfs on /dev type devtmpfs (rw,relatime,size=403412k,nr_inodes=1007506,mode=755)
tmpfs on /run type tmpfs (rw,relatime,size=2017048k,mode=755)
/dev/sda6 on / type ext4 (rw,relatime,data=ordered)
/dev/sda6 on /nix/store type ext4 (ro,relatime,data=ordered)
tmpfs on /dev/shm type tmpfs (rw,relatime,size=4034092k)
ramfs on /run/keys type ramfs (rw,relatime)
tmpfs on /var/setuid-wrappers type tmpfs (rw,relatime,mode=755)
securityfs on /sys/kernel/security type securityfs (rw,nosuid,nodev,noexec,relatime)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=3,mode=620,ptmxmode=000)
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,mode=755)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/run/current-system/systemd/lib/systemd/systemd-cgroups-agent,name=systemd)
efivarfs on /sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/net_cls type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls)
mqueue on /dev/mqueue type mqueue (rw,relatime)
hugetlbfs on /dev/hugepages type hugetlbfs (rw,relatime)
debugfs on /sys/kernel/debug type debugfs (rw,relatime)
/dev/sda1 on /boot type vfat (rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
tmpfs on /run/user/0 type tmpfs (rw,nosuid,nodev,relatime,size=806820k,mode=700)`
