# SSH requirements for Azure Stack Uptime Monitor 

The Azure Stack Uptime Monitor runs on an Ubuntu OS. 
To connect to the VM over SSH a user can authenticate to Linux with a password or a certificate. 
The Azure Stack Uptime Monitor only allows for certificate based authentication to increase security.
This document describes how to create an SSH keypair that can be used to deploy and securely connect to the Azure Stack Uptime Monitor

* Create SSH Keypair
* Public Key for deployment of the Azure Stack Uptime Monitor
* Connect to the Azure Stack Uptime Monitor VM

## Create SSH key pair
The procedure to create an SSH keypair is performed in bash. Most Linux distributions come with bash preinstalled, but if the client machine (used for connecting to the Azure Stack Uptime Monitor VM) is running a Windows operating system you can install Git Bash.

### Install Git Bash on Windows
Windows does not contain a bash environment to run shell scripts. You can install [Git for Windows](https://git-scm.com/), which comes with a Git Bash envrionment to execute shell scripts. Once you have installed Git, locate the **Git Bash** program in your start menu and open the command.

### SSH Keygen
The procedure for creating the keypair is identical for Linux and Windows (with Git Bash installed). 

* Azure and Azure Stack currently supports SSH protocol 2 (SSH-2) RSA public-private key pairs with a minimum length of 2048 bits. Other key formats such as ED25519 and ECDSA are not supported. 

    ``` shell
    ssh-keygen -t rsa -b 2048 -C "your@email.com" 
    ```
* You will be prompted for a location to store the keys.

    ``` shell
    Enter file in which to save the key (/home/youruser/.ssh/id_rsa):
    ```
* You will be prompted to specify a passphrase

    ``` shell
    Enter passphrase (empty for no passphrase):
    ```
    This passphrase is used to load the private key when connecting with SSH.
    To setup the SSH connection a passphrase is not required. It is an additonal level of security that you can choose to leverage.
* Ssh-keygen will create two files in the location specified to store the key in. **id_rsa** which is contains the private key and **id_rsa.pub** which contains the public key.

## Public Key for deployment of the Azure Stack Uptime Monitor
The ARM template that deploys the Azure Stack Uptime Monitor has a required sshPublicKey parameter. During deployment you need to submit the content of the **id_rsa.pub** file that was created earlier. On Windows you can just open the id_rsa.pub with notepad and copy the public key or on linux you can use the **cat** command.

During deployment the public key will be added to the the authorized_keys file in the .ssh directory of the users home directory on the VM.

## Connect to the Azure Stack Uptime Monitor VM
To connect from a client machine to the Azure Stack Uptime Monitor VM with SSH, the client machine needs to run a bash environment and have access to the private key of thet key pair.

* Ensure the ssh-agent is running

    ``` shell
    eval $(ssh-agent)
    ```
* Import the private key in the current session (replace the path with the value you specified, if you choose to use another value as the defeault path, when creating the key pair.)

    ``` shell
    # Linux
    ssh-add /home/youruser/.ssh/id_rsa
    
    # Windows
    ssh-add "/c/Users/youruser/.ssh/id_rsa"
    ```

* Connect to the public IP address of the Azure Stack Uptime Monitor Load Balancer

    ``` shell
    ssh [adminUserName]@[loadbalancer-public-ip-address]
    ```