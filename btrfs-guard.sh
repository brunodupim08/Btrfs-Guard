#!/bin/bash

version="1.0"
project="https://github.com/brunodupim08/Btrfs-Guard.git"

function usage() {
    echo "Usage: $0 <uuid> <subvolume>"
    echo "Options: $0 [-h] or [-v]"
    echo "  -h    Display this help message"
    echo "  -v    Display script version"
}

function mount_drive() {
    local uuid="$1"
    local drive_point="$2"

    mount UUID="$uuid" "$drive_point" || exit 3
}

function umount_drive() {
    local drive_point="$1"

    if grep -qs "$drive_point" /proc/mounts; then
        umount "$drive_point" || exit 5
        if grep -qs "$drive_point" /proc/mounts; then
            echo -e "Error: The mount point is still mounted."
            exit 6
        else
            rmdir "$drive_point" || exit 7
        fi
    else
        echo -e "Error: The mount point is not mounted."
        exit 8
    fi
}

function main() {
    while getopts ":hv" opt; do
        case ${opt} in
            h ) usage;exit 0;;
            v ) version;exit 0 ;;
            \? ) echo "Invalid option: $OPTARG" 1>&2; usage ;;
        esac
    done
    shift $((OPTIND -1))

    if [ "$#" -ne 2 ]; then
        echo "Error: Missing arguments."
        usage
        exit 1
    fi

    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Error: This script must be run as root."
        exit 1
    fi

    local uuid="$1"
    local subvolume="$2"
    local drive_point="/run/snapshot-$uuid"
    local subvolume_point="$drive_point/$subvolume"
    local snap_vol_paste="$drive_point/snapshot/$subvolume"
    local date=$(date +%Y-%m-%d_%H-%M-%S)

    # Check if mount directory exists, if not, create it
    if [ ! -d "$drive_point" ]; then
        mkdir -p "$drive_point" || exit 2
    fi
    # Check if the mount point is already mounted before attempting to mount it again
    if ! grep -qs "$drive_point" /proc/mounts; then
        mount_drive "$uuid" "$drive_point"
    fi
    # Check if the snapshot directory of subvolume_point exists, if not, create it
    if [ ! -d "$snap_vol_paste" ]; then
        mkdir -p "$snap_vol_paste" || exit 4
    fi
    # Create a snapshot and await its completion
    btrfs subvolume snapshot "$subvolume_point" "$snap_vol_paste/$date"
    snapshot_exit_code=$?
    if [ $snapshot_exit_code -eq 0 ]; then
        umount_drive "$drive_point"
        exit 0
    else
        echo -e "Error creating snapshot. Exit code: $snapshot_exit_code"
        umount_drive "$drive_point"
        exit 9
    fi
}

function version(){
    local version="\033[1;94mv$version\033[0m"
    local author="\033[1;94mBruno Dupim\033[0m"
    local project="\033[1;94m$project\033[0m"
    echo -e "\033[1;94m
                       .                                  .                               
                       c                                 .,             .,                
                        ;.              ......         .,,.   ..,;::cccl;                 
                         .::;'..    .;cllllllll:,.  .,:,....;clll:;'                      
               ...'...     .':ccc.'cllllllllllllll;.cc.  .clll;'.                         
                    ',::,.    'l;;lclllllllllll:.ll'lc  'llll.              .......       
                       .cl;    l:;l.:llllllllll: ll;:l. llll'           .':loc            
   .                    .loc..c;:oc.coooooooooool;lo:;c.oooo,         'coo:.              
    ;                    :oo:;::oocoooooooooooooooooo'l;coool.      ,loo:.                
    ,o:,,,:cclcc;'.      looo'c;oooooooooooooooooool,cll,loooo;.  .looo,.                 
     .ooooooooooooo:.   ,oooc,l;.ooo,cooooooooc,ol,   'll;:ooooo;.looo;                   
              ':odddo'.:oooo,l;  .;oo,:oooooo;,l,';;,.  llc;loooooc:lo                    
                .cdcc:ooool;cc  ;,..:o':oooo:,c.;;,coo   ooo::loooooc,                    
                ..:looooo::oo. ::.c,.lo.cool.oc;':c.lo   ooooo':oddddo,                   
                .cdddddl,looo'  :'OKxd'c;od;o,c0lNl.    'oooo::d;dddddd'                  
                cdddddo;;ooool.   :oox. :odo'.lkl.    .:ooooc;dd,ddddddo                  
               .dddddd;do;loooo,.   ;ddl:ddd:ddd;  .,cooooo::dd:lddddddd                  
               ,dddddd;dddc:cooool:,.odddddddddd'dccccllcccldd:lddddddd,                  
               .dddddd;xxxxxocccccc;:dddlddoodddo:ldxdoodxxoccdddddddd;                   
                odddddlcxxxxxxxxxdccdddd:dd:ddddddoccllllcclddddddddd    ..           ,   
         ...    .ddddddlcloddollclddddddoxdoxxxxxdxxxxxxxxxxxxxxxxd..'cdxxxxdc;'...,cd    
     .;coxxxdl.  .dxxxxxxdlllldxxdoxxxxxxxxxxxxxoclxxxxxxxxxxxxxo;.'oxxxxxxddxxxxxxxo     
           .xxx,   :xxxxxxxxxxxxd:lxxxxxxxxxxxxx.oxxxxxxxxxxxo:' .lxxxx;                  
             cxxc   .:oxxxxxxxc,.cxxxxxxxxxxxxxxc..,;::::;,..  .cxxxxo                    
              :xxd;     ',,'.. 'oxxxxxxxxxxxxxxxxxl;'.......,:oxxxxx,                     
               xxxxdc'.    .':dxxxxxxxd:,.:dxxxxxxxxxxxxxxxxxxxxxxx.                      
                dxxxxxxxoodxxxxxxxxxd,     .:xxxxxxxxxxxxxxxxxxxxx.                       
                  oxxxxxxxxkxkxxxxd:..       .;coxkkkkkkkkkkkkkd                          
                    :lxkkkkkkkkdl;..           ...';:cloooo;                              
                          .,'.                                                   
    \033[0m"
    echo -e "\033[1;94m
    #=============#
    # Btrfs Guard #
    #=============#
    \033[0m
    Version: $version
    Author:  $author
    Project: $project
    "
}

main "$@"
