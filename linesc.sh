#!/bin/bash
#this isn't really a replacement for the priv-esc scripts that everyone uses
#and it contains a bunch of overlap with them, but I felt like pushing some code
#it might have some interesting and uncommon tricks
#I haven't bothered to include setuid binaries or procs running as root
#if you could find 0day that easily you wouldn't need a priv-esc script
#this was also written in about 30 minutes and only tested on Fedora and CentOS, so it probably has bugs
#my code always has bugs

gather() {
echo "[#] General system info..."
echo "[*] Kernel version:"
uname -a
echo "[*] Linux distro:"
cat /etc/*release | grep -i PRETTY | awk -F "=" '{print $2}'
#We're relying on PRETTY_NAME being present for full release and version, so may not work on some distros"
echo "[*] Init system in use:"
ps --no-header -p 1 | awk -F " " '{ print $4 }'
echo ""
}

versions() {
echo "[#] Checking versions of two pieces of userland that often have priv-esc bugs and are overlooked..."
echo "[*] Libc version and date information:"
`ldd $(which id) | awk -F " " '{print $3}' | grep --color=never libc` | grep -A1 release
#If it's from 2009/2010, taviso has some userland bugs for you!
echo "[*] Dbus version:"
$(which dbus-daemon) --version | grep Message
echo "[*] Dbus services for system:"
dbus-send --system --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames
echo "[*] Dbus services for session:"
dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames
echo "See https://github.com/taviso/dbusmap for additional dbus auditing!"
echo ""
}

escape() {
declare pids
declare -a pida
pids=$(ps --no-header -wweo "%u %p" | grep march | awk -F " " '{print $2}')
IFS=' ' read -r -a pida <<< $pids
for i in "${pida[@]}";do
        if ls -di --color=never "/proc/$i/root/" | grep -qe "^2\ "; then
                echo "proc $i seems to be outside the jail..."
        fi
done
}

capabilities() {
declare TTY
echo "[#] Checking capabilities..."
echo "[*] Do we have a TTY (and thus sudo/ssh)?"
#I feel the need to clarify that not having a tty is NOT the same as being in a "restricted shell"
#some commands require it for interaction in order to enter passwords securely (and sometimes some other interaction), that's why some commands don't work
TTY=$(tty)
if echo $TTY | grep -q "not"; then
	echo "No tty; get one with python -c import pty;pty.spawn('/bin/bash')"
else
	echo "You've got a TTY."
	echo $TTY
fi
echo "[*] Are we in a chroot?"
if ls -di --color=never / | grep -vqe "^2.*/$"; then
	echo "Chroot detected."
	echo "Attempting to find PIDs that will let you escape as a low-privileged user..."
	escape
else
	echo "You're not chrooted."
	fi
echo "[*] SELinux status?"
getenforce
echo ""
}

users() {
echo "[#] Getting user information..."
echo "[*] Logged-in users:"
#note, not a count of how many login processes the users have per user.
who -q | tr " " "\n" | sort | uniq | grep -v "\=\|\#"
echo "[*] Total users:"
getent passwd
#we use getent because it'll pull users from LDAP et al, not just local filesystem.
echo ""
}

tools() {
echo "[#] Tools available..."
echo "[*] Pay particular attention to strace and gcore, since they might allow you to capture passwords from your user..."
type -p gcc perl python ruby nmap openssl strace gcore gdb lsof wget nc ncat socat ftp curl lwp-download
#lwp-download generally implies LWP is around, which means perl's curl
echo ""
}

filesystem() {
echo "[#] Filesystem information..."
echo "[*] df output:"
df -ah
echo "Note: tmpfs is a good place to do things to avoid disk forensics."
echo "However, if you find they're mounted noexec/nosuid" 
echo "you can nearly always use /var/tmp, but that filesystem is always on disk."
echo ""
}

procs() {
echo "[#] Processes..."
echo "[*] Readable procs with environment variables:"
ps --no-header -wwefo "%p %a"
echo "[*] Procs in general:"
ps --no-header -weFH
echo ""
}

network() {
echo "[#] Networking..."
echo "[*] Interfaces:"
ip address
ifconfig -a
#duplication here, too lazy to check whether ifconfig or ip is present
echo "[*] Resolv.conf:"
cat /etc/resolv.conf
echo "[*] Hosts"
cat /etc/hosts
echo "[*] Netstat:"
netstat -peanut
echo ""
}

usage() {
echo "-f allows you to specify a file for output instead of STDOUT."
echo "This will output a lot of text, be warned."
echo "I'm lazy, this has limited error checking and is terrible."
echo "Some functions that produce a lot of output only run with -f"
#currently proc list and network info
}

main() {
gather
versions
capabilities
users
tools
filesystem
}

while getopts "hf:x" opt; do
	case $opt in
		h)
		usage
		exit 1
		;;
		f)
		main > $OPTARG
		procs >> $OPTARG
		network >> $OPTARG
		exit 1
		;;
	esac
done
main
