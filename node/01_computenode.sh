#!/bin/sh
# This script builds a Compute node for cloud bursting with Azure CycleCloud
# Author : Vinil Vadakkepurakkal
# Date : 24/11/2025

set -e
if [ $(whoami) != root ]; then
  echo "Please run as root"
  exit 1
fi
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Building Slurm Compute node for cloud bursting with Azure CycleCloud"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
# Prompt for Cluster Name
read -p "Enter Cluster Name: " cluster_name
read -p "Enter the Slurm version to install (24.05.4-2): " SLURM_VERSION
read -p "Enter the NFSServer IP Address (This is the IP of the scheduler node): " ip_address

echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
echo "Summary of entered details:"
echo "--------------------------"
echo "Cluster Name: $cluster_name"
echo "NFSServer IP Address: $ip_address"
echo " "
echo "Proceeding with the setup..."
echo "------------------------------------------------------------------------------------------------------------------------------"

sched_dir="/sched/$cluster_name"
slurm_conf="$sched_dir/slurm.conf"
munge_key="/etc/munge/munge.key"
slurm_script_dir="/opt/azurehpc/slurm"
OS_VERSION=$(cat /etc/os-release  | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)
OS_ID=$(cat /etc/os-release  | grep ^ID= | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)


# Create Munge and Slurm users
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Creating Munge and Slurm users"
echo "------------------------------------------------------------------------------------------------------------------------------"


# Function to create a group if it does not exist
create_group() {
    if ! getent group "$1" >/dev/null; then
        groupadd -g "$2" "$1"
        echo "Group $1 created."
    else
        echo "Group $1 already exists."
    fi
}

# Function to create a user if it does not exist
create_user() {
    if ! id "$1" >/dev/null 2>&1; then
        useradd -u "$2" -g "$3" -s /bin/false -M "$1"
        echo "User $1 created."
    else
        echo "User $1 already exists."
    fi
}

# Create groups and users
create_group "munge" 11101
create_user "munge" 11101 11101

create_group "slurm" 11100
create_user "slurm" 11100 11100

echo "Munge and Slurm user setup complete."
echo "------------------------------------------------------------------------------------------------------------------------------"

# Set up NFS server
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Setting up NFS server"
echo "------------------------------------------------------------------------------------------------------------------------------"
# Mount /sched and /shared from the scheduler node
mkdir -p /sched
mkdir -p /shared
echo "$ip_address:/sched /sched nfs defaults 0 0" >> /etc/fstab
echo "$ip_address:/shared /shared nfs defaults 0 0" >> /etc/fstab
mount -a
echo "NFS setup complete."
echo "------------------------------------------------------------------------------------------------------------------------------"

# setting up Microsoft repo and installing Packages
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Setting up Microsoft repo and installing Slurm packages"
echo "------------------------------------------------------------------------------------------------------------------------------"
case "$OS_ID" in
    almalinux)
        # Setup Microsoft repository if not already present
        if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ]; then
            echo "Setting up Microsoft repository..."
            curl -sSL -O https://packages.microsoft.com/config/rhel/$OS_VERSION/packages-microsoft-prod.rpm        
            rpm -i packages-microsoft-prod.rpm
            rm -f packages-microsoft-prod.rpm
            echo "Microsoft repo setup complete."
        fi

        # Setup Slurm repository
        echo "Setting up Slurm repository..."
        cat <<EOF > /etc/yum.repos.d/slurm.repo
[slurm]
name=Slurm Workload Manager
baseurl=https://packages.microsoft.com/yumrepos/slurm-el8-insiders
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
priority=10
EOF
        echo "Slurm repo setup complete."
        echo "Installing munge packages..."
        dnf install -y epel-release
        dnf install -y munge munge-libs
        echo "Munge installed"
        echo "Installing Slurm packages..."
        slurm_packages="slurm slurm-slurmrestd slurm-libpmi slurm-devel slurm-pam_slurm slurm-perlapi slurm-torque slurm-openlava slurm-example-configs"
        execute_packages="slurm-slurmd"
        for pkg in $slurm_packages; do
                yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
        done
        for pkg in $execute_packages; do
                yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
        done
        echo "Slurm installed"
        ;;

    ubuntu)
        echo "Updating package lists..."
        apt update

        # Extract Ubuntu version
        UBUNTU_VERSION=$(grep -oP '(?<=VERSION_ID=")[0-9.]+' /etc/os-release)

        # Install python3-venv if Ubuntu version is greater than 19
        if [ "$(echo "$UBUNTU_VERSION > 19" | bc)" -eq 1 ]; then
        echo "Installing Python3 virtual environment..."
        DEBIAN_FRONTEND=noninteractive apt -y install python3-venv
        fi

        # Install required dependencies
        echo "Installing required packages and munge..."
        DEBIAN_FRONTEND=noninteractive apt -y install munge libmysqlclient-dev libssl-dev jq

        # Determine Slurm repository based on Ubuntu version
        case "$UBUNTU_VERSION" in
        "22.04") 
        REPO="slurm-ubuntu-jammy"
        ln -sf /lib/x86_64-linux-gnu/libtinfo.so.6.3 /usr/lib/x86_64-linux-gnu/libtinfo.so.6
         ;;
        "20.04") 
        REPO="slurm-ubuntu-focal" 
        ln -sf /lib/x86_64-linux-gnu/libtinfo.so.6.2 /usr/lib/x86_64-linux-gnu/libtinfo.so.6
        ;;
        esac

        echo "Using Slurm repository: $REPO"

        # Add Slurm repository
        echo "Configuring Slurm repository..."
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/$REPO/ insiders main" > /etc/apt/sources.list.d/slurm.list

        # Set repository priorities
        cat <<EOF > /etc/apt/preferences.d/slurm-repository-pin-990
Package: slurm, slurm-*
Pin: origin "packages.microsoft.com"
Pin-Priority: 990

Package: slurm, slurm-*
Pin: origin *ubuntu.com*
Pin-Priority: -1
EOF
        echo "Slurm repository setup complete."

        # Setup Microsoft repository if not already present
        if [ ! -e /etc/apt/sources.list.d/microsoft-prod.list ]; then
            echo "Setting up Microsoft repository..."
            curl -sSL -O https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/packages-microsoft-prod.deb
            dpkg -i packages-microsoft-prod.deb
            rm -f packages-microsoft-prod.deb
            echo "Microsoft repo setup complete."
        fi
        apt update
        slurm_packages="slurm-smd slurm-smd-client slurm-smd-dev slurm-smd-libnss-slurm slurm-smd-libpam-slurm-adopt slurm-smd-slurmrestd slurm-smd-sview"
        for pkg in $slurm_packages; do
                DEBIAN_FRONTEND=noninteractive apt install -y $pkg=$SLURM_VERSION
                apt-mark hold $pkg
        done

        DEBIAN_FRONTEND=noninteractive apt install -y slurm-smd-slurmd=$SLURM_VERSION 
        apt-mark hold slurm-smd-slurmd
	DEBIAN_FRONTEND=noninteractive apt install -y libhwloc15
	ln -sf /lib/x86_64-linux-gnu/libreadline.so.8 /usr/lib/x86_64-linux-gnu/libreadline.so.7
        ln -sf /lib/x86_64-linux-gnu/libhistory.so.8 /usr/lib/x86_64-linux-gnu/libhistory.so.7
        ln -sf /lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.6
        ln -sf /usr/lib64/libslurm.so.38 /usr/lib/x86_64-linux-gnu/
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac
echo "------------------------------------------------------------------------------------------------------------------------------"


# Install and configure Munge
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "configuring Munge"
echo "------------------------------------------------------------------------------------------------------------------------------"
cp "$sched_dir/munge.key" "$munge_key" 
chown munge:munge "$munge_key"
chmod 400 "$munge_key"
systemctl stop munge
systemctl start munge
systemctl enable munge
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Munge configured"
echo "------------------------------------------------------------------------------------------------------------------------------"


# Configure Slurm
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Configuring Slurm"
echo "------------------------------------------------------------------------------------------------------------------------------"

# Set permissions and create symlinks

ln -s "$slurm_conf" /etc/slurm/slurm.conf
ln -s "$sched_dir/keep_alive.conf" /etc/slurm/keep_alive.conf
ln -s "$sched_dir/cgroup.conf" /etc/slurm/cgroup.conf
ln -s "$sched_dir/accounting.conf" /etc/slurm/accounting.conf
ln -s "$sched_dir/azure.conf" /etc/slurm/azure.conf
ln -s "$sched_dir/gres.conf" /etc/slurm/gres.conf 
chown  slurm:slurm "$sched_dir"/*.conf
chmod 644 "$sched_dir"/*.conf
chown slurm:slurm /etc/slurm/*.conf

# Set up log and spool directories
mkdir -p /var/spool/slurmd  /var/log/slurmd 
chown slurm:slurm /var/spool/slurmd  /var/log/slurmd 

echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Slurm configured"
echo "------------------------------------------------------------------------------------------------------------------------------"
