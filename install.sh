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

set_time_by_timezone(){
	answer="no"
	
	while [[ -z $answer ]] || [[ $answer != "oui" ]]
	do
		#set the date set-ntp
		timedatectl set-ntp true
		
		echo ""
		ls /usr/share/zoneinfo
		# On handle les erreurs haha lol =)
		while [[ -z $error ]] || [[ $error = 1 ]] 
		do
			error=1
			read -p "Indiquez votre continent : " continent
			
			ls /usr/share/zoneinfo/$continent 2> /dev/null && error=0
		done
		
		error=1
		
		while [[ -z $error ]] || [[ $error = 1 ]]
		do
			error=1
			read -p "Indiquez votre ville : " city
			ls /usr/share/zoneinfo/$continent/$city 2> /dev/null && error=0
		done

		timedatectl set-timezone $continent/$city
		
		timedatectl status
		
		echo ""
		read -p "Est-ce correct ? (oui / non): " answer
	done
}

make_partition(){
	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << end | fdisk
	o # clear the in memory partition table
	n # new partition
	p # primary partition
	1 # partition number 1
	# default - start at beginning of disk 
	+100M # 100 MB boot parttion
	n # new partition
	p # primary partition
	2 # partion number 2
	# default, start immediately after preceding partition
	# default, extend partition to end of disk
	a # make a partition bootable
	1 # bootable partition is partition 1 -- /dev/sda1
	p # print the in-memory partition table
	w # write the partition table
	q # and we're done
	EOF
}

# define what is the boot => can change settings 
what_kind_of_boot
efi=$? # efi is set to 1 if it's true

sleep 1 # Sleep for making the script smoother 

#define timezone
set_time_by_timezone





