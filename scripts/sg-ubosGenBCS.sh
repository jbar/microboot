#!/bin/sh

if [ -z "$1" -o "$1" == "-h" -o "$1" == "--help" -o "$1" == "/?" ] ; then
    echo -e "Usage: $0 file(.dat) [directory] \n"
	    "  Will create all the bcs specified using the .dat input file.\n"
	    "  The input file has to be WinUBOS compliant.\n"
	    "  If directory is not specified, a directory called \"out-bcs\" will be created in the current path."
    exit -1
fi

if ! [ -f "$1" ] ; then
    echo "$0: Error: file $1 doesn't exist !" >&2
    exit -1
fi

if [ "$2" ] ; then
    WinUBOS.exe "$1" "$2"
else
    mkdir -p "out-bcs" || exit -1
    WinUBOS.exe "$1" out-bcs
fi

exit $?
