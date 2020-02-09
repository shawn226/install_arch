#!/bin/bash

echo "Bienvenue dans le quide d'installation d'Arch Linux.\n"
echo "Veuillez suivre les instructions à l'écran."

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
	
	while [[ -z $answer ]] || [[ $answer -!= "oui" ]]
	do
		#set the date set-ntp
		timedatectl set-ntp true
		
		echo "\n"
		read -p "Indiquez votre continent : " continent
		read -p "Indiquez votre ville : " city

		timedatectl set-timezone $continent/$city
		
		timedatectl status
		
		echo "\n"
		read -p "Est-ce correct ? (oui / non): " answer
		
		echo $answer
	done
}

# define what is the boot => can change settings 
what_kind_of_boot
efi=$? # efi is set to 1 if it's true

sleep 2
set_time_by_timezone





