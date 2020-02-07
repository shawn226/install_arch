#!/bin/bash

echo "Bienvenue dans le quide d'installation d'Arch Linux.\n"
echo "Veuillez suivre les instructions à l'écran."

what_kind_of_boot()
{ (
    if [[ test -e /sys/firmware/efi/efivars -a  test -d /sys/firmware/efi/efivars ]]
    then
        echo "efi"
    fi
) }