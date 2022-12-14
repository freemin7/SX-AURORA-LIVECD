# Generated by pykickstart v3.32
#version=DEVEL
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --iscrypted --lock locked
# System language
lang en_US.UTF-8
# Shutdown after installation
shutdown
# Network information
network  --bootproto=dhcp --device=link --activate
# Firewall configuration
firewall --enabled --service=mdns
# Use network installation
url --url="http://dl.rockylinux.org/pub/rocky/8.6/BaseOS/$basearch/os/"
repo --name="BaseOS" --baseurl=http://dl.rockylinux.org/pub/rocky/8.6/BaseOS/$basearch/os/ --cost=200
repo --name="AppStream" --baseurl=http://dl.rockylinux.org/pub/rocky/8.6/AppStream/$basearch/os/ --cost=200
repo --name="PowerTools" --baseurl=http://dl.rockylinux.org/pub/rocky/8.6/PowerTools/$basearch/os/ --cost=200
repo --name="extras" --baseurl=http://dl.rockylinux.org/pub/rocky/8.6/extras/$basearch/os --cost=200

repo --name="TSUBASA-repo" --baseurl=https://sxauroratsubasa.sakura.ne.jp/repos/TSUBASA-repo_el8.6 --cost=200 --install
repo --name="nec-sdk-runtime" --baseurl=https://sxauroratsubasa.sakura.ne.jp/repos/runtime/sdk/sdk_el8 --cost=200 --install
repo --name="nec-mpi-runtime" --baseurl=https://sxauroratsubasa.sakura.ne.jp/repos/runtime/mpi/mpi_el8 --cost=200 --install
repo --name="nec-sdk-community" --baseurl=https://sxauroratsubasa.sakura.ne.jp/repos/community/sdk/sdk_el8 --cost=200 --install
repo --name="nec-mpi-community" --baseurl=https://sxauroratsubasa.sakura.ne.jp/repos/community/mpi/mpi_el8 --cost=200 --install
repo --name="llvm-re-rv" --baseurl=https://sx-aurora.com/repos/llvm-el8/ --cost=200 --install

# System timezone
timezone US/Eastern
# SELinux configuration
selinux --enforcing
# System services
services --disabled="sshd" --enabled="NetworkManager,ModemManager"
# System bootloader configuration
bootloader --location=none
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="ext4" --size=10000
part / --size=12000

%post

# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager chronyd
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    continue
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
  fi
done

# Enable swap unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

# Support for persistent homes
mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

# Help locate persistent homes
findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# Mount the persistent home if it's available
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# Create the liveuser (no password) so automatic logins and sudo works
action "Adding live user" useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Same for root
passwd -d root > /dev/null

# Turn off firstboot (similar to a DVD/minimal install, where it asks
# for the user to accept the EULA before bringing up a TTY)
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# Prelinking damages the images
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# Turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# Even if there isn't gnome, this doesn't hurt.
gsettings set org.gnome.software download-updates 'false' || :

# Disable cron
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# Disable abrt
systemctl --no-reload disable abrtd.service 2> /dev/null || :
systemctl stop abrtd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
# the hostname must be something else than 'localhost'
# https://bugzilla.redhat.com/show_bug.cgi?id=1370222
echo "localhost-live" > /etc/hostname

EOF

# HAL likes to start late.
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# Read some stuff out of the kernel cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# If liveinst or textinst is given, start installer
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

# Configure X, allowing user to override xdriver
if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# Enable tmpfs for /tmp - this is a good idea
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# PackageKit likes to play games. Let's fix that.
rm -f /var/lib/rpm/__db*
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794 - the error is expected
/sbin/chkconfig network off

# Remove machine-id on generated images
rm -f /etc/machine-id
touch /etc/machine-id

cat >> /etc/rc.d/init.d/livesys << EOF


# disable gnome-software automatically downloading updates
cat >> /usr/share/glib-2.0/schemas/org.gnome.software.gschema.override << FOE
[org.gnome.software]
download-updates=false
FOE

# don't autostart gnome-software session service
rm -f /etc/xdg/autostart/gnome-software-service.desktop

# disable the gnome-software shell search provider
cat >> /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini << FOE
DefaultDisabled=true
FOE

# don't run gnome-initial-setup
mkdir ~liveuser/.config
touch ~liveuser/.config/gnome-initial-setup-done

# suppress anaconda spokes redundant with gnome-initial-setup
cat >> /etc/sysconfig/anaconda << FOE
[NetworkSpoke]
visited=1

[PasswordSpoke]
visited=1

[UserSpoke]
visited=1
FOE

# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
  # need to move it to anaconda.desktop to make shell happy
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

  cat >> /usr/share/glib-2.0/schemas/org.gnome.shell.gschema.override << FOE
[org.gnome.shell]
favorite-apps=['firefox.desktop', 'evolution.desktop', 'rhythmbox.desktop', 'shotwell.desktop', 'org.gnome.Nautilus.desktop', 'anaconda.desktop']
FOE

  # Make the welcome screen show up
  if [ -f /usr/share/anaconda/gnome/rhel-welcome.desktop ]; then
    mkdir -p ~liveuser/.config/autostart
    #sed -i "s/Red Hat Enterprise/Rocky/g" /usr/share/anaconda/gnome/rhel-welcome.desktop
    #sed -i "s/RHEL/Rocky Linux/g" /usr/share/anaconda/gnome/rhel-welcome
    #sed -i "s/Red Hat Enterprise/Rocky/g" /usr/share/anaconda/gnome/rhel-welcome
    #sed -i "s/org.fedoraproject.AnacondaInstaller/fedora-logo-icon/g" /usr/share/anaconda/gnome/rhel-welcome
    #sed -i "s/org.fedoraproject.AnacondaInstaller/fedora-logo-icon/g" /usr/share/applications/anaconda.desktop
    cp /usr/share/anaconda/gnome/rhel-welcome.desktop /usr/share/applications/
    cp /usr/share/anaconda/gnome/rhel-welcome.desktop ~liveuser/.config/autostart/
  fi
  echo "[Desktop Entry]
Type=Application
Name=Test Instructions
Exec=xdg-open  /home/liveuser/test_instructions.txt" >> ~liveuser/.config/autostart/instructions.desktop

  # Copy Anaconda branding in place
  if [ -d /usr/share/lorax/product/usr/share/anaconda ]; then
    cp -a /usr/share/lorax/product/* /
  fi
fi

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up auto-login
cat > /etc/gdm/custom.conf << FOE
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=liveuser
FOE

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

#not sure if necessary but it helped
echo "# Generated by NetworkManager
nameserver 8.8.8.8
nameserver 8.8.4.4" >> /etc/resolve.conf

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
restorecon -R /

# make a bunch of test stuff available
(cd ~liveuser/;
curl -L https://sxauroratsubasa.sakura.ne.jp/repos/file/SetupGuide_examples.tgz --output ~liveuser/examples.tgz ;
tar -xf examples.tgz ;
rm examples.tgz ;

curl -L https://github.com/efocht/hpcg-ve-bin/releases/download/v3.1.10ef/hpcg-ve-v3.1.10ef.tgz  --output ~liveuser/hpcg.tgz ;
tar -xf hpcg.tgz ;
rm hpcg.tgz ;

curl -L https://github.com/efocht/ve-intrinsics-examples/archive/refs/heads/main.zip  --output ~liveuser/instrinsics.zip ;
unzip instrinsics.zip ;
rm instrinsics.zip ;

curl -L https://share.sx-aurora.de/s/Ho3Bf65gDoqCeYc/download/dgemm_c >> dgemm_c

curl -L https://share.sx-aurora.de/s/b6s2rtdNDztANar/download/dgemm_test.tgz >> dgemm_test.tgz;
tar -xf dgemm_test.tgz ;
rm dgemm_test.tgz ;

echo "Testing notes:

Does the fan of the card spin?
Run lscpi in the terminal

If 

lsmod | grep ve_drv

is empty run:

modprobe ve_drv; modprobe vp
systemctl restart mmm



/opt/nec/ve/bin/vecmd info
/opt/nec/ve/bin/vecmd state get

if card shows as needs update
/opt/nec/ve/bin/vecmd fwup check


/opt/nec/ve/bin/vecmd state set off
/opt/nec/ve/bin/vecmd state set mnt

/opt/nec/ve/bin/vecmd fwup vmc /etc/opt/nec/ve/mmm/vmc/aurora_MK10.bin

reboot #the machine

/opt/nec/ve/bin/veda-smi
/opt/nec/ve/bin/lscpu

edit the first line of ve-intrinsics-examples-main to say
-rv-2.2.0

run that script

~/dgemm_c

~/dgemm_test/dgemm_clang

cd ~/examples
/usr/local/ve/llvm-ve-rv-2.2.0/bin/clang --target=ve-linux -o ve.out sample.c
/usr/local/ve/llvm-ve-rv-2.2.0/bin/clang -o x86.out sample.c

./ve.out
./x86.out

/opt/nec/ve/bin/ve_exec -c 0 ve.out
   ...  
/opt/nec/ve/bin/ve_exec -c 7 ve.out

cd ~/hpcg-ve-v3.1.1.0ef/
~/hpcg-ve-v3.1.1.0ef/run.sh




/opt/nec/ve/bin/



cd examples

" >> test_instructions.txt



)
chown -R liveuser:liveuser /home/liveuser/

EOF

%end

%post --nochroot
cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# This only works on x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
    # For livecd-creator builds
    if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
    cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS

    # For lorax/livemedia-creator builds
    sed -i '
    /## make boot.iso/ i\
    # Add livecd-iso-to-disk script to .iso filesystem at /LiveOS/\
    <% f = "usr/bin/livecd-iso-to-disk" %>\
    %if exists(f):\
        install ${f} ${LIVEDIR}/${f|basename}\
    %endif\
    ' /usr/share/lorax/templates.d/99-generic/live/x86.tmpl
fi

%end

%packages
@anaconda-tools
@base-x
@core
@fonts
@gnome-desktop
@guest-desktop-agents
@hardware-support
@internet-browser
@networkmanager-submodules
aajohan-comfortaa-fonts
anaconda
anaconda-install-env-deps
anaconda-live
chkconfig
dracut-live
glibc-all-langpacks
initscripts
kernel
kernel-modules
kernel-modules-extra
memtest86+
syslinux
@ve-devel
@ve-runtime
@nec-sdk-runtime
@nec-mpi-runtime
nec-mpi-runtime
nec-mpi-runtime-common
nec-mpi-runtime-pbs
wget
unzip
llvm-ve-rv-2.2.0
-@dial-up
-@input-methods
-@standard
-gfs2-utils
-reiserfs-utils

%end
