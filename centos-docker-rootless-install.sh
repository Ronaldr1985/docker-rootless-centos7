#!/bin/bash

## Variables
user='dockerd' # User we are going to create
group=$user # We shall create a group with the same name as the user
home_dir='/opt/docker' ## The home folder for the dockerd user we are going to create and run docker as
xdgruntimedir_dir='/tmp/$user-docker' # The directory that we are going to set XDG_RUNTIME_DIR to

## Defining functions
function checkPrerequisites {
	[[ "$EUID" -ne 0  ]] && (echo "Please run as root"; exit 1)
	(ping -c 4 google.com > /dev/null 2>&1) || (echo "Need internet access and/or DNS"; exit 1)
	[[ -n $(id -u "$user" 2>/dev/null)  ]] && (echo "User already exists"; exit 1)
	yum > /dev/null 2>&1 || (echo "Need to be on CentOS 7"; exit 1)
}

function checkDocker {
	(rpm -qa | grep -i docker && echo "Docker installed, checking for Docker rootless installer") || installDocker
	(which dockerd-rootless-setuptool.sh && echo "Found Docker rootless installer, moving on...") || installDockerRootlessPackage
}

function setupSystem {
	grep "user.max_user_namespaces" /etc/sysctl.conf && sed -i "$(grep -in "user.max_user_namespaces" /etc/sysctl.conf | cut -f1 -d:)s/.*/user.max_user_namespaces=28633/"  /etc/sysctl.conf || echo "user.max_user_namespaces=28633" >> /etc/sysctl.conf
	grep "net.ipv4.ping_group_range" /etc/sysctl.conf && sed -i "$(grep -in "net.ipv4.ping_group_range" /etc/sysctl.conf | cut -f1 -d:)s/.*/net.ipv4.ping_group_range = 0 2147483647/"  /etc/sysctl.conf || echo "net.ipv4.ping_group_range = 0 2147483647" >> /etc/sysctl.conf
	sysctl --system
}

function installDocker {
	yum update -y
	rpm -qa | grep yum-utils || yum install -y yum-utils || (echo "Failed to install yum-utils, exiting..."; exit 1)
	yum repolist | grep -i docker || ((yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum makecache) || (echo "Failed to add Docker repository, exiting..."; exit 1))
	yum install -y docker-ce docker-ce-cli containerd.io || (echo "Failed to install Docker, exiting..."; exit 1)
	systemctl disable --now docker.service docker.socket # Disable Docker from running as root
}

function installDockerRootlessPackage {
	rpm -qa | grep yum-utils || yum install -y yum-utils
	yum repolist | grep -i docker || ((yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum makecache) || (echo "Failed to add Docker repository, exiting..."; exit 1))
	yum install -y docker-ce-rootless-extras || (echo "Failed to install Docker rootless extras, exiting..."; exit 1)
}

function createUser {
	# which rbash 2>/dev/null || cp -f /bin/bash /bin/rbash 
	useradd -m -d $home_dir $user ## Don't set shell straight to rbash as it will cause issues later, change it to change the shell after install has completed.
	mkdir -p $home_dir/.programs
	echo "export XDG_RUNTIME_DIR=$xdgruntimedir_dir" > $home_dir/.bash_profile
	echo "export HOME=$home_dir" >> $home_dir/.bash_profile
	mkdir -p $xdgruntimedir_dir 
	# echo "readonly PATH=$home_dir/.programs" > $home_dir/.bash_profile && echo "export PATH" >> $home_dir/.bash_profile
	# ln -s /usr/bin/dockerd-rootless.sh $home_dir/.programs && ln -s /bin/kill $home_dir/.programs && ln -s /bin/dockerd-rootless-setuptool.sh $home_dir/.programs
	# chattr +i $home_dir/.bash_profile
}

function installDockerRootless {
	echo "/bin/bash" > $home_dir/.programs/installDocker.sh
	echo "XDG_RUNTIME_DIR=$xdgruntimedir_dir" >> $home_dir/.programs/installDocker.sh
	echo "HOME=$home_dir" >> $home_dir/.programs/installDocker.sh
	echo "dockerd-rootless-setuptool.sh install" >> $home_dir/.programs/installDocker.sh
	echo "exit" >> $home_dir/.programs/installDocker.sh
	chmod +x $home_dir/.programs/installDocker.sh 
	su -l $user -s /bin/bash -c exec $home_dir/.programs/installDocker.sh
}

function installServiceFile {
	echo "
[Unit]
Description=Rootless Docker
After=network.target

[Service]
User=$user
Group=$group
WorkingDirectory=$home_dir

# Read only mapping of /usr /boot and /etc
ProtectSystem=full

# /home, /root and /run/user seem to be empty from within the unit.
ProtectHome=true

# What to do to start the service
Environment="XDG_RUNTIME_DIR=$xdgruntimedir_dir"
Environment="HOME=$home_dir"
ExecStart=/usr/bin/dockerd-rootless.sh

# What to do when reloading service
ExecReload=/bin/kill -s HUP \$MAINPID

Restart=on-failure
RestartSec=60s

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/docker-rootless.service 
	systemctl daemon-reload
}

function finishingUp {
	chown -R $user:docker $xdgruntimedir_dir 
	cat << 'EOF'
 ___           _        _ _       _   _                ____                      _      _       
|_ _|_ __  ___| |_ __ _| | | __ _| |_(_) ___  _ __    / ___|___  _ __ ___  _ __ | | ___| |_ ___ 
 | || '_ \/ __| __/ _` | | |/ _` | __| |/ _ \| '_ \  | |   / _ \| '_ ` _ \| '_ \| |/ _ | __/ _ \
 | || | | \__ | || (_| | | | (_| | |_| | (_) | | | | | |__| (_) | | | | | | |_) | |  __| ||  __/
|___|_| |_|___/\__\__,_|_|_|\__,_|\__|_|\___/|_| |_|  \____\___/|_| |_| |_| .__/|_|\___|\__\___|
                                                                          |_|                   
EOF
	echo "To allow any users to use docker add them to the $group group"

}

## The actual script
checkPrerequisites 
checkDocker && \
setupSystem && \
createUser && \
installDockerRootless && \
installServiceFile && \
finishingUp
