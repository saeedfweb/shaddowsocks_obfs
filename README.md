# How to Run
These steps should be executed on both internal and external hosts
Video link in [youtube](https://youtu.be/rtGPtn0Fkv8 "youtube") 
## Clone the code
```bash
cd /srv
git clone git@github.com:MortezaBashsiz/shaddowsocks_obfs.git
cd shaddowsocks_obfs
```
## Adjust your config
```bash
internalIP=192.168.122.1
internalPort=443
externalIP=192.168.122.130
externalPort=4550
```
## execute
```bash
sudo bash setup.sh
```
