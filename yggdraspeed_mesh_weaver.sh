#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Enable color output
enable_color() {
    if [ -t 1 ]; then
        ncolors=$(tput colors)
        if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
            COLOR_SUPPORT=true
        else
            COLOR_SUPPORT=false
        fi
    fi
}

enable_color

show_banner() {
    echo -e "\033[0m"  # Reset color
    echo -e "\033[38;5;43m███████╗ ██████╗██████╗ ██╗██████╗ ████████╗\033[38;5;48m    ███╗   ██╗██╗███╗   ██╗     ██╗ █████╗ "
    echo -e "\033[38;5;43m██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝\033[38;5;48m    ████╗  ██║██║████╗  ██║     ██║██╔══██╗"
    echo -e "\033[38;5;42m███████╗██║     ██████╔╝██║██████╔╝   ██║   \033[38;5;47m    ██╔██╗ ██║██║██╔██╗ ██║     ██║███████║"
    echo -e "\033[38;5;41m╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   \033[38;5;46m    ██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║"
    echo -e "\033[38;5;41m███████║╚██████╗██║  ██║██║██║        ██║   \033[38;5;46m    ██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║"
    echo -e "\033[38;5;40m╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   \033[38;5;82m    ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝"
    echo -e "\033[0m"  # Reset color
    echo -e "\033[1;38;5;36m                     Yggdrasil Configuration Tool"
    echo -e "\033[1;38;5;36m                     ============================\033[0m"
}

clear_screen() {
    clear
}

# Function to get user input
get_input() {
    read -rp "$1: " value
    echo "$value"
}

# Function to select protocol
select_protocol() {
    while true; do
        select protocol in TCP TLS QUIC
        do
            case $protocol in
                TCP|TLS|QUIC) 
                    echo "${protocol,,}"
                    return
                    ;;
                *) 
                    break
                    ;;
            esac
        done
    done
}

# Main setup function
run_setup() {
    clear_screen
    show_banner

    echo "Installing Yggdrasil..."
    if ! sudo apt-get install -y yggdrasil; then
        echo "Failed to install Yggdrasil. Please check your internet connection and try again."
        read -rp "Press Enter to return to the main menu..."
        show_main_menu
        return
    fi

    clear_screen
    show_banner

    # Create admin socket
    sudo mkdir -p /var/run/yggdrasil
    sudo chown yggdrasil:yggdrasil /var/run/yggdrasil

    # Generate private key
    private_key=$(yggdrasil -genconf | grep PrivateKey | awk '{print $2}')

    ipv4_address=$(get_input "Enter your IPv4 address")
    echo "Select a protocol:"
    protocol=$(select_protocol)
    node_name=$(get_input "Enter your node name")

    read -rp "Do you want to set a custom port? (default is 9101) (y/N): " custom_port_choice
    if [[ "$custom_port_choice" == "y" || "$custom_port_choice" == "Y" ]]; then
        while true; do
            read -rp "Enter custom port number (1024-65535): " port
            if [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1024 && "$port" -le 65535 ]]; then
                break
            else
                echo "Invalid port number. Please enter a number between 1024 and 65535."
            fi
        done
    else
        port=9101
    fi

    config_file="/etc/yggdrasil/yggdrasil.conf"
    if [ -f "$config_file" ]; then
        read -rp "Configuration file already exists. Overwrite? (y/N): " overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            echo "Setup aborted."
            read -rp "Press Enter to return to the main menu..."
            show_main_menu
            return
        fi
    fi

    sudo tee "$config_file" > /dev/null <<EOL
{
  "AdminListen": "unix:///var/run/yggdrasil/yggdrasil.sock",

  "Peers": [
    "${protocol}://${ipv4_address}:${port}"
  ],

  "Listen": [
    "${protocol}://[::]:${port}"
  ],

  "PrivateKey": "${private_key}",

  "LinkLocalTCPPort": 0,

  "IfMTU": 65535,

  "SessionFirewall": {
    "Enable": true,
    "AllowFromDirect": true,
    "AllowFromRemote": false,
    "AlwaysAllowOutbound": true
  },

  "Logging": {
    "LogLevel": "info",
    "LogTo": "syslog"
  },

  "NodeInfo": {
    "name": "${node_name}"
  }
}
EOL

    sudo systemctl restart yggdrasil
    sudo systemctl enable yggdrasil

    # Display Yggdrasil IPv6 address
    clear_screen
    show_banner
    echo "Your Yggdrasil IPv6 address is:"
    sudo yggdrasil -useconffile /etc/yggdrasil/yggdrasil.conf -address

    echo "Yggdrasil configuration complete!"
    read -rp "Press Enter to return to the main menu..."
    show_main_menu
}

run_optimizer() {
    clear_screen
    show_banner
    echo "Running TurboTux BBR FQ-CoDel Optimizer..."
    git clone https://github.com/ScriptNinja-GNU/TurboTux-BBR-FQ-CoDel-Optimizer.git
    cd TurboTux-BBR-FQ-CoDel-Optimizer || exit
    chmod +x setup_bbr_fq_codel.sh
    sudo ./setup_bbr_fq_codel.sh
    cd ..
    rm -rf TurboTux-BBR-FQ-CoDel-Optimizer
    echo "Optimization complete. Press Enter to return to the main menu..."
    read -r
    show_main_menu
}

# Function to add a new peer
add_peer() {
    clear_screen
    show_banner
    echo "Adding a new peer"
    echo "================="

    # Get the protocol and IP address from the user
    protocol=$(select_protocol)
    ipv4_address=$(get_input "Enter the peer's IPv4 address")

    # Ask user if they want to set a custom port
    read -rp "Do you want to set a custom port? (default is to use the next available port) (y/N): " custom_port_choice
    if [[ "$custom_port_choice" == "y" || "$custom_port_choice" == "Y" ]]; then
        while true; do
            read -rp "Enter custom port number (1024-65535): " port
            if [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1024 && "$port" -le 65535 ]]; then
                break
            else
                echo "Invalid port number. Please enter a number between 1024 and 65535."
            fi
        done
    else
        # Find the next available port starting from 9102
        config_file="/etc/yggdrasil/yggdrasil.conf"
        last_port=$(grep -oP '(?<=:)\d+' "$config_file" | sort -n | tail -1)
        port=$((last_port + 1))
        if [ $port -le 9101 ]; then
            port=9102
        fi
    fi

    # Add the new peer to the configuration file
    sed -i "/\"Peers\": \[/a \    \"${protocol}://${ipv4_address}:${port}\"," "$config_file"

    # Add the corresponding Listen entry
    sed -i "/\"Listen\": \[/a \    \"${protocol}://[::]:${port}\"," "$config_file"

    clear_screen
    show_banner
    echo "Peer and Listen entries added successfully!"
    echo "New peer: ${protocol}://${ipv4_address}:${port}"
    echo "New listen: ${protocol}://[::]:${port}"
    
    # Restart Yggdrasil to apply changes
    sudo systemctl restart yggdrasil

    read -rp "Press Enter to return to the main menu..."
    show_main_menu
}

# Main menu function
show_main_menu() {
    clear_screen
    show_banner
    echo "1. Run Yggdrasil setup"
    echo "2. Add peer"
    echo "3. Run TurboTux BBR FQ-CoDel Optimizer"
    echo "4. Exit"
    echo
    read -rp "Enter your choice (1, 2, 3 or 4): " choice
    case $choice in
        1) run_setup;;
        2) add_peer;;
        3) run_optimizer;;
        4) echo "Exiting..."; exit 0;;
        *) echo "Invalid choice. Please try again."; sleep 2; show_main_menu;;
    esac
}

show_main_menu
