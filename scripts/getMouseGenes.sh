#!/bin/bash

if [ ! -f ../test/mouse_genes.sqlite ]; then
    printf "mouse_genes.sqlite not found!\n"
    printf "Downloading to /test/\n"
    wget -O ../test/mouse_genes.sqlite  https://ndownloader.figshare.com/files/17609261
else
    printf "mouse_genes.sqlite found.\n"
fi
