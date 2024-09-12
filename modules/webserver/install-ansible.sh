# install Ansible
# Update the package list
echo "Updating package list..."
sudo apt update -y

# Install prerequisite software properties
echo "Installing software-properties-common..."
sudo apt install -y software-properties-common

# Add Ansible PPA (Personal Package Archive)
echo "Adding Ansible PPA..."
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Update the package list again
echo "Updating package list after adding Ansible PPA..."
sudo apt update -y

# Install Ansible
echo "Installing Ansible..."
sudo apt install -y ansible

echo "Ansible installation complete!"