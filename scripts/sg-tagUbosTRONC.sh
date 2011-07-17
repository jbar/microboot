#!/bin/sh

if [ -z "$1" -o "$1" == "-h" -o "$1" == "--help" -o "$1" == "/?" ] ; then
    echo -e "Usage: $0 Tag \n"\
	    "  Will tag all files in the CVS repositiry needed to compile SAGEM microboot and flash driver.\n"
    exit -1
fi

echo "  Creating tag \"$1\" on the current branch \"TRONC\" ..."
cvs rtag -rTRONC $1 mobiletool/inc || exit $?
cvs rtag -rTRONC $1 mobiletool/microboot || exit $?
cvs rtag -rTRONC $1 mobiletool/retrofit || exit $?
cvs rtag -rTRONC $1 mobiletool/nanoboot || exit $?
cvs rtag -rTRONC $1 mobiletool/displayprg || exit $?
cvs rtag -rTRONC $1 mobiletool/zlib || exit $?
cvs rtag -rTRONC $1 mobiletool/signature || exit $?
cvs rtag -rTRONC $1 mobiletool/libext || exit $?

## NB: il est plus nécessaire de tag les paliers de l'OS car on travail sur des paliers fermés

exit $?

