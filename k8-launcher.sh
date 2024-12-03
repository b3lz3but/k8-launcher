#!/bin/bash

# Load configuration if available
CONFIG_FILE="config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Default configurations
KUBECTL_VERSION=${KUBECTL_VERSION:-"$(curl -L -s https://dl.k8s.io/release/stable.txt)"}
MINIKUBE_VERSION=${MINIKUBE_VERSION:-"latest"}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Logging functions with timestamps
log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a k8s_setup.log
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a k8s_setup.log
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log_error "Cannot detect the Linux distribution."
        exit 1
    fi
}

# Function to install a package if not already installed
install_package() {
    if ! command_exists "$1"; then
        log_info "$1 is not installed. Installing..."
        case "$DISTRO" in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y "$1"
                ;;
            fedora|centos|rhel)
                sudo yum install -y "$1"
                ;;
            arch)
                sudo pacman -Syu --noconfirm "$1"
                ;;
            *)
                log_error "Unsupported distribution: $DISTRO"
                exit 1
                ;;
        esac
    else
        log_info "$1 is already installed."
    fi
}

# Function to check for dependencies
check_dependencies() {
    local dependencies=("curl" "sudo" "docker")
    for dep in "${dependencies[@]}"; do
        if ! command_exists "$dep"; then
            log_error "$dep is required but not installed. Please install it first."
            exit 1
        fi
    done
}

# Function to check network connectivity
check_network() {
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Network connectivity is required. Please check your connection."
        exit 1
    fi
}

# Function to detect if running in a virtualized environment
detect_virtualization() {
    if command_exists systemd-detect-virt; then
        VIRT_TYPE=$(systemd-detect-virt)
        if [ "$VIRT_TYPE" != "none" ]; then
            log_info "Running in a virtualized environment: $VIRT_TYPE"
        else
            log_info "Running on bare metal"
        fi
    else
        log_info "Virtualization detection not supported on this system"
    fi
}

# Function to confirm actions
confirm_action() {
    read -p "Are you sure you want to proceed? (y/n): " choice
    case "$choice" in
        y|Y ) return 0 ;;
        * ) log_info "Action cancelled."; return 1 ;;
    esac
}

# Function to start Minikube
start_minikube() {
    log_info "Starting Minikube..."
    if confirm_action; then
        if [ "$(id -u)" -eq 0 ]; then
            # Running as root, use the none driver
            minikube start --driver=none
        else
            # Running as non-root, use the docker driver
            minikube start --driver=docker
        fi
        log_info "Minikube started successfully."
    fi
}

# Function to deploy a sample application
deploy_sample_app() {
    log_info "Deploying sample application..."
    if confirm_action; then
        kubectl create deployment hello-node --image=k8s.gcr.io/echoserver:1.4
        kubectl expose deployment hello-node --type=LoadBalancer --port=8080
        log_info "Sample application deployed successfully."
    fi
}

# Function to monitor system resources
monitor_resources() {
    log_info "Monitoring system resources..."
    echo "CPU Load: $(uptime | awk -F'load average:' '{ print $2 }')"
    echo "Memory Usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "Disk Usage: $(df -h / | grep / | awk '{print $5}')"
}

# Function to create a pod
create_pod() {
    log_info "Creating a new pod..."
    if confirm_action; then
        kubectl run my-pod --image=nginx --restart=Never
        log_info "Pod created successfully."
    fi
}

# Function to create a replicaset
create_replicaset() {
    log_info "Creating a new replicaset..."
    if confirm_action; then
        kubectl create deployment my-replicaset --image=nginx --replicas=3
        log_info "Replicaset created successfully."
    fi
}

# Function to scale a deployment
scale_deployment() {
    read -p "Enter deployment name: " deployment_name
    read -p "Enter number of replicas: " replicas
    if confirm_action; then
        kubectl scale deployment "$deployment_name" --replicas="$replicas"
        log_info "Deployment scaled successfully."
    fi
}

# Function to view logs of a pod
view_pod_logs() {
    read -p "Enter pod name: " pod_name
    if confirm_action; then
        kubectl logs "$pod_name"
    fi
}

# Function to delete a resource
delete_resource() {
    read -p "Enter resource type (pod, deployment, replicaset): " resource_type
    read -p "Enter resource name: " resource_name
    if confirm_action; then
        kubectl delete "$resource_type" "$resource_name"
        log_info "$resource_type $resource_name deleted successfully."
    fi
}

# Function to get cluster info
get_cluster_info() {
    log_info "Fetching cluster information..."
    kubectl cluster-info
}

# Function to list all pods
list_pods() {
    log_info "Listing all pods..."
    kubectl get pods
}

# Function to list all services
list_services() {
    log_info "Listing all services..."
    kubectl get services
}

# Function to manage namespaces
manage_namespaces() {
    echo "1) Create a namespace"
    echo "2) Delete a namespace"
    read -p "Choose an option: " ns_choice
    case $ns_choice in
        1)
            read -p "Enter namespace name: " ns_name
            if confirm_action; then
                kubectl create namespace "$ns_name"
                log_info "Namespace $ns_name created successfully."
            fi
            ;;
        2)
            read -p "Enter namespace name: " ns_name
            if confirm_action; then
                kubectl delete namespace "$ns_name"
                log_info "Namespace $ns_name deleted successfully."
            fi
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
}

# Function to update tools
update_tools() {
    log_info "Updating kubectl and minikube..."
    if confirm_action; then
        install_kubectl
        install_minikube
        log_info "Tools updated successfully."
    fi
}

# Function to manage RBAC
manage_rbac() {
    echo "1) Create a role"
    echo "2) Create a role binding"
    read -p "Choose an option: " rbac_choice
    case $rbac_choice in
        1)
            read -p "Enter role name: " role_name
            read -p "Enter namespace: " ns_name
            if confirm_action; then
                kubectl create role "$role_name" --verb=get,list,watch --resource=pods -n "$ns_name"
                log_info "Role $role_name created successfully in namespace $ns_name."
            fi
            ;;
        2)
            read -p "Enter role binding name: " rb_name
            read -p "Enter role name: " role_name
            read -p "Enter service account name: " sa_name
            read -p "Enter namespace: " ns_name
            if confirm_action; then
                kubectl create rolebinding "$rb_name" --role="$role_name" --serviceaccount="$ns_name":"$sa_name" -n "$ns_name"
                log_info "Role binding $rb_name created successfully in namespace $ns_name."
            fi
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
}

# Function to manage secrets
manage_secrets() {
    echo "1) Create a secret"
    echo "2) View a secret"
    read -p "Choose an option: " secret_choice
    case $secret_choice in
        1)
            read -p "Enter secret name: " secret_name
            read -p "Enter namespace: " ns_name
            read -p "Enter key=value pairs (comma-separated): " kv_pairs
            if confirm_action; then
                kubectl create secret generic "$secret_name" -n "$ns_name" --from-literal="$kv_pairs"
                log_info "Secret $secret_name created successfully in namespace $ns_name."
            fi
            ;;
        2)
            read -p "Enter secret name: " secret_name
            read -p "Enter namespace: " ns_name
            if confirm_action; then
                kubectl get secret "$secret_name" -n "$ns_name" -o yaml
            fi
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
}

# Function to manage persistent volumes
manage_persistent_volumes() {
    echo "1) Create a persistent volume"
    echo "2) Delete a persistent volume"
    read -p "Choose an option: " pv_choice
    case $pv_choice in
        1)
            read -p "Enter persistent volume name: " pv_name
            read -p "Enter storage size (e.g., 1Gi): " storage_size
            if confirm_action; then
                kubectl create pv "$pv_name" --capacity="$storage_size" --access-modes=ReadWriteOnce --host-path=/mnt/data
                log_info "Persistent volume $pv_name created successfully."
            fi
            ;;
        2)
            read -p "Enter persistent volume name: " pv_name
            if confirm_action; then
                kubectl delete pv "$pv_name"
                log_info "Persistent volume $pv_name deleted successfully."
            fi
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
}

# Function to manage service accounts
manage_service_accounts() {
    echo "1) Create a service account"
    echo "2) Delete a service account"
    read -p "Choose an option: " sa_choice
    case $sa_choice in
        1)
            read -p "Enter service account name: " sa_name
            read -p "Enter namespace: " ns_name
            if confirm_action; then
                kubectl create serviceaccount "$sa_name" -n "$ns_name"
                log_info "Service account $sa_name created successfully in namespace $ns_name."
            fi
            ;;
        2)
            read -p "Enter service account name: " sa_name
            read -p "Enter namespace: " ns_name
            if confirm_action; then
                kubectl delete serviceaccount "$sa_name" -n "$ns_name"
                log_info "Service account $sa_name deleted successfully from namespace $ns_name."
            fi
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
}

# Function to display the menu
display_menu() {
    echo "1) Install curl"
    echo "2) Install kubectl"
    echo "3) Install minikube"
    echo "4) Start minikube"
    echo "5) Deploy sample app"
    echo "6) Uninstall kubectl"
    echo "7) Uninstall minikube"
    echo "8) Monitor resources"
    echo "9) Create a pod"
    echo "10) Create a replicaset"
    echo "11) Scale a deployment"
    echo "12) View pod logs"
    echo "13) Delete a resource"
    echo "14) Get cluster info"
    echo "15) List all pods"
    echo "16) List all services"
    echo "17) Manage namespaces"
    echo "18) Update tools"
    echo "19) Manage RBAC"
    echo "20) Manage secrets"
    echo "21) Manage persistent volumes"
    echo "22) Manage service accounts"
    echo "23) Help"
    echo "24) Exit"
}

# Placeholder functions for menu options
install_kubectl() {
    log_info "Installing kubectl version $KUBECTL_VERSION..."
    if confirm_action; then
        curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        log_info "kubectl installed successfully."
    fi
}

install_minikube() {
    log_info "Installing minikube version $MINIKUBE_VERSION..."
    if confirm_action; then
        curl -LO "https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-amd64"
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        log_info "minikube installed successfully."
    fi
}

uninstall_kubectl() {
    log_info "Uninstalling kubectl..."
    if confirm_action; then
        sudo rm /usr/local/bin/kubectl
        log_info "kubectl uninstalled successfully."
    fi
}

uninstall_minikube() {
    log_info "Uninstalling minikube..."
    if confirm_action; then
        sudo rm /usr/local/bin/minikube
        log_info "minikube uninstalled successfully."
    fi
}

# Function to display help
display_help() {
    echo "Help:"
    echo "1) Install curl - Installs the curl command-line tool."
    echo "2) Install kubectl - Installs the Kubernetes command-line tool."
    echo "3) Install minikube - Installs the Minikube tool for running Kubernetes locally."
    echo "4) Start minikube - Starts the Minikube cluster."
    echo "5) Deploy sample app - Deploys a sample application to the Minikube cluster."
    echo "6) Uninstall kubectl - Removes the kubectl tool."
    echo "7) Uninstall minikube - Removes the Minikube tool."
    echo "8) Monitor resources - Displays current CPU, memory, and disk usage."
    echo "9) Create a pod - Creates a new pod using the nginx image."
    echo "10) Create a replicaset - Creates a new replicaset with 3 replicas using the nginx image."
    echo "11) Scale a deployment - Scales a deployment to a specified number of replicas."
    echo "12) View pod logs - Displays logs for a specified pod."
    echo "13) Delete a resource - Deletes a specified Kubernetes resource."
    echo "14) Get cluster info - Displays information about the Kubernetes cluster."
    echo "15) List all pods - Lists all pods in the current namespace."
    echo "16) List all services - Lists all services in the current namespace."
    echo "17) Manage namespaces - Create or delete namespaces."
    echo "18) Update tools - Updates kubectl and minikube to the latest versions."
    echo "19) Manage RBAC - Create roles and role bindings."
    echo "20) Manage secrets - Create and view secrets."
    echo "21) Manage persistent volumes - Create or delete persistent volumes."
    echo "22) Manage service accounts - Create or delete service accounts."
    echo "23) Help - Displays this help message."
    echo "24) Exit - Exits the script."
}

# Main script loop
detect_distro
check_dependencies
check_network
detect_virtualization

while true; do
    display_menu
    read -p "Choose an option: " choice
    case $choice in
        1) install_package curl ;;
        2) install_kubectl ;;
        3) install_minikube ;;
        4) start_minikube ;;
        5) deploy_sample_app ;;
        6) uninstall_kubectl ;;
        7) uninstall_minikube ;;
        8) monitor_resources ;;
        9) create_pod ;;
        10) create_replicaset ;;
        11) scale_deployment ;;
        12) view_pod_logs ;;
        13) delete_resource ;;
        14) get_cluster_info ;;
        15) list_pods ;;
        16) list_services ;;
        17) manage_namespaces ;;
        18) update_tools ;;
        19) manage_rbac ;;
        20) manage_secrets ;;
        21) manage_persistent_volumes ;;
        22) manage_service_accounts ;;
        23) display_help ;;
        24) echo "Exiting..."; break ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done

echo "Script execution complete."