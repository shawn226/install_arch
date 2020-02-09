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
	echo"Montage effectué:"
	lsblk
	sleep 2
	genfstab -U /mnt >> /mnt/etc/fstab
}

#Fonction qui permet de créer une liste des "mirrors" en fonction du pays, ici c'est FR
set_mirrors(){
	curl -s "https://www.archlinux.org/mirrorlist/?country=FR&protocol=https&use_mirror_status=on" > /etc/pacman.d/mirrorlist
	sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist #On decommente les lignes dans le fichier 
}

generate_localegen(){
	echo ""
	while [[ -z $answer ]] || [[ $error = 1 ]]
	do
		read -p "Choisissez un langgage (fr / en): " answer
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
		echo "KEYMAP=$answer" > /etc/vconsole.conf #on met le clavier en azerty si fr
		answer="fr_FR.UTF-8"
		sed -re 's/^#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
	else
		answer="en_US.UTF-8"
		sed -re 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
	fi
	
	echo "LANG=$answer" > /etc/locale.conf
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
arch-chroot /mnt


#On set à nouveau la timezone dans le chroot
ln -sf /usr/share/zoneinfo/$continent/$city /etc/localtime
hwclock --systohc

#On génère les différentes langues du systeme
generate_localegen







