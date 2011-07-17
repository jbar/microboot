#!/bin/bash

DOPTS='
DOTAG=0 # Create tag on the CVS repository #bool# tag t
MKUBOS=1 # launch the sg-mkubos script (to compile) #bool# mkubos k
DOEND=1 # backup the tar.gz and make RTKI component #bool# finalize f

RELMICROBOOT=1 # Release a microboot #bool# microboot m
RELRETROFIT=1 # Release a retrofit driver #bool# retrofit r

UBOSTAG="microboot_${VERSION}_X62" # Set the Tag to use or create #par# -ustag ustag
BUILDDATE='$(date +%d%m%y_%H%M)' # Set the date of the release #par# -date date
MKUBOSconfFile="" # Specifie a configuration file for sg-mkubos #par# -mkconf mkconf

## UBOSDIR peut être en chemin absolu ou en chemin relatif : à $HOME par défaut ou au répertoire courant si la variable suit le motif ./* ou ../* .
UBOSDIR="$HOME/release_ubos_$UBOSTAG" # Directory of the release #par# -dir dir
'

echo $VERSION | grep "^[3-9][0-9]\{2\}$" > /dev/null || VERSION="999"

function rlubos_usage()
{
    echo -e " Usage : ${0##*/} VERSION [+-[option] [val]] [+-[option] [val]]..."\
            "\nRelease Sagem Communication's embedded retrofit softwares (microboots, ROM flash drivers...)"\
	    "\n       VERSION has to be defined beetween 391 and 998."\
            "\n       Options 'h' '-help' or '?' always show this help" >&2
    echo -e "\nThere are 2 types of options : boolean are set by sign + ou - before its name, when parameter options need an argument :"\
            "\n#type# option names : description { default value } "\
            "\n----------------------------------------------------"
    echo "$DOPTS" | sed -n ' s/\(.*\)#\([^#]*\)#\(bool\|par\)#\([^#]*\)/#\3#\4 :\2 { \1}/p'
    echo -e "\n Example :"\
            "\n      ${0##*/} 999 +t --date 120580_1824"\
            "\n will create a new release 999 with a new tag microboot_999_X62 dated on Mon, 12 May 1980 18h24 :"
    exit $1
}

## Check the version of the script
if ! cvs get -rTRONC -p mobiletool/microboot/scripts/sg-rlubos.sh | diff -q "$0" - ; then 
    echo -n "You don't have the last version of this script. Do u want to continue (y/n) ? "
    read answer
    case "$answer" in 
	Y* | y* | O* | o* )
        echo
	;;
	* )
	exit
    esac
fi

## Process arguments.
while [ $# -ge 1 ]; do
  case "$1" in
   [+-]h | [+-]-help | [+-]\? ) 
      rlubos_usage 1
    ;;
   [+-]?* )
    if str="$( echo -e "$DOPTS" | grep -m 1 "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#bool#[^#]*\<${1:1}\>[^#]*$")" ; then 
## L'argument indique un (des) booléens -> on les met à 1 ou à 0.
	if [ "${1:0:1}" == "+" ] ; then 
            eval "$( echo $str | sed ' { s/=0\>/=1/g } ' )"
	else
            eval "$( echo $str | sed ' { s/=1\>/=0/g } ' )"
        fi
    elif str="$(echo -e "$DOPTS" | grep -m 1 "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#par#[^#]*[#[:blank:]]${1:1}\>[^#]*$")" ; then
## L'argument indique une variable -> on la met à la valeur indiqué.
        eval "${str%%=*}=$2"
        shift
    else
## L'argument n'a pas été trouvé -> on insulte le pauvre utilisateur ;-)
        echo "$0: Error: Argument $1 not found !" >&2
        rlubos_usage -1
    fi 
    ;;
    [3-9][0-9][0-9])
      VERSION=$1
    ;;
    * ) 
      echo "$0: Error: Argument $1 not valid !" >&2
      rlubos_usage -2 > /dev/null
    ;;
  esac
shift
done

## Verifie la validité des paramètres BUILDDATE et VERSION.
if [ "$VERSION" == "999" ] ; then
    rlubos_usage -2 > /dev/null
fi
if [ "$BUILDDATE" ] && ! echo $BUILDDATE | grep "^[0-9]\{6\}_[0-9]\{4\}$" > /dev/null ; then
    echo "Error: the date has a invalid format, must be 'ddmmyy_hhmm' ." >&2
    rlubos_usage -2 > /dev/null
fi

## Assigne les autres valeurs des options sans écraser une variable déjà définie
for b in $(echo -e "$DOPTS" |  sed -n ' /^[[:space:]]*\<[[:alnum:]_]\+\>=.*#par#[^#]*$/  {  s/#[^#]*#par#.*// ; p } ' ) \
	 $(echo -e "$DOPTS" | grep "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#bool#[^#]*$" | grep -o "\<[[:alnum:]_]\+\>=[01]\>" )  ; do 
    if [ -z "$(eval "echo \$${b%%=*}")" ] ; then
       eval "$b"	
    fi
done

## Se place dans $UBOSDIR et le convertit éventuellement $UBOSDIR en chemin absolu
pushd ~ > /dev/null
if echo "$UBOSDIR" | grep "^[ ]*\.\.\?/\?" > /dev/null ; then cd - ; fi
mkdir -p "$UBOSDIR" || exit -3
if [ "$MKUBOSconfFile" ] ; then
    popd > /dev/null
    cp -v "$MKUBOSconfFile"  "$UBOSDIR/sg-mkubos.sh.conf"
    pushd - > /dev/null
fi
cd "$UBOSDIR"
UBOSDIR="$PWD"

## Create file descriptor 7 and 8 to save STDOUT et STDERR
exec 7>&1
exec 8>&2

## Start the log file
LOGFILE="$UBOSDIR/${0##*/}_$BUILDDATE.log"	#var# -logfile logfile o
echo -e "\n--- $(date +%d%m%y_%H%M) -- Starting $0  \$Revision: 1.1.2.12 $ ---\n" >> "$LOGFILE" || exit -3
sleep 1
tail --pid $$ -f "$LOGFILE" &
exec >> "$LOGFILE" 2>&1
cd "$UBOSDIR"

## Display a resume of configuration before to launch compilations
if (($DOTAG)) ; then	echo "     create Tag = $UBOSTAG" 
else			echo "        use Tag = $UBOSTAG"
fi
echo -e  "\n  directory = $UBOSDIR" \
         "\n  build date = $BUILDDATE" \
         "\n  compile (using sg-mkubos.sh) : $MKUBOS" \
         "\n  release microboot : $RELMICROBOOT" \
         "\n  release retrofit : $RELRETROFIT" \
         "\n  finalize (RTKI,copy) : $DOEND"
if [ "$( df $UBOSDIR | tr -s ' ' | cut -f 4 -d ' ' | tail -1)" -lt 850000 ] ; then 
       	echo -e '\n WARNING : you may have not enough space !!! :'
	df -h $UBOSDIR
fi
echo -e "\nType Enter or wait 10 sec to continue. Type Ctrl-C to abort."
read -t 10

## Tag the CVS repository
if (($DOTAG)) ; then
    cvs get -rTRONC -dscripts mobiletool/microboot/scripts/sg-tagUbosTRONC.sh
    if ! $UBOSDIR/scripts/sg-tagUbosTRONC.sh $UBOSTAG ; then
	echo "$0: Error: when creating cvs tag $UBOSTAG" >&2
	exit -2
    fi
fi

## Check out the sg-mkubos scripts and launch it
if (($MKUBOS)) ; then
    if ! cvs get -r$UBOSTAG -dscripts mobiletool/microboot/scripts/sg-mkubos.sh ; then 
	echo "$0: Fatal cvs Error." >&2
        exit -4
    fi
    echo -e "\n $(date "+%Hh%M %Ss") - Launch $UBOSDIR/scripts/sg-mkubos.sh ..." \
            "\n      ( the file sg-mkubos.sh_$BUILDDATE.log should contain his log )"
    ## On "lache" le fichier de log
    exec 2>&8 ; exec >&7 
    export VERSION UBOSDIR UBOSTAG BUILDDATE
    if ! "$UBOSDIR/scripts/sg-mkubos.sh" +tgz ; then
	echo "$0: Error: $(date "+%Hh%M %Ss") - sg-mkubos.sh FAIL ($?) !!!" >> "$LOGFILE"
	exit -4
    else
        echo -e "\n $(date "+%Hh%M %Ss") - sg-mkubos.sh OK !" >> "$LOGFILE"
    fi
    ## On "reprend" le fichier de log
    exec >> "$LOGFILE" 2>&1
fi

## generate the .dat file for WinUBOS.exe and generate bcs files with it
if (($RELMICROBOOT|$RELRETROFIT)); then 
    echo -e "\nGenerating the WinUBOS .dat file..."
    ./os/hardti/microboot/scripts/sg-printWinUBOSdatafile.sh | sed ' { s/\/cygdrive\/\([[:alnum:]]\)/\1:/g ;  s/\//\\/g } ' > Driver_Microboot_$VERSION.dat
    mkdir -pv out-bcs_${BUILDDATE}

    echo -e "\nCalling WinUBOS  Driver_Microboot_$VERSION.dat out-bcs_${BUILDDATE}"
    WinUBOS.exe Driver_Microboot_$VERSION.dat out-bcs_${BUILDDATE}/
    #echo "$0: Debug: WinUBOS return $?"
    #if [ "$?" != "1" ] ; then echo "erreur WinUBOS" ; exit -6 ; fi
fi

## make all the stuff to upload on "avis de modif" for MICROBOOT_SECURISE
if (($RELMICROBOOT)) ; then 
    mkdir -p "${UBOSDIR}/UBOS_${VERSION}_${BUILDDATE}"
    pushd  "${UBOSDIR}/UBOS_${VERSION}_${BUILDDATE}"

    num=$(cp -v "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/TELECHs/TELECH_62_148_"* "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/TELECHs/TELECH_52_136_"* . | wc -l )
    echo " $num old TELECHs copied from //sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/TELECHs/ ."
    cp -v "../os/hardti/microboot/fab/TELECH"* .
    echo -e "\nGenerating  UBOS_${VERSION}_${BUILDDATE}.zip ..."
    zip -j UBOS_${VERSION}_${BUILDDATE}.zip ../os/hardti/nanoboot/neptune/out_romcode/secureboot_*.a32
    zip -j UBOS_${VERSION}_${BUILDDATE}.zip ../os/hardti/nanoboot/neptune/out_romcode/secureboot*odm_*.a32
    zip -j UBOS_${VERSION}_${BUILDDATE}.zip ../os/hardti/microboot/fab/*.i32
    zip -j UBOS_${VERSION}_${BUILDDATE}.zip ../out-bcs_${BUILDDATE}/UBOS*.bcs

    echo -e "\nGenerating the .txt file for BCSPacker..."
    echo  -e "-p\n"\
	     "UBOS_${VERSION}_${BUILDDATE}.pbcs" >  UBOS_${VERSION}_paked_files.txt
    (ls ../os/hardti/nanoboot/neptune/out_romcode/secureboot_*.a32 ;
     ls ../os/hardti/microboot/fab/*.i32 ;
     ls ../out-bcs_${BUILDDATE}/UBOS*.bcs ;
    ) | while read line ; do 
	echo -e "-f\n"\
		"$line" >> UBOS_${VERSION}_paked_files.txt
    done
    echo "Generating Pack BCS  UBOS_${VERSION}_${BUILDDATE}.pbcs ..."
    BCSPacker.exe UBOS_${VERSION}_paked_files.txt
    popd
fi

## make all the stuff to upload on "avis de modif" for DRIVER_FLASH_SECURI
if (($RELRETROFIT)) ; then 
    mkdir -p $UBOSDIR/FBS_62_${VERSION}_${BUILDDATE}
    pushd $UBOSDIR/FBS_62_${VERSION}_${BUILDDATE}

    echo -e "\nGenerating  LOCALFLHDRV.zip ..."
    zip -j LOCALFLHDRV.zip  "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/DisplayPrg/DISPLAYPRG_62"*
    zip -j LOCALFLHDRV.zip ../out-bcs_${BUILDDATE}/LOCALFLHDRV*.bcs

    echo -e "\nGenerating the .txt file for BCSPacker..."
    echo  -e "-p\n"\
	     "pFBS.pbcs" >  FBS_${VERSION}_packed_files.txt
    ( ls "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/FlashDrivers/FBS_52_137"*.bcs ;
      ls "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/FlashDrivers/JTG_52_137"*.bcs ;
      ls "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/FlashDrivers/FBS_62_163"*.bcs ;
      ls "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichie~2/FlashDrivers/JTG_62_163"*.bcs ;
      ls "../out-bcs_${BUILDDATE}/JTG_"*.bcs ;
      ls "../out-bcs_${BUILDDATE}/FBS_"*.bcs ;
      ) | while read line ; do  
	echo -e "-f\n"\
	        "$line" >> FBS_${VERSION}_packed_files.txt
    done 
    echo "Generating Pack BCS pFBS.pbcs ..."
    BCSPacker.exe FBS_${VERSION}_packed_files.txt
    popd
fi

if (($DOEND)) ; then
    echo -e "\nIf you are sure are sure that FBS and/or UBOS generated are ok, press enter to backup the tar.gz archive, optimize Pack BCS files, make RTKI components and copy release directories on the AvisModif server. Else fix them first.\n"
    sleep 1
    read 
    pushd $UBOSDIR
## backup the tar.gz archive
    cp -vi "$VERSION.tar.gz" "//sct38nt1/terminal/Outils/RCS/Histor~1/Fichiers Sources"
## optimize pbcs files and make FBS and UBOS as RTKI components. 
    if [ -f "$UBOSDIR/UBOS_${VERSION}_${BUILDDATE}/UBOS_${VERSION}_${BUILDDATE}.pbcs" ] ; then
        echo "Optimize UBOS_${VERSION}_${BUILDDATE}/UBOS_${VERSION}_${BUILDDATE}.pbcs ..."
        BCSPacker.exe -o -p "UBOS_${VERSION}_${BUILDDATE}/UBOS_${VERSION}_${BUILDDATE}.pbcs"
        echo "Generating RTKI Component for UBOS_${VERSION}_${BUILDDATE} ..."
        mkdir "MICROBOOT_SECURISE_NSBRD"
        pushd "MICROBOOT_SECURISE_NSBRD"
        compgenerator.exe "../os/hardti/microboot/scripts/ressources/Microboot_compgen.xml" "UBOS_${VERSION}_${BUILDDATE}"
        popd
    else
        echo "File UBOS_${VERSION}_${BUILDDATE}/UBOS_${VERSION}_${BUILDDATE}.pbcs not found to optimize and make RTKI component."
    fi
    if [ -f "$UBOSDIR/FBS_62_${VERSION}_${BUILDDATE}/pFBS.pbcs" ] ; then
        echo "Optimize FBS_62_${VERSION}_${BUILDDATE}/pFBS.pbcs ..."
        BCSPacker.exe -o -p "FBS_62_${VERSION}_${BUILDDATE}/pFBS.pbcs"
        echo "Generating RTKI Component for FBS_62_${VERSION}_${BUILDDATE} ..."
        compgenerator.exe "os/hardti/microboot/scripts/ressources/FlashDriver_compgen.xml" "FBS_62_${VERSION}_${BUILDDATE}"
    else
        echo "File FBS_62_${VERSION}_${BUILDDATE}/pFBS.pbcs not found to optimize and make RTKI component."
    fi
## Copy released directories on AvisModif
    read -p "Do u want to copy release directories on AvisModif (y/n) ? " answer
    case "$answer" in 
	Y* | y* | O* | o* )
            cp -ivr "UBOS_${VERSION}_${BUILDDATE}" "//sct38nt4/AvisModif/MICROBOOT_SECURISE"
            cp -ivr "MICROBOOT_SECURISE_NSBRD/UBOS_${VERSION}_${BUILDDATE}" "//sct38nt4/AvisModif/MICROBOOT_SECURISE_NSBRD"
            cp -ivr "FBS_62_${VERSION}_${BUILDDATE}" "//sct38nt4/AvisModif/DRIVERS.FLASH_SECURI"
	;;
    esac
    popd
fi

[ "$(echo $LOGFILE)" ] && sleep 2 ## Just to wait the "tail -f" on the log file attached to the current process

