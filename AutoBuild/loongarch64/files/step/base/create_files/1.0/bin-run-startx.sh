#!/bin/bash
if [ -d /var/unit/dm ]; then
    if [[ ! $(find /var/unit/dm/ -maxdepth 1 -type f) ]]; then
        if [ -d /var/unit/alone-app ]; then
            if [[ $(find /var/unit/alone-app/ -maxdepth 1 -type f) ]]; then
                HOME=/root startx
                poweroff
            fi
        fi
    fi
fi
