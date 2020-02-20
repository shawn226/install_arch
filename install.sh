#!/bin/bash

echo "Bienvenue dans le quide d'installation d'Arch Linux."
echo "Veuillez suivre les instructions à l'écran."

###VARIABLES GLOBALES
message_wrong_timezone="\nVeuillez indiquer un nom présent dans la liste."

###FONCTIONS

#Fonction qui permet de récupérer le mode de boot
what_kind_of_boot()
{ 
    if [[ -d "/sys/firmware/efi/efivars" ]]
    then
        return 1
	else
		return 0
    fi
}

#Fonction qui permet de configurer le reseau
set_network(){
	echo ""
	ip address show
	
	read -p "Voulez vous configurez votre réseau ? Y/N " networking
	if [[$networking = "Y"] && [$networking = "y"]]
	then
	#on récupère l'interface car celle-ci varie d'un drvier / d'un OS à un autre			
	interface=$(ip address show | grep "^[^,\d]:" | grep -v "lo" | cut -d " " -f 2 | cut -d : -f 1)
	echo ""
	read -p "Choisissez votre configuration [static or dhcp]." net_management
		if [[$net_management = "dhcp"]]
		then
			ip link set $interface up
			dhcpd
		fi	
			
		if [[$net_management = "static"]]
		then
			echo "" 
			#J'active l'interface
			ip link set $interface up
			#je lis et j'ajoute l'IP sur l'interface
			read -p "Écrivez l'addresse IP dans le format suivant : xxx.xxx.xxx.xxx/xx." IPaddress	
			ip address add $IPaddress broadcast + dev $interface
		fi
}


#Fonction qui permet de définir l'heure et la date
set_time_by_timezone(){
	local answer="no"
	
	while [[ -z $answer ]] || [[ $answer != "oui" ]]
	do
		#set the date set-ntp
		timedatectl set-ntp true
		
		echo ""
		ls /usr/share/zoneinfo
		# On handle les erreurs haha lol =)
		while [[ -z $error ]] || [[ $error = 1 ]] 
		do
			local error=1
			read -p "Indiquez votre continent : " continent
			
			ls /usr/share/zoneinfo/$continent 2> /dev/null && error=0
		done
		
		error=1
		
		while [[ -z $error ]] || [[ $error = 1 ]]
		do
			local error=1
			read -p "Indiquez votre ville : " city
			ls /usr/share/zoneinfo/$continent/$city 2> /dev/null && error=0
		done

		timedatectl set-timezone $continent/$city
		
		timedatectl status
		
		echo ""
		read -p "Est-ce correct ? (oui / non): " answer
	done
}

#Fonction qui permet de partitionnner les disques
make_partition(){
	echo ""
	echo "Début du partitionnement:"
	if [[ $efi = 1 ]]
	then
		(echo g; echo n; echo 1; echo ""; echo +1G; echo n; echo 3; echo ""; echo +2G; echo n; echo 2; echo ""; echo ""; echo t; echo 1;echo 1;echo t; echo 2; echo 24; echo t; echo 3; echo 19; echo w) | fdisk /dev/sda
		echo ""
	fi
	mkfs.fat -F32 /dev/sda1 # parition de boot en fat32
	
	# création du swap
	mkswap /dev/sda3
	swapon /dev/sda3
	
	echo "Paritionnnement terminé."
}

#Fonction qui permet de chiffrer la partition /
encrypt_partition(){
	echo ""
	read -p "Voulez-vous chiffrer la partition ? (oui / non) : " answer
	
	if [[ $answer = "oui" ]]
	then
		echo ""
		read -p "Votre mot de passe : " password
		echo "$password" | cryptsetup -q luksFormat /dev/sda2
		echo "$password" | cryptsetup open /dev/sda2 cryptroot
		mkfs -t ext4 /dev/mapper/cryptroot
		echo ""
		echo "Fin du chiffrement da la partition"
		return 1
	else
		mkfs -t ext4 /dev/sda2
		return 0
	fi
}

#Fonction qui permet de monter les partitions
make_mount(){
	if [[ $efi = 1 ]]
	then
		if [[ $encrypted = 1 ]]
		then
			mount /dev/mapper/cryptroot /mnt
		else
			mount /dev/sda2 /mnt
		fi
		mkdir /mnt/boot
		mount /dev/sda1 /mnt/boot
	fi
	echo ""
	echo "Montage effectué:"
	lsblk
	sleep 2
}

#Fonction qui permet de créer une liste des "mirrors" en fonction du pays, ici c'est FR
set_mirrors(){
	curl -s "https://www.archlinux.org/mirrorlist/?country=FR&protocol=https&use_mirror_status=on" > /etc/pacman.d/mirrorlist
	sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist #On decommente les lignes dans le fichier 
}


#Fonction qui permet de générer les langues
generate_localegen(){
	echo ""
	local error=1
	while [[ $error = 1 ]]
	do
		read -p "Choisissez un langage (fr / en): " answer
		if [[ $answer != "fr" ]] && [[ $answer != "en" ]]
		then
			echo "Veuillez choisir entre 'fr' et 'en'."
			error=1
		else
			error=0
		fi
	done
	
	if [[ $answer = "fr" ]]
	then
		
		answer="fr_FR.UTF-8"
		sed -i 's/^#fr_FR.UTF-8/fr_FR.UTF-8 UTF-8/' /mnt/etc/locale.gen
	else
		answer="en_US.UTF-8"
		sed -i's/^#en_US.UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
	fi
	read -p "Mettre le clavier en AZERTY ? (oui /non) : " keymap
	if [[ $keymap = "oui" ]]
	then
		echo "KEYMAP=fr" > /mnt/etc/vconsole.conf #on met le clavier en azerty
	fi
	echo "" >> /mnt/install.sh
	echo "locale-gen" >> /mnt/install.sh
	echo "LANG=$answer" > /mnt/etc/locale.conf
}

#Fonction qui définit le nom de la machine
def_hosts(){
	echo ""
	read -p "Choissiez un nom pour la nouvelle machine : " name
	
	echo $name > /mnt/etc/hostname
	
	echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	$name.localdomain	$name" > /mnt/etc/hosts
}

#Fonction qui permet de configurer le démarage si partition chiffrée
make_initramfs(){
	if [ $encrypted = 1 ]
	then
		sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/' /mnt/etc/mkinitcpio.conf
		echo "" >> /mnt/install.sh
		echo "mkinitcpio -P" >> /mnt/install.sh
	fi
}

#Fonction qui permet à l'utilisateur de choisir un mot de passe pour "root"
config_root(){
	echo ""
	local error_pwd=1
	while [ $error_pwd = 1 ]
	do
		read -p "Choisir le mot de passe pour root : " root_pwd
		read -p "Confirmez le mot de passe : " confirm
		if [[ $root_pwd != $confirm ]]
		then
			error_pwd=1
		else
			error_pwd=0
		fi
	done
	
	echo "" >> /mnt/install.sh
	echo "(echo $root_pwd; echo $root_pwd) | passwd" >> /mnt/install.sh
}


#Fonction qui permet de créer un utilisateur et lui affecter un mot de passe
config_user(){
	echo ""
	read -p "Choissez un nom pour le nouvel utilisateur : " username
	local error_pwd=1
	while [ $error_pwd = 1 ]
	do
		read -p "Choisir le mot de passe pour $username : " user_pwd
		read -p "Confirmez le mot de passe : " confirm
		if [[ $user_pwd != $confirm ]]
		then
			error_pwd=1
		else
			error_pwd=0
		fi
	done
	echo "" >> /mnt/install.sh
	echo "useradd -m $username" >> /mnt/install.sh
	echo "" >> /mnt/install.sh
	echo "(echo $root_pwd; echo $root_pwd) | passwd $username" >> /mnt/install.sh
	echo "" >> /mnt/install.sh
	echo "usermod -aG wheel,audio,video,optical,storage $username" >> /mnt/install.sh
	
}

#Fonction qui permet la configuration du boot loader
config_bootloader(){
	local encrypt_uuid=$(blkid -o value -s UUID /dev/sda2)
	echo "" >> /mnt/install.sh
	echo "bootctl --path=/boot install
echo 'default arch
timeout 5
console-mode keep
editor no
' > /boot/loader/loader.conf ">> /mnt/install.sh

	echo "" >> /mnt/install.sh
	if [[ $encrypted = 1 ]]
	then
		echo "echo 'title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
options cryptdevice=UUID=$encrypt_uuid:cryptroot root=/dev/mapper/cryptroot rw quiet
' > /boot/loader/entries/arch.conf" >> /mnt/install.sh

	else
		echo "echo 'title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
options root=UUID=$encrypt_uuid rw quiet
' > /boot/loader/entries/arch.conf" >> /mnt/install.sh
	fi
	
	echo "" >> /mnt/install.sh
	echo "bootctl --path=/boot update" >> /mnt/install.sh
	
}


# define what is the boot => can change settings 
what_kind_of_boot
efi=$? # efi is set to 1 if it's true

#define timezone
set_time_by_timezone

#Configure Pacman
# pacman -Sy

#Partition making
make_partition

#Encrypt the partition
encrypt_partition
encrypted=$?

#make mount
make_mount

#Set mirrorlist
set_mirrors

#On passe au Chroot
pacstrap /mnt base linux linux-firmware vim sudo dhcpcd
genfstab -U /mnt >> /mnt/etc/fstab

#On set à nouveau la timezone dans le chroot

echo "ln -sf /usr/share/zoneinfo/$continent/$city /etc/localtime
	
hwclock --systohc" > /mnt/install.sh

#On génère les différentes langues du systeme
generate_localegen

#On def les hosts
def_hosts

#On configure les initramfs
make_initramfs


#Configuration des utilisateurs
config_root
config_user


#Configuration du bootloader
config_bootloader


#On rend le deuxième script executable
chmod u+x /mnt/install.sh

#On lance le deuxième script en chroot
arch-chroot /mnt ./install.sh

#on démonte pour éteindre la machine
umount -R /mnt
shutdown now






