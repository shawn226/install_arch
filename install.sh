#!/bin/bash

echo "Bienvenue dans le quide d'installation d'Arch Linux.\n"
echo "Veuillez suivre les instructions à l'écran."

what_kind_of_boot()
{ 
    if [[ -d "/sys/firmware/efi/efivars" ]]
    then
        return 1
	else
		return 0
    fi
}

boot=what_kind_of_boot

if [ $boot -eq 1 ]
then
	echo "C'est parti pour l'efi !"
else
	echo "ah non c'est du boot"
fi
