# CTF Environment - King of the Hill Edition

<img src="https://upload.wikimedia.org/wikipedia/en/5/51/King_of_the_Hill_%28logo%29.svg">

This environment contains multiple machines with various challenges themed around the King of the Hill TV series. Some information might be hidden in unexpected places, and you might encounter familiar characters from Arlen, Texas.

## Character-Based Challenges

Each container in this CTF environment includes King of the Hill themed user accounts with character-appropriate passwords. These users may contain hidden files, images, or other secrets. Look for:

- **Propane and propane accessories enthusiasts**
- **Conspiracy theorists and pest control experts** 
- **Army veterans and beauty school graduates**
- **Fast-talking mechanics and massage therapists**
- **Substitute teachers and violin prodigies**

[Walkthrough](https://medium.com/@bakerwomack/king-of-the-hill-ctf-3150314ae63f)

## Installation

1. Clone the git repo

```
git clone https://github.com/WomackBaker/KOTH_CTF.git
```

2. Ensure docker is up and running
```
docker -h
```

3. Bring up the docker environment
```
docker-compose up --build -d
```


## Connecting to the Network

To access the CTF environment, you'll need to connect to the VPN:

1. Install OpenVPN client:
   - Windows: Download from [OpenVPN website](https://openvpn.net/community-downloads/)
   - Linux: `sudo apt-get install openvpn`
   - macOS: `brew install openvpn`
   
2. Run the openssh install script
   - Windows: install_openvpn.bat
   - Linux: install_openvpn.sh

```
OpenVPN Installation Script
Usage: install_openvpn.bat -i [IP] -c [count] [-p [port]] [-o [output_dir]]

Required:
  -i [IP]       Public IP address (use 10.8.0.1 for VPN network)
  -c [count]    Number of client configs

Optional:
  -p [port]     Port (default: 1194)
  -o [dir]      Output directory (default: .\client_configs)
  -h            Show this help

Example: install_openvpn.bat -i 10.8.0.1 -c 5
```

3. Connect to the VPN:
   - Windows: Right-click the .ovpn file and select "Start OpenVPN on this config file"
   - Linux/macOS: `sudo openvpn client1.ovpn`

4. Verify connection:
   - You should be able to ping 172.20.0.1
   - All CTF machines will be accessible in the 172.20.0.0/16 network

## Challenge Overview

1. **Web Services**
   - Multiple web servers running different versions
   - Some might have interesting configurations
   - Look for unusual file locations
   - King of the Hill themed databases and user accounts

2. **Remote Access**
   - Multiple SSH instances with character-themed accounts
   - Different authentication methods
   - Some services might be running on non-standard ports
   - Try common passwords based on character traits

3. **Data Storage**
   - Database instances with Arlen, Texas residents
   - File storage systems in user home directories
   - Backup locations and hidden images
   - Character-specific file permissions

4. **User Enumeration**
   - Each container has themed user accounts
   - Users may have character-appropriate passwords
   - Home directories may contain hidden files or images
   - Look for references to propane, conspiracies, military service, etc.

## Scoreboard

A scoreboard system is available to track your progress:
- Access the scoreboard at http://localhost:5000
- Submit flags to earn points
- View real-time rankings of all teams
- Track your progress through the challenges

### Point Values
- Basic challenges: 100 points
- Advanced challenges: 200 points
