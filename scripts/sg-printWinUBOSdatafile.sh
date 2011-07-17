#!/bin/bash

## Set the working directory with argument 1, UBOSDIR environnement variable or at last current dir.
if [ -d "$1/os/hardti" ] ; then
    DIR="$1/"
elif [ -d "$UBOSDIR/os/hardti" ] ; then
    DIR="$UBOSDIR/"
elif [ -d "$PWD/os/hardti" ] ; then
    DIR="$PWD/"
else
    echo "${0##*/}: Error: Neither Argument 1 $1, UBOSDIR variable $UBOSDIR, or the current dir $PWD seems to contains a valid architecture" >&2
    exit -1
fi

## test and generate input line for MICROBOOT part
ilistm=(
    "X62+_MICROBOOT.winubos     UBOS_62+_???_60030104_    uncompress_62+_"
    "X62+_MICROBOOT.winubos     UBOS_62+_???_60030105_    uncompress_62+_"
    "X62+_MICROBOOT.winubos     UBOS128_62+_???_60030104_"
    "X62+_MICROBOOT.winubos     UBOS128_62+_???_60030105_"
    "loco_MICROBOOT.winubos     UBOS_63_???_63070105_     uncompress_63_"
    "loco_MICROBOOT.winubos     UBOS128_63_???_63070105_"
    "loconoram_MICROBOOT.winubos UBOS_64_???_64060105_"
    "nept_MICROBOOT.winubos     UBOS128_90_???_90040105_"
    "neptodm_MICROBOOT.winubos  UBOS128_91_???_91040105_"
    )

for i in "${ilistm[@]}" ; do
    j=($i);
    if    [ $(ls -a "${DIR}os/hardti/microboot/scripts/ressources/${j[0]}" | wc -l) == "1" ] \
       && [ $(ls -a "${DIR}os/hardti/microboot/fab/"${j[1]}*.i32 | wc -l) == "1" ] \
       && ( ((${#j[@]}<3)) || [ $(ls "${DIR}os/hardti/microboot/fab/"${j[2]}*.i32 | wc -l) == "1" ] )
    then
        echo -n "${DIR}os/hardti/microboot/scripts/ressources/${j[0]};"
        echo -n "${DIR}os/hardti/microboot/fab/"${j[1]}*.i32
        if ((${#j[@]}>2)) ; then 
            echo -n ";"
            echo -n "${DIR}os/hardti/microboot/fab/"${j[2]}*.i32
        fi
        echo
    else
        echo "${0##*/}: Warning: Can't determine some file(s) in $i " >&2
    fi
done

## test and generate input line for FLASHDRIVERpart
ilistr=(
    "X62+_FLASHDRIVER.winubos    FBS_62+_???_60020103_"
    "X62+_FLASHDRIVER.winubos    FBS_62+_???_60020104_"
    "X62+_FLASHDRIVER.winubos    FBS_62+_???_60020105_"
    "X62+_FLASHDRIVER.winubos    FBS_62+_???_60030103_"
    "X62+_FLASHDRIVER.winubos    FBS_62+_???_60030104_"
    "X62+_FLASHDRIVER.winubos    FBS_62+_???_60030105_"
    "loco_FLASHDRIVER.winubos    FBS_63_???_63050105_"
    "loco_FLASHDRIVER.winubos    FBS_63_???_63070105_"
    "loconoram_FLASHDRIVER.winubos FBS_64_???_64060105_"
    "nept_FLASHDRIVER.winubos    FBS_90_???_90040105_"
    "neptodm_FLASHDRIVER.winubos FBS_91_???_91040105_"
    )

for i in "${ilistr[@]}" ; do
    j=($i);
    if    [ $(ls -a "${DIR}os/hardti/microboot/scripts/ressources/${j[0]}" | wc -l) == "1" ] \
       && [ $(ls -a "${DIR}os/hardti/retrofit/fab/"${j[1]}*.rawprg | wc -l) == "1" ]
    then
        echo -n "${DIR}os/hardti/microboot/scripts/ressources/${j[0]};"
        echo "${DIR}os/hardti/retrofit/fab/"${j[1]}*.rawprg
    else
        echo "${0##*/}: Warning: Can't determine some file(s) in $i " >&2
    fi
done

