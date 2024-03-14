#!/bin/bash

#######################################################
#   shdwNode Install Script                           #
#   This script is provided by GenesysGo to assist    #
#   in installation and may not work in all machines  #
#   or use cases.  Use with care.                     #
#######################################################

cat << "EOF"
                                                                                       =:--:       
                                                        :                       .--..*.-.      
                                                         :+:                 .*###.*#--:..      
                                                        .. ::            .:########::-:..       
              .__         .___                          ....- ....  .*#% +%%%%#*=::..         
         _____|  |__    __| _/_  _  __                   ..---..+%%%%#%%#%%*=-.....          
        /  ___/  |  \  / __ |\ \/ \/ /                    --=---::##@%@#+=:.....             
        \___ \|   Y  \/ /_/ | \     /                -----*....--%%*=:.....                  
       /____  >___|  /\____ |  \/\_/               ----:  :-#%.  +-:......                  
            \/     \/      \/                   --:::  :--     %* ......                    
                                              -:::   :-.     :+--== ....                     
                                           -:::  .--      =-:......: ...                     
                                       --:::  .--     ==:....      .. :.                     
                                    -:-:.  :-      =-....           .: :.                    
                                 -:::   --     =-...                  ..                     
                              -:::  :=.    .=:..                                             
                           ----:::      =-..                                                 
                        ----:.      ==:..                                                    
                     =---- ......=:..                                                        
                  ----:......=-..      .___                 __         .__  .__                
               -=--:.::::-=..          |   | ____   _______/  |______  |  | |  |   ___________ 
            ----.::---+:.              |   |/    \ /  ___/\   __\__  \ |  | |  | _/ __ \_  __ \ 
         ----:----*:.                  |   |   |  \\___ \  |  |  / __ \|  |_|  |_\  ___/|  | \/  
       :-:--=++=.                      |___|___|  /____  > |__| (____  /____/____/\___  >__|    
     .-+++*=.                                   \/     \/            \/               \/        
   =+++-                                                                                     
=+=.                                                                                        
EOF

SHDW_NODE_PATH="/home/dagger/shdw-node"        
KEYGEN_PATH="/home/dagger/shdw-keygen"        
ID_PATH="/home/dagger/id.json"
SHDW_NODE_URL="https://shdw-drive.genesysgo.net/4xdLyZZJzL883AbiZvgyWKf2q55gcZiMgMkDNQMnyFJC/shdw-node"
KEYGEN_URL="https://shdw-drive.genesysgo.net/4xdLyZZJzL883AbiZvgyWKf2q55gcZiMgMkDNQMnyFJC/shdw-keygen-latest"
SERVICE_NAME="shdw-node.service"
CONFIG_FILE="/home/dagger/config.toml"
TRUSTED_NODES=(
    "184.154.98.116:2030"
    "184.154.98.117:2030"
    "184.154.98.118:2030"
    "184.154.98.119:2030"
    "184.154.98.120:2030"
)

install() {
  ### Dagger user check
  check_dagger_user
  ### Install Dependencies
  install_dependencies


### Get number of CPU cores
NUM_CPU=$(lscpu | grep "^CPU(s):" | awk '{print $2}')

### get the thread(s) per core
# threads_per_core=$(lscpu | grep "^Thread(s) per core:" | awk '{print $4}')
# CPU_THREADS=$(($NUM_CPU*$threads_per_core))

### Get total RAM in GB
TOTAL_RAM=$(awk '/MemTotal/ {printf "%.3f\n", $2/1024/1024}' /proc/meminfo)

### Get OS information
OS=$(lsb_release -d)
CURRENT_VERSION=$(uname -r | cut -c1-4)

if [[ $OS != *"Ubuntu 22.04"* ]]; then
  echo "Currently only Ubuntu 22.04 is officially supported. If you are installing with a different OS, you may run into issues."
fi

echo ""
echo "Number of CPUs: $NUM_CPU"
# echo "Number of CPU Threads: $CPU_THREADS"
echo "Total RAM: $TOTAL_RAM GB"
echo "$OS"
echo "Current Kernel Version: $CURRENT_VERSION"

### Checks CPU, RAM, User
system_checks

###############
### Install ###
###############

#Make Folders
make_folders

# Run Keygen
keygen

#Create config.toml
create_config

#make sysctl changes and save
sysctl_changes
sudo sysctl -p

#build start_shdw_node.sh with cpu config
start_shdw_node_build
chmod +x start-shdw-node.sh

#Make shdw_node service
make_shdw_node_service

echo "Install complete, would you like to enable the service now? (yes/no)"
read input
if [[ $input == "no" ]] || [[ $input == "n" ]]; then
  echo "Please enable the service from the main menu when ready."
  sleep 1
elif [[ $input == "yes" ]] || [[ $input == "y" ]]; then
  echo "Enabling now..."
  sudo systemctl enable --now shdw-node.service
  sleep 1
else
  echo "Please enable the service from the main menu when ready."
  sleep 1
fi


### Check Status
OUTPUT=$(sudo systemctl is-active $SERVICE_NAME)

echo ""
echo "Install is complete.  Installation status: $OUTPUT"
echo "IMPORTANT: PLEASE LOGOUT AND/OR EXIT FROM THE DAGGER USER AND LOG BACK IN."
echo "THESE CHANGES WILL NOT APPLY UNTIL YOU DO.  IF YOU DO NOT, YOU MAY RUN INTO FILE ISSUES."
echo ""
}

upgrade() {
  STATUS=$(sudo systemctl is-active $SERVICE_NAME)
  if [ -f "/etc/systemd/system/wield.service" ]; then
    echo "This version upgrade requires a full reinstall due to some naming and functionality changes.  Please do a full uninstall and re-install"
    echo "by running the uninstall command from the menu and then the install command."
    exit 1
  fi
  if [ -f "/home/dagger/wield" ]; then
    echo "This version upgrade requires a full reinstall due to some naming and functionality changes.  Please do a full uninstall and re-install"
    echo "by running the uninstall command from the menu and then the install command."
    exit 1
  fi
  if [ "$(whoami)" != "dagger" ]; then
    echo "Current user is not dagger, please ensure that you are user dagger, in directory /home/dagger ."
    echo "Exiting..."
    exit 1
  fi

  output=$(/home/dagger/shdw-node --version 2>&1)
  # Check if the command execution was successful and the output is not empty
  if [ $? -ne 0 ] || [ -z "$output" ]; then
      echo "Error occurred or shdwNode is not installed, please run the install from the main menu." 
      echo "Exiting..."
      sleep 1
      exit 1
  fi
  version=$(echo "$output" | awk '{print $2}')

  if check_trusted_nodes; then
      echo ""
      echo "Current configuration is still valid, continuing with upgrade..."
      echo ""
      sleep 1
  else
      echo ""
      echo "Current version requires updates to the config.toml and possibly other changes."
      echo "A full uninstall is required before being able to proceed, please run the uninstaller and re-run the installer"
      echo ""
      sleep 1
      exit 1
  fi

  if [ -f "$SHDW_NODE_PATH" ]; then
      echo "shdwNode Found...Checking if shdwNode service is running."

      if [[ $STATUS == "active" ]]; then
        echo "shdwNode service is running.  Are you trying to upgrade? (yes/no)"
          read input
          if [[ $input == "no" ]] || [[ $input == "n" ]]; then
            echo "Exiting..."
            exit 1
          fi

          echo "Attempting to stop service and upgrade..."
          sleep 1


          # Attempt to stop the service
          sudo systemctl stop "$SERVICE_NAME"

          STATUS=$(sudo systemctl is-active $SERVICE_NAME)
          if [[ $STATUS == "inactive" ]]; then
              echo "Service stopped successfully.  Downloading latest file..."
              sleep 1
              rm "$SHDW_NODE_PATH"
              wget -O "$SHDW_NODE_PATH" "$SHDW_NODE_URL"

              # Check if wget was successful
              if [ $? -eq 0 ]; then
                  echo "New shdwNode binary downloaded successfully."
              else
                  echo "Failed to download new binary.  Check your internet connection and restart."
                  exit 1
              fi

              chmod +x $SHDW_NODE_PATH
              rm /home/dagger/config.toml
              create_config

              # Optionally, you can start the service again if you want
              # sudo systemctl start "$SERVICE_NAME"
              sleep 2

              # STATUS=$(sudo systemctl is-active $SERVICE_NAME)
              echo "shdwNode upgrade complete."
              check_shdw_node_status
              echo "Please wait 5 epochs before restarting the service. Monitor progress at https://dagger-hammer.shdwdrive.com/explorer"
              echo "You can restart it via the main menu."
              echo ""
              echo ""
          else
              echo "Failed to stop the shdwNode service.  Check systemctl status shdw-node.service for more information."
              exit 1
          fi
      elif [[ $STATUS == "inactive" ]]; then
        echo "Service is currently stopped.  Are you trying to upgrade (yes/no)?"
              read input 
              if [[ $input == "no" ]] || [[ $input == "n" ]]; then
                echo "Exiting..."
                exit 1
              elif [[ $input == "yes" ]] || [[ $input == "y" ]]; then
                rm "$SHDW_NODE_PATH"
                wget -O "$SHDW_NODE_PATH" "$SHDW_NODE_URL"

                # Check if wget was successful
                if [ $? -eq 0 ]; then
                  echo "New shdwNode binary downloaded successfully."
                else
                  echo "Failed to download new binary.  Check your internet connection and restart."
                  exit 1
                fi
              fi
              # Optionally, you can start the service again if you want
              chmod +x $SHDW_NODE_PATH

              rm /home/dagger/config.toml
              create_config

              # sudo systemctl start "$SERVICE_NAME"
              sleep 2

              # STATUS=$(sudo systemctl is-active $SERVICE_NAME)
              echo "Upgrade complete."
              check_shdw_node_status
              echo "Please wait 5 epochs before restarting the service. Monitor progress at https://dagger-hammer.shdwdrive.com/explorer"
              echo "You can restart it via the main menu."
              echo ""
              echo ""

      elif [[ $STATUS == "failed" ]]; then
        echo "Service is currently failed, or was disabled.  Are you trying to upgrade (yes/no)?  This upgrade will fail if you have not ran the installer."
              read input 
              if [[ $input == "no" ]] || [[ $input == "n" ]]; then
                echo "Exiting..."
                exit 1
              elif [[ $input == "yes" ]] || [[ $input == "y" ]]; then
                rm "$SHDW_NODE_PATH"
                wget -O "$SHDW_NODE_PATH" "$SHDW_NODE_URL"

                # Check if wget was successful
                if [ $? -eq 0 ]; then
                  echo "New shdwNode binary downloaded successfully."
                else
                  echo "Failed to download new binary.  Check your internet connection and restart."
                  exit 1
                fi
              fi

              chmod +x $SHDW_NODE_PATH
              rm /home/dagger/config.toml
              create_config

              # sudo systemctl start "$SERVICE_NAME"
              sleep 2

              # STATUS=$(sudo systemctl is-active $SERVICE_NAME)
              echo "Upgrade complete."
              check_shdw_node_status
              echo "Please wait 5 epochs before restarting the service. Monitor progress at https://dagger-hammer.shdwdrive.com/explorer"
              echo "You can restart it via the main menu."
              echo ""
              echo ""
              exit 1
      else
        failed_service 
      fi
  else
    echo "shdwNode binary was not found.  It is recommended to run the uninstall tool and do a full reinstall.  Do you still wish to continue? (yes/no)"
    if [[ $input == "no" ]] || [[ $input == "n" ]]; then
      echo "Exiting..."
      exit 1
    fi
    failed_service 
  fi
}




uninstall() {
  echo "This will remove all D.A.G.G.E.R. components from the server, and is not reversible.  You will need to run the installer again to reinstall."
  echo "Do you wish to continue? (yes/no)"
  read input
  if [[ $input == "no" ]] || [[ $input == "n" ]]; then
    echo "Exiting..."
    exit 1
  elif [[ $input == "yes" ]] || [[ $input == "y" ]]; then
    sudo systemctl stop shdw-node.service
    sudo systemctl disable shdw-node.service
    sudo rm /etc/systemd/system/shdw-node.service
    sudo systemctl stop wield.service
    sudo systemctl disable wield.service
    sudo rm /etc/systemd/system/wield.service
    sudo rm -rf /mnt/dag/historydb > /dev/null 2>&1
    rm /home/dagger/config.toml > /dev/null 2>&1
    rm /home/dagger/shdw-node > /dev/null 2>&1 
    rm /home/dagger/wield > /dev/null 2>&1 
    rm /home/dagger/shdw-keygen > /dev/null 2>&1 
    rm /home/dagger/start_wield.sh > /dev/null 2>&1 
    rm /home/dagger/start-shdw-node.sh > /dev/null 2>&1 
    rm -rf /home/dagger/snapshots > /dev/null 2>&1
    rm -rf /home/dagger/trust_peer_snapshot > /dev/null 2>&1
    rm -rf /home/dagger/dbs > /dev/null 2>&1
    rm -rf /home/dagger/replicated_db_init_from_snapshot > /dev/null 2>&1
    rm /home/dagger/trusted_peer_snapshot > /dev/null 2>&1
    echo "shdwNode has been uninstalled."
    echo "Exiting..."
    exit 1
  fi
}

# Updates the config.toml based on current requirements
create_config() {
  # Join the array elements with comma and space
  joined_nodes=$(printf ", \"%s\"" "${TRUSTED_NODES[@]}")
  # Remove the leading comma and space
  joined_nodes="[${joined_nodes:2}]"

  cat > /home/dagger/config.toml 2> /dev/null << EOF
trusted_nodes = $joined_nodes
dagger = "JoinAndRetrieve"
[node_config]
socket = 2030
keypair_file = "id.json"
[storage]
peers_db = "dbs/peers.db"
EOF
}

sysctl_changes(){ 

echo "
*               soft    nofile          5000000
*               hard    nofile          5000000
" | sudo tee /etc/security/limits.conf

echo "# set default and maximum socket buffer sizes to 12MB
net.core.rmem_default=12582912
net.core.wmem_default=12582912
net.core.rmem_max=12582912
net.core.wmem_max=12582912
# make changes for ulimit
fs.nr_open = 5000000
# set minimum, default, and maximum tcp buffer sizes (10k, 87.38k (linux default), 12M resp)
net.ipv4.tcp_rmem=10240 87380 12582912
net.ipv4.tcp_wmem=10240 87380 12582912
# Enable TCP westwood for kernels greater than or equal to 2.6.13
net.ipv4.tcp_congestion_control=westwood
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_low_latency=1
# don't cache ssthresh from previous connection
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
# kernel Tunes
kernel.timer_migration=0
kernel.hung_task_timeout_secs=30
# A suggested value for pid_max is 1024 * <# of cpu cores/threads in system>
kernel.pid_max=65536
# vm.tuning
vm.swappiness=30
vm.max_map_count=1000000
vm.stat_interval=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
vm.min_free_kbytes = 3000000
vm.dirty_expire_centisecs=36000
vm.dirty_writeback_centisecs=3000
vm.dirtytime_expire_seconds=43200
" | sudo tee /etc/sysctl.conf
}

start_shdw_node_build() {
NUM_CPU=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
PROC_THREADS=$NUM_CPU
COMMS_THREADS=2
GLOBAL_THREADS=$NUM_CPU

cat > /home/dagger/start-shdw-node.sh 2> /dev/null << EOF
#!/bin/bash
PATH=/home/dagger
exec shdw-node \
--processor-threads $PROC_THREADS \
--global-threads $GLOBAL_THREADS \
--comms-threads $COMMS_THREADS \
--log-level info \
--history-db-path /mnt/dag/historydb \
--config-toml config.toml
EOF
}


keygen() {
  if [ -f "$ID_PATH" ]; then
      # Notify the user that the file exists
      wget -O "$KEYGEN_PATH" "$KEYGEN_URL"
      chmod +x /home/dagger/shdw-keygen
      echo "Key file path exists. Continuing with install..."

  else
      # (Optional) Notify the user that the file does not exist
      echo "Key file path does not exist. Would you like to create a new key? (yes/no)"
      read input
      if [[ $input == "no" ]] || [[ $input == "n" ]]; then
        echo "Please enable the service from the main menu when ready."
        sleep 1
      elif [[ $input == "yes" ]] || [[ $input == "y" ]]; then
        echo "Enabling now..."
        wget -O "$KEYGEN_PATH" "$KEYGEN_URL"
        chmod +x /home/dagger/shdw-keygen
        ./shdw-keygen new -o ~/id.json
        echo ""
        echo "************************************************************************************"
        echo "IMPORTANT: PLEASE COPY DOWN YOUR RECOVERY KEY.  THIS WILL ONLY BE SHOWN ONCE."
        echo "************************************************************************************"
        echo ""
        shopt -s nocasematch
        while true; do
          read -n 1 -r -p "Press 'y' to continue or any other key to repeat: "
          echo "" 
          if [[ $REPLY == 'y' ]]; then
            break
          else
            echo -e "You pressed: '$REPLY', please press 'y' to continue."
          fi
        done
        shopt -u nocasematch
      else
        echo "Something went wrong.  Verify that the file path exists or restore the file from backup."
        sleep 1
      fi

  fi

}

make_folders(){
    rm "$SHDW_NODE_PATH"
    wget -O "$SHDW_NODE_PATH" "$SHDW_NODE_URL"
    chmod +x /home/dagger/shdw-node

    echo "making historydb dir..."
    sleep 1
    sudo mkdir -p /mnt/dag/historydb
    sudo chown -R dagger:dagger /mnt/dag/*

    echo "making snapshots dir..."
    sleep 1
    mkdir -p /home/dagger/snapshots
}



make_shdw_node_service(){
    echo "[Unit]
Description=shdwNode Service
After=network.target
[Service]
User=dagger
WorkingDirectory=/home/dagger
ExecStart=/home/dagger/start-shdw-node.sh
Restart=always
[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/shdw-node.service
}

checkWieldService() {
  # Use systemctl to check if wield.service is active
  if systemctl is-active shdw-node.service ; then
    # If the service is running, print the message and exit the function
    echo "This version upgrade requires a full reinstall due to some naming and functionality changes.  Please do a full uninstall and re-install"
    echo "by running the uninstall command from the menu and then the install command."
    exit 1
  fi
}


system_checks() {
    ### Check if CPU cores is less than 16
    if (( NUM_CPU < 16 )); then
    echo ""
    echo "WARNING: Your machine has less than 16 CPU cores and will have performance issues running a shdwNode."
    echo "Please ensure that your machine meets the minimum requirements as they have recently changed during testnet."
    echo "Please see here for more information: https://docs.shdwdrive.com/wield#1.-node-requirements"
    echo ""
    echo "This is now a hard requirement for testnet.  Exiting..."
    exit 1
    fi

    ### Check if total RAM is less than 32 GB
    if (( $(echo "$TOTAL_RAM < 31" | bc -l) )); then
    echo "WARNING: Your machine has less than 32 GB of RAM and will have performance issues running a shdwNode."
    echo "Please ensure that your machine meets the minimum requirements.  Please see here for more information: https://docs.shdwdrive.com/wield#1.-node-requirements"
    fi
    ### Check dagger user
    if [ "$(whoami)" != "dagger" ]; then
    echo "This script must be run as dagger, please change to the dagger user or create the user based on the instructions found here: https://docs.shdwdrive.com/wield#3.-node-configuration" 1>&2
    echo "Use this to change to the dagger user:"
    echo "sudo su - dagger"
    echo ""
    echo "Exiting..."
    exit 1
    fi
    ### Review
    echo "Please review the information above has met the minimum install requirements."
    echo ""
    echo "16 Core CPU, 32GB RAM, Ubuntu 22.04, Kernel Version 5.15 or greater."
    echo ""
    echo "**Do you wish to continue with the installation? (yes/no)**"
    read input
    if [[ $input == "no" ]] || [[ $input == "n" ]]; then
    echo "Exiting..."
    exit 1
    fi
}

install_dependencies() {
    echo "Checking installer dependencies..."
    if ! dpkg -s bc >/dev/null 2>&1; then
    echo "Package 'bc' is not installed. Installing it now..."
    sudo apt-get update

    # Install the 'bc' package
    sudo apt-get install -y bc

    echo "Package 'bc' has been installed."
    else
    echo "Package 'bc' is already installed.  Continuing..."
    fi
}



# Check for failed services if service is not running
failed_service() {
  echo "Service is currently failed, disabled, or not found.  Are you trying to upgrade (yes/no)?  This upgrade will fail if you have not ran the installer."
        read input 
        if [[ $input == "no" ]] || [[ $input == "n" ]]; then
          echo "Exiting..."
          exit 1
        elif [[ $input == "yes" ]] || [[ $input == "y" ]]; then

          if [ "$(pwd)" != "/home/dagger" ]; then
            echo "Error: Installer must be run from /home/dagger, please rerun from that directory."
            echo "Exiting..."
            exit 1
          fi
          rm "$SHDW_NODE_PATH"
          wget -O "$SHDW_NODE_PATH" "$SHDW_NODE_URL"

          # Check if wget was successful
          if [ $? -eq 0 ]; then
            echo "New shdwNode binary downloaded successfully."
          else
            echo "Failed to download new binary.  Check your internet connection and restart."
            exit 1
          fi
        fi

        chmod +x $SHDW_NODE_PATH
        rm /home/dagger/config.toml
        create_config

        # sudo systemctl start "$SERVICE_NAME"
        sleep 2

        # STATUS=$(sudo systemctl is-active $SERVICE_NAME)
        echo "Upgrade complete."
        check_shdw_node_status
        echo "Please wait 5 epochs before restarting the service. Monitor progress at https://dagger-hammer.shdwdrive.com/explorer"
        echo "You can restart it via the main menu."
        echo ""
        echo ""
  exit 1
}

setup_logrotate() {
  logrotate_file="/etc/logrotate.d/shdw-node.conf"

  config_content="/home/dagger/config.log {
    su dagger dagger
    daily
    rotate 5
    size 10M
    missingok
    copytruncate
    delaycompress
    compress
}"
  echo "$config_content" | sudo tee "$logrotate_file" > /dev/null
  if [ $? -ne 0 ]; then
    echo "Failed to write logrotate file to $logrotate_file"
    exit 1
  fi
  echo "Logrotate configuration has been written to $logrotate_file"
  sudo systemctl restart logrotate.service
  sleep 1
  if [ $? -ne 0 ]; then
      echo "Failed to restart the logrotate service.  Please ensure logrotate is installed."
      exit 1
  fi
  echo "The logrotate service has been restarted."
  sleep 1
}

#########################################
#            shdwNode Functions         #
#########################################

check_shdw_node_version() {
  if [ -f "$SHDW_NODE_PATH" ]; then
    echo ""
    /home/dagger/shdw-node --version
    echo ""
    sleep 1
  else
    echo ""
    echo "shdwNode Binary (wield) not found at Current Directory: $(pwd).  Please ensure you've installed previously or are located in /home/dagger"
    echo ""
    sleep 1
  fi
}

check_shdw_node_status() {
  STATUS=$(sudo systemctl is-active $SERVICE_NAME)
  if [[ $STATUS == "active" ]]; then
    echo ""
    echo "******************************************************************"
    echo "shdwNode service is currently active."
    echo "******************************************************************"
    echo ""
    sleep 1
  elif [[ $STATUS == "inactive" ]]; then
    echo ""
    echo "******************************************************************"
    echo "shdwNode service is currently inactive."
    echo "******************************************************************"
    echo ""
    sleep 1
  elif [[ $STATUS == "failed" ]]; then
    echo ""
    echo "******************************************************************"
    echo ""
    echo "shdwNode service is currently failed or missing."  
    echo "Please run the installer to continue."
    echo ""
    echo "******************************************************************"
    echo ""
    sleep 1
  fi
}

stop_shdw_node() {
  sudo systemctl stop shdw-node.service
  sleep 1
  check_shdw_node_status
}

start_shdw_node() {
  sudo systemctl start shdw-node.service
  sleep 1
  check_shdw_node_status
}

get_node_id() {
    local keygen_command="/home/dagger/shdw-keygen"
    if [[ -x "$keygen_command" ]]; then
        local output=$("$keygen_command" pubkey id.json)
        if [ $? -eq 0 ]; then
            echo "******************************************************"
            echo "Node ID: $output"
            echo "******************************************************"
        else
            echo "Failed to retrieve node ID" >&2
        fi
    else
        echo ""
        echo "Error: The keygen binary does not exist or is not executable at '$keygen_command'.  Please run the installer or restore your file from a backup." >&2
        echo ""
    fi
}

shdw_service_menu() {
  while true; do
        echo "shdwNode Service Menu - Please select an option:"
        select sub_option in "Check shdwNode Status" "Start shdwNode Service" "Stop shdwNode Service" "Check shdwNode Version" "Return to main menu"; do
            case $REPLY in
                1) check_shdw_node_status; break;;
                2) start_shdw_node; break;;
                3) stop_shdw_node; break;;
                4) check_shdw_node_version; break;;
                5) return ;;
                *) echo "Invalid option! Please try again." ;;
            esac
        done
    done
}

check_trusted_nodes() {
  local all_ips_found=true
  for ip in "${TRUSTED_NODES[@]}"; do
      if ! grep -q "$ip" "$CONFIG_FILE"; then
          all_ips_found=false
          break
      fi
  done

  # Return status: 0 (true) if all IPs found, 1 (false) if any is missing
  $all_ips_found
}
# Function to compare versions for upgrade
version_lt() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

# Checks dagger user and creates account
check_dagger_user() {
  if ! getent passwd dagger > /dev/null 2>&1; then
    echo "User dagger was not found, creating..."
    sudo useradd -m -s /bin/bash dagger
    echo "Please enter a new password for dagger:"
    sudo passwd dagger
    sudo usermod -aG sudo dagger
    sudo cp shdw-node-installer.sh /home/dagger/
    sudo chown dagger:dagger /home/dagger/shdw-node-installer.sh
    echo "Please re-run this script as the dagger user."
    echo "******************************************************************"
    echo "To switch users: sudo su - dagger"
    echo "******************************************************************"
    echo "Exiting..."
    exit 1
  else
    echo "User dagger already exists, continuing with install..."
  fi
}

while true; do
    echo "Welcome to the D.A.G.G.E.R. shdwNode Installer - Please select an option:"
    select option in "Install" "Upgrade" "Check shdwNode Status or Start/Stop" "Get Node ID" "Setup Logrotate for shdwNode" "Uninstall" "Exit"; do
        case $REPLY in
            1) install; break ;;
            2) upgrade; break ;;
            3) shdw_service_menu; break;;
            4) get_node_id; break;;
            5) setup_logrotate; break;;
            6) uninstall; break;;
            7) exit 0 ;;
            *) echo "Invalid option! Please try again." ;;
        esac
    done
done
