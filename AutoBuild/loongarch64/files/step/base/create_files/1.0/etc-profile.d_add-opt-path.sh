if [[ $(find /opt -maxdepth 1 -type d) ]]; then
    for i in $(find /opt -maxdepth 1 -type d | sort); do
        if [ -d $i/bin ]; then
            pathmunge $i/bin after
        fi
    done
fi
