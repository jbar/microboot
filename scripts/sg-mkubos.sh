#!/bin/bash

DOPTS='
DOCVS=1	            #bool# cvs C 
DOCLEAN=1           #bool# clean c 
DOCLEANALL=0        #bool# clean-all ca 
DOMAPRI=1           #bool# mapri p
DOMAFI=1            #bool# mafi f
DOTARGZ=0           #bool# tgz z

DOCOMPILEOS=1	    #bool# os
DODISPLAYPRG=0	    #bool# displayprg x
DONANOBOOT=1	    #bool# nanoboot n
DOMICROBOOT=1	    #bool# microboot m
DORETROFIT=1	    #bool# retrofit r

DOX62=1	            #bool# 62 kp
DOX62PLUS=1	    #bool# 62p 62plus kpplus kpp
DOX63=1	            #bool# 63 loco
DOX64=1	            #bool# 64 locolight
DODOLO1=0           #bool# dolo
DONEPT=1            #bool# 90 nept
DONEPTODM=1         #bool# 91 neptodm

#UBOSDEBUG=0     #bool# debug D
#UBOSTRACE=0     #bool# trace T
OSTAG=osX6X_MAX_149     #var# -ostag ostag ot
OSKPTAG=oskpTRONC_195_2 #var# -oskptag oskptag kt
UBOSTAG=TRONC	        #var# -ustag ustag t
VERSION=999	        #var# -version version v
BUILDDATE='$(date +%d%m%y_%H%M)'         #var# -date date

## UBOSDIR et LOGFILE peuvent être en chemin absolu ou en chemin relatif : à $HOME par défaut ou au répertoire courant si la variable suit le motif ./* ou ../* .
UBOSDIR="$HOME/en_cours_$UBOSTAG"       #var# -dir dir
LOGFILE="$UBOSDIR/'${0##*/}'_$BUILDDATE.log"  #var# -logfile logfile o

DOCVS=1 DOCLEAN=1 DOMAPRI=1 DOMAFI=1 DOLOG=1 DORETROFIT=1 DOMICROBOOT=1 DODISPLAYPRG=0  DONANOBOOT=0 DOX62=1 DOX62PLUS=1 DOX63=1 DOX64=1 DODOLO1=0 DONEPT=1 DONEPTODM=1 DOCOMPILEOS=1 #bool# all a
'

## Place les options du fichier indiqué ou du fichier de conf par défaut en 1er arguments 
if echo $1 | grep "^[^+-]" > /dev/null ; then
    CFGFILE="$1"
    shift
else
    CFGFILE="./${0##*/}.conf"
fi

if [ -f "$CFGFILE" ] ; then
    set -- $( grep  -v "^[[:space:]]*#" $CFGFILE ) "$@"
    echo -e "Executing ' ${0##*/} $@ ' ...\n" >&2
fi

function mkubos_usage()
{
    echo -e " Usage : ${0##*/} [config_file] [+-[option] [val]] [+-[option] [val]]..."\
            "\nMake Sagem Communication's embedded retrofit softwares (microboots, ROM flash drivers...)"\
            "\n       Options 'h' '-help' or '\?' always show this help"\
	    "\n       If no config file is specified, program try to use ./${0##*/}.conf" >&2
    echo -e "\nDefault values    #(type)# command option\n-----------------------------------------"
    echo "$DOPTS" | grep  "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#\(bool\|var\)#[^#]*$"
    exit $1
}

function end_prg()
{
    echo -e "\n$1"

    ## Count the remarks, warning, errors and Fails in the logfile and set so the script return value.
    if [ "$LOGFILE" ] ; then
	RET=$( grep -c "\<Echec\>" "$LOGFILE" )
	echo -e "\n  "$( grep -ic "\<remark:"  "$LOGFILE" )" compilation remarks."\
		"\n  "$( grep -ic "\<warning:" "$LOGFILE" )" compilation warnings."\
		"\n  "$( grep -ic "\<error:" "$LOGFILE" )" compilation errors."\
		"\n  $RET Echecs.\n" 
	RET=$(($RET>250?250:$RET))
    else
	RET=0
    fi

    [ "$LOGFILE" ] && sleep 2 ## Just to wait the "tail -f" on the log file attached to the current process
    exit $RET
}

## Process arguments.
while [ $# -ge 1 ]; do
  case "$1" in
   [+-]h | [+-]-help | [+-]\? ) 
      mkubos_usage -2
    ;;
   [+-]?* )
    if str="$( echo -e "$DOPTS" | grep -m 1 "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#bool#[^#]*[#[:blank:]]${1:1}\>[^#]*$")" ; then
## L'argument indique un (des) booléens -> on les met à 1 ou à 0.
	if [ "${1:0:1}" == "+" ] ; then 
            eval "$( echo $str | sed ' { s/=0\>/=1/g } ' )"
	else
            eval "$( echo $str | sed ' { s/=1\>/=0/g } ' )"
        fi
    elif str="$(echo -e "$DOPTS" | grep -m 1 "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#var#[^#]*[#[:blank:]]${1:1}\>[^#]*$")" ; then
## L'argument indique une variable -> on la met à la valeur indiqué.
        eval "${str%%=*}=$2"
        shift
    else
## L'argument n'a pas été trouvé -> on insulte le pauvre utilisateur ;-)
        echo "Error:$0: Argument $1 not found !" >&2
        mkubos_usage -1
    fi
    ;;
    * ) 
      echo "Error:$0: Argument $1 not valid !" >&2
      mkubos_usage -1 > /dev/null
    ;;
  esac
shift
done

## Assigne les autres valeurs des options sans écraser une variable déjà définie
for b in $(echo -e "$DOPTS" |  sed -n ' /^[[:space:]]*\<[[:alnum:]_]\+\>=.*#var#[^#]*$/  { s/#var#.*// ; p } ' ) \
	 $(echo -e "$DOPTS" | grep "^[[:space:]]*\<[[:alnum:]_]\+\>=.*#bool#[^#]*$" | grep -o "\<[[:alnum:]_]\+\>=[01]\>" )  ; do 
    if [ -z "$(eval "echo \$${b%%=*}")" ] ; then
       eval "$b"	
    fi
done

## Verifie et exporte la date
if ! echo $BUILDDATE | grep "^[0-9]\{6\}_[0-9]\{4\}$" > /dev/null ; then
    echo "Error: the date has a invalid format, must be 'ddmmyy_hhmm' ." >&2
    mkubos_usage -1 > /dev/null
fi
export BUILDDATE

## Se place dans $UBOSDIR et le convertit éventuellement $UBOSDIR en chemin absolu
pushd ~ > /dev/null
if echo "$UBOSDIR" | grep "^[ ]*\.\.\?/" > /dev/null ; then cd - ; fi
mkdir -p "$UBOSDIR" || exit -3
cd "$UBOSDIR"
UBOSDIR=$PWD

## Copie la sortie standard dans un fichier de log si fichier de log indiqué et convertit éventuellement $LOGFILE en chemin absolu
if [ "$LOGFILE" == "none" -o -z "$(echo $LOGFILE)" ] ; then
    LOGFILE=""
else
    if echo "$LOGFILE" | grep "^[ ]*\.\.\?/\?" > /dev/null ; then cd "$(dirs -l -0)" ; else cd ; fi
    if ! echo "$LOGFILE" | grep "^/.*" > /dev/null ; then LOGFILE="$PWD/$LOGFILE" ; fi
    echo -e "\n--- $(date +%d%m%y_%H%M) -- Starting $0 \$Revision: 1.1.2.22 $ ---" >> "$LOGFILE" || exit -3
    sleep 1
    tail --pid $$ -f "$LOGFILE" &
    exec >> "$LOGFILE" 2>&1
    cd "$UBOSDIR"
fi

## The following lines may need improvements
TARGET_LIST_ERTFS_____=""
TARGET_LIST_NFTL______=""
TARGET_LIST_FLHDRVNAND=""
TARGET_LIST_OS________=""
TARGET_LIST_ZLib______=""
TARGET_LIST_Signatures=""

if [ "$DOX62" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| 62    "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti25_32"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|-------"

    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____        "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______        "
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND        "
    TARGET_LIST_OS________="$TARGET_LIST_OS________        "
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti25_32"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures ti25_32"
fi
if [ "$DOX62PLUS" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| 62+        "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti25nu ti2kp"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|------------"

    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____ ti25nu      "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______ ti25nu      "
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND ti25nu      "
    TARGET_LIST_OS________="$TARGET_LIST_OS________ ti25nu ti2kp"
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti25nu ti2kp"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures        ti2kp"
fi
if [ "$DOX63" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| 63      "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti25xloco"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|---------"

    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____          "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______ ti25xloco"
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND ti25xloco"
    TARGET_LIST_OS________="$TARGET_LIST_OS________ ti25xloco"
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti25xloco"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures ti25xloco"
fi
if [ "$DOX64" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| 64      "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti25xloco"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|---------"
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND          "
    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____          "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______          "
    TARGET_LIST_OS________="$TARGET_LIST_OS________          "
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti25xloco"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures ti25xloco"
fi
if [ "$DODOLO1" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| dolo1    "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti2dolo_32"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|----------"

    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____           "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______           "
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND           "
    TARGET_LIST_OS________="$TARGET_LIST_OS________           "
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti2dolo_32"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures ti2dolo_32"
fi
if [ "$DONEPT" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| nept             "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti2nept ti2nept_32"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|------------------"

    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____                   "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______         ti2nept_32"
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND         ti2nept_32"
    TARGET_LIST_OS________="$TARGET_LIST_OS________ ti2nept           "
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti2nept ti2nept_32"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures         ti2nept_32"
fi
if [ "$DONEPTODM" = "1" ]; then
    TARGET_LIST_NAME______="$TARGET_LIST_NAME______| neptodm          "
    TARGET_LIST_COMP______="$TARGET_LIST_COMP______ ti2nept ti2nept_32"
    TARGET_LIST_ECHO______="$TARGET_LIST_ECHO______|------------------"

    TARGET_LIST_ERTFS_____="$TARGET_LIST_ERTFS_____                   "
    TARGET_LIST_NFTL______="$TARGET_LIST_NFTL______         ti2nept_32"
    TARGET_LIST_FLHDRVNAND="$TARGET_LIST_FLHDRVNAND         ti2nept_32"
    TARGET_LIST_OS________="$TARGET_LIST_OS________ ti2nept           "
    TARGET_LIST_ZLib______="$TARGET_LIST_ZLib______ ti2nept ti2nept_32"
    TARGET_LIST_Signatures="$TARGET_LIST_Signatures         ti2nept_32"
fi

## Display a resume of configuration before to launch compilations
echo  -e " version=$VERSION  $( (($DOCVS)) && echo "tag=$UBOSTAG" )" \
      "\n build date = $BUILDDATE" \
      "\n directory=$UBOSDIR" \
      "$( [ "$LOGFILE" ] && echo "\n log file =$LOGFILE" )" \
      "\n cvs=$DOCVS clean=$( [ "$DOCLEANALL" == "1" ] &&  printf "All"  || printf "$DOCLEAN" )      mapri=$DOMAPRI mafi=$DOMAFI" \
      "\n x62=$DOX62 x62plus=$DOX62PLUS  x63=$DOX63 x64=$DOX64 dolo1=$DODOLO1 nept=$DONEPT neptodm=$DONEPTODM" \
      "\n compile os =$DOCOMPILEOS  displayprg=$DODISPLAYPRG  nanoboot=$DONANOBOOT  microboot=$DOMICROBOOT  retrofit=$DORETROFIT
      |-----------|$TARGET_LIST_ECHO______|
      |target name|$TARGET_LIST_NAME______|
      |-----------|$TARGET_LIST_ECHO______|
      |compiler   |$TARGET_LIST_COMP______|
      |-----------|$TARGET_LIST_ECHO______|
      |ERTFS      |$TARGET_LIST_ERTFS_____|
      |NFTL       |$TARGET_LIST_NFTL______|
      |FLHDRVNAND |$TARGET_LIST_FLHDRVNAND|
      |OS         |$TARGET_LIST_OS________|
      |ZLib       |$TARGET_LIST_ZLib______|
      |Signatures |$TARGET_LIST_Signatures|
      |-----------|$TARGET_LIST_ECHO______|
      \nType Enter or wait 10 sec to continue. Type Ctrl-C to abort."
read -t 10

trap 'end_prg "Interrupted by user (Echec)"' SIGINT

## Here is stopped the main execution to declare some functions (which are used only once...).

NEWUBOS_f_CompileOS()
{
## Compile OS
    echo "==> Compiling OS..."
	cd "$UBOSDIR/oskp"
        cd "$UBOSDIR/oskp/usb"
        mkdir -p obj
        for TARGET in $TARGET_LIST_OS________ ; do
            mkdir -p "$UBOSDIR/oskp/obj${TARGET}"
  ## Compile USB
	    case $TARGET in 
              ti25nu | ti2kp ) 
		pushd "$UBOSDIR/os4kpp/oskp" || ( echo "Have u enable kpplus when u get from CVS ?" >&2 ; exit -3 )
		mkdir -p "$UBOSDIR/oskp/obj${TARGET}"
		cd "$UBOSDIR/os4kpp/oskp/usb"
		compilusb.X UBOOT_kp
		popd
		;;
              ti2nept ) compilusb.X UBOOT_nept nomm ;;
              ti25xloco ) compilusb.X UBOOT_loco nomm ;;
	    esac
        done

  ## Compile ERTFS
    for i in oskp/storage/ertfs2 \
             oskp/eco/common \
             oskp/hardti/r5314 \
             oskp/hardti/uwire \
             oskp/hardti/gpio \
             oskp/storage/ftl_nor ; do
        echo " Compiling $i ..."
        cd "$UBOSDIR/$i" || exit -3
        for TARGET in $TARGET_LIST_ERTFS_____ ; do 
	    case $TARGET in 
              ti25nu | ti2kp ) 
		pushd "$UBOSDIR/os4kpp/$i" || ( echo "Have u enable kpplus when u get from CVS ?" >&2 ; exit -3 )
                m $TARGET -Dubo -Dkp | qur2
		popd
		;;
	      * )
                m $TARGET -Dubo -Dkp | qur2
		;;
	    esac
        done
    done
    echo " Compiling oskp/storage/sd ..."
    cd "$UBOSDIR/oskp/storage/sd" || exit -3
    for TARGET in $TARGET_LIST_ERTFS_____ ; do
	    case $TARGET in 
              ti25nu | ti2kp ) 
		pushd "$UBOSDIR/os4kpp/oskp/storage/sd" || ( echo "Have u enable kpplus when u get from CVS ?" >&2 ; exit -3 )
		m $TARGET -Dubo -Dm2005 -Dkp | qur2
		popd
		;;
	      * )
	        m $TARGET -Dubo -Dm2005 -Dkp | qur2
		;;
	    esac
    done

  ## Compile NFTL
    echo "--> Compiling NFTL..."
    cd "$UBOSDIR/oskp/storage/nftl" && mkdir -p obj || exit -3
    for TARGET in $TARGET_LIST_NFTL______ ; do
        case $TARGET in 
            ti25nu | ti2kp ) 
		pushd "$UBOSDIR/os4kpp/oskp/storage/nftl" && mkdir -p obj || exit -3
		m $TARGET nor nand kp niron opt2 nopt
		popd
		;;
            ti25xloco ) m $TARGET nor nand loco niron opt2 nopt ;;
            ti2nept_32 ) m $TARGET nor nand nept niron opt2 nopt ;;
        esac
    done

  ## Compile FLHDRVNAND        
    echo "--> Compiling Nand Flash Driver..."
    for TARGET in $TARGET_LIST_FLHDRVNAND ; do
        case $TARGET in 
          ti25nu | ti2kp ) 
            cd "$UBOSDIR/os4kpp/oskp/storage/drv_flhnand" && mkdir -p obj || exit -3
            m $TARGET kp sam76 opt2 nopt
            cd "$UBOSDIR/os4kpp/oskp/storage/ctrl_flhnand" && mkdir -p obj || exit -3
            m $TARGET kp opt2 nopt
	    ;;
	  ti25xloco )
            cd "$UBOSDIR/oskp/storage/drv_flhnand2" && mkdir -p obj || exit -3
            m $TARGET loco sam76 opt2 nopt
            cd "$UBOSDIR/oskp/storage/ctrl_flhnand2" && mkdir -p obj || exit -3
            m $TARGET loco opt2 nopt
	    ;;
	  ti2nept_32 )
            cd "$UBOSDIR/oskp/hardti/mmu"  && mkdir -p obj || exit -3
            m $TARGET nept sam76 opt2 nopt ubo
	    cd "$UBOSDIR/oskp/storage/drv_flhnand3" && mkdir -p obj || exit -3
            m $TARGET nept sam76 opt2 nopt ubo
            cd "$UBOSDIR/oskp/storage/ctrl_flhnand3" && mkdir -p obj || exit -3
            m $TARGET nept opt2 nopt emifs ubo
            ;;
	esac
    done

  ## Link all ti25nu and ti2kp objects in the main tree structure.
    if  [ "$DOX62PLUS" != 0 ] ; then
	pushd "$UBOSDIR/os4kpp"
	find oskp \( -iname "*ti25nu*.o" -o -iname "*ti2kp*.o" \) -a -xtype f | while read line ; do
	    mkdir -p "../${line%/*}"
	    ln -s "$( echo "${line%/*}/" | sed '{ s/[[:alnum:]_-]\+\//\.\.\//g }' )os4kpp/$line" "../$line"
	done
	popd
    fi
}

NEWUBOS_f_CompileNanoboot()
{
        cd "$UBOSDIR/os/hardti/nanoboot"
        [ "$DOMAPRI" = "1" ] && mapri3
        [ "$DOMAFI" = "1" ] && mafi
        if [ "$DONEPT" = "1" ]; then
            cd "$UBOSDIR/os/hardti/nanoboot"
            (cd neptune; make all_neptune VERSION=${VERSION} TARGET=90)
        fi
        
        if [ "$DONEPTODM" = "1" ]; then
            cd "$UBOSDIR/os/hardti/nanoboot"
            (cd neptune; make all_neptodm VERSION=${VERSION} TARGET=91 ODM=odm)
        fi
}

NEWUBOS_f_CompileUBoot()
{
        cd "$UBOSDIR/os/hardti/microboot"
        [ "$DOMAPRI" = "1" ] && mapri3
        [ "$DOMAFI" = "1" ] && mafi
        cd fab
	echo -e ":020000040400F6\n:00000001FF" > dummy.i32
        if [ "$DOX62" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x62
        fi
        if [ "$DOX62PLUS" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x62+
        fi
        if [ "$DOX63" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x63
        fi
        if [ "$DOX64" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x64
        fi
        if [ "$DODOLO1" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x80
        fi
        if [ "$DONEPT" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x90
        fi
        if [ "$DONEPTODM" = "1" ]; then
            perl faball.pl v=${VERSION} platform=x91
        fi
}

NEWUBOS_f_CompileRetrofit()
{
        cd "$UBOSDIR/os/hardti/retrofit"
        [ "$DOMAPRI" = "1" ] && mapri3
        [ "$DOMAFI" = "1" ] && mafi
        cd fab
        chmod +x faball fab.pl
        if [ "$DOX62" = "1" ]; then
            ./faball v=${VERSION} g2
        fi
        if [ "$DOX62PLUS" = "1" ]; then
            ./faball v=${VERSION} kp
        fi
        if [ "$DOX63" = "1" ]; then
            ./faball v=${VERSION} loco
        fi
        if [ "$DOX64" = "1" ]; then
            ./faball v=${VERSION} loco light
        fi
        if [ "$DODOLO1" = "1" ]; then
            ./faball v=${VERSION} dolo
        fi
        if [ "$DONEPT" = "1" ]; then
            ./faball v=${VERSION} nept
        fi
        if [ "$DONEPTODM" = "1" ]; then
            ./faball v=${VERSION} nept odm
        fi
}

NEWUBOS_f_CompileDisplayPrg()
{
        cd "$UBOSDIR/os/hardti/displayprg"
        [ "$DOMAPRI" = "1" ] && mapri3
        [ "$DOMAFI" = "1" ] && mafi
        cd fab
        chmod +x faball fab.pl
        if [ "$DOX62" = "1" ]; then
            ./faball v=${VERSION} g2
        fi
        if [ "$DOX62PLUS" = "1" ]; then
            ./faball v=${VERSION} kp
        fi
        if [ "$DOX63" = "1" ]; then
            ./faball v=${VERSION} loco
        fi
        if [ "$DOX64" = "1" ]; then
            ./faball v=${VERSION} loco light
        fi
        if [ "$DODOLO1" = "1" ]; then
            ./faball v=${VERSION} dolo
        fi
        if [ "$DONEPT" = "1" ]; then
            ./faball v=${VERSION} nept
        fi
        if [ "$DONEPTODM" = "1" ]; then
            ./faball v=${VERSION} nept odm
        fi
}

## Declare the function banner if the banner command doesn't exist or is not as expected
if ! banner --usage 2>&1 | grep -i "\<\(string\|print\)\>.*\<\(string\|print\)\>" > /dev/null ; then 
    function banner()
    {
    echo -e "########################################"\
          "\n$*"\
          "\n########################################"
    }
fi

## Here continue at last the main execution.
cd "$UBOSDIR"

if [ "$DOCLEANALL" == "1" ] ; then
    echo "==> Removing All intermediate and compilated files..."
    find ./os* \( -name 'obj*' -o -name '[0123]*' -o -name '*.err' -o -name '*.o' -o -name '*.obj' -o -name '*.exe' -o -name '*.bin' -o -name '*.i32' -o -name '*.a32' -o -name '*.map' -o -name '*.elf' -o -name '*.rawprg' -o -name \*_${VERSION}_\* \) -print -exec rm -rf {} \;
    echo
elif  [ "$DOCLEAN" == "1" ] ; then
    echo "==> Removing mobiletool intermediate and compilated files..."
    find ./os \( -name 'obj*' -o -name '[0123]*' -o -name '*.err' -o -name '*.o' -o -name '*.obj' -o -name '*.exe' -o -name '*.bin' -o -name '*.i32' -o -name '*.a32' -o -name '*.map' -o -name '*.elf' -o -name '*.rawprg' -o -name \*_${VERSION}_\* \) -print -exec rm -rf {} \;
    echo
fi

if [ "$DOCVS" = "1" ] ; then
    echo "Updating files regarding CVS database (directory=$UBOSDIR)..."
    
    if [ "$DOX62PLUS" != 0 ] ; then
	mkdir -p "$UBOSDIR/os4kpp"
	pushd "$UBOSDIR/os4kpp"
	cvs get -rosX6X_MAX_140   os/inc
	cvs get -rosX6X_MAX_140   os/hardti/inc
	cvs get -rosX6X_MAX_140   os/hardti/tiv24drv_sio/inc
	cvs get -rosX6X_MAX_140   os/hardti/tidpll/inc

	cvs get -roskpTRONC_163   oskp/usb
	cvs get -roskpTRONC_163   oskp/inc
	cvs get -roskpTRONC_163   oskp/bin
	cvs get -roskpTRONC_163   oskp/hardti/uwire
	cvs get -roskpTRONC_163   oskp/hardti/gpio
	cvs get -roskpTRONC_163   oskp/hardti/r5314
	cvs get -roskpTRONC_163   oskp/hardti/inc
	cvs get -roskpTRONC_163   oskp/eco
	cvs get -roskpTRONC_163   oskp/storage/sd
	cvs get -roskpTRONC_163   oskp/storage/ftl_nor
	cvs get -roskpTRONC_163   oskp/storage/ertfs2
	cvs get -roskpTRONC_163   oskp/storage/inc
	cvs get -roskpTRONC_163   oskp/storage/drv_flhnand
	cvs get -roskpTRONC_163   oskp/storage/ctrl_flhnand
	cvs get -roskpTRONC_163   oskp/storage/nftl

	cvs get -roskpTRONC_163   inc1
	cvs get -roskpTRONC_163   inc2
	cvs get -roskpTRONC_163   inc3
	cvs get -roskpTRONC_163   inc4
	cvs get -roskpTRONC_163   inc
	popd
    fi

    cvs get -r$OSTAG   os/inc
    cvs get -r$OSTAG   os/hardti/inc
    cvs get -r$OSTAG   os/hardti/tiv24drv_sio/inc
    cvs get -r$OSTAG   os/hardti/tidpll/inc

    cvs get -r$OSKPTAG   oskp/usb
    cvs get -r$OSKPTAG   oskp/inc
    cvs get -r$OSKPTAG   oskp/bin
    cvs get -r$OSKPTAG   oskp/hardti/uwire
    cvs get -r$OSKPTAG   oskp/hardti/gpio
    cvs get -r$OSKPTAG   oskp/hardti/r5314
    cvs get -r$OSKPTAG   oskp/hardti/inc
    cvs get -r$OSKPTAG   oskp/eco
    cvs get -r$OSKPTAG   oskp/storage/sd
    cvs get -r$OSKPTAG   oskp/storage/ftl_nor
    cvs get -r$OSKPTAG   oskp/storage/ertfs2
    cvs get -r$OSKPTAG   oskp/storage/inc
    cvs get -r$OSKPTAG   oskp/storage/drv_flhnand
    cvs get -r$OSKPTAG   oskp/storage/ctrl_flhnand
    cvs get -r$OSKPTAG   oskp/storage/drv_flhnand2
    cvs get -r$OSKPTAG   oskp/storage/ctrl_flhnand2
    cvs get -r$OSKPTAG   oskp/storage/drv_flhnand3
    cvs get -r$OSKPTAG   oskp/storage/ctrl_flhnand3
    cvs get -r$OSKPTAG   oskp/storage/nftl
    cvs get -r$OSKPTAG   oskp/hardti/mmu

    cvs get -r$OSKPTAG   inc1
    cvs get -r$OSKPTAG   inc2
    cvs get -r$OSKPTAG   inc3
    cvs get -r$OSKPTAG   inc4
    cvs get -r$OSKPTAG   inc

    ( cd os/hardti/inc ;
      cvs get -r$UBOSTAG -dmobiletool      mobiletool/inc ;
    )
    ( cd os/hardti ;
      cvs get -r$UBOSTAG -dmicroboot mobiletool/microboot ;
      cvs get -r$UBOSTAG -dretrofit  mobiletool/retrofit ;
      cvs get -r$UBOSTAG -dnanoboot  mobiletool/nanoboot ;
      cvs get -r$UBOSTAG -ddisplayprg mobiletool/displayprg ;
      cvs get -r$UBOSTAG -dzlib      mobiletool/zlib ;
      cvs get -r$UBOSTAG -dsignature mobiletool/signature ;
      cvs get -r$UBOSTAG -dlibext    mobiletool/libext 
    )
    echo
fi

if [ "$DORETROFIT" = "1" -o "$DOMICROBOOT" = "1" -o "$DODISPLAYPRG" = "1" -o "$DONANOBOOT" = "1" ]; then 

    [ "$DOCOMPILEOS" = "1" ] && NEWUBOS_f_CompileOS         

## Compile ZLib
    echo "==> Compiling ZLib..."
        cd "$UBOSDIR/os/hardti/zlib"
        [ "$DOMAPRI" = "1" ] && mapri3
        [ "$DOMAFI" = "1" ] && mafi
        for TARGET in $TARGET_LIST_ZLib______ ; do
	    m $TARGET | qur2
        done

## Compile Signatures
    echo "==> Compiling signatures..."
        cd "$UBOSDIR/os/hardti/signature"
        [ "$DOMAPRI" = "1" ] && mapri3
        [ "$DOMAFI" = "1" ] && mafi
        for TARGET in $TARGET_LIST_Signatures ; do
	    m $TARGET -Dsigx | qur2
        done

        if [ "$DONANOBOOT" = "1" ]; then
            banner "Nanoboot"
            NEWUBOS_f_CompileNanoboot
        fi
        if [ "$DOMICROBOOT" = "1" ]; then
            banner "UBoot"
            NEWUBOS_f_CompileUBoot
        fi
        if [ "$DORETROFIT" = "1" ]; then
            banner "Retrofit"
            NEWUBOS_f_CompileRetrofit
        fi
        if [ "$DODISPLAYPRG" = "1" ]; then
            banner "Display"
            NEWUBOS_f_CompileDisplayPrg
        fi
        echo
fi

## Archive all generated files (source files to generate a release)
if [ "$DOTARGZ" = "1" ]; then
    banner "${VERSION}.tar.gz"
    cd "$UBOSDIR"
    rm -f ${VERSION}.tar.gz
    tar czf ${VERSION}.tar.gz \
        os/hardti/microboot/fab/*.bin \
        os/hardti/microboot/fab/*.i32 \
        os/hardti/microboot/fab/*/*.out \
        os/hardti/microboot/fab/*/*.map \
        os/hardti/retrofit/fab/*.rawprg \
        os/hardti/retrofit/fab/*.i32 \
        os/hardti/retrofit/fab/*/*.out \
        os/hardti/retrofit/fab/*/*.map \
        os/hardti/displayprg/fab/*.rawprg \
        os/hardti/displayprg/fab/*/*.i32 \
        os/hardti/displayprg/fab/*/*.out \
        os/hardti/displayprg/fab/*/*.map \
        os/hardti/nanoboot/*/*/*.a32 \
        os/hardti/nanoboot/*/*/*.out \
        os/hardti/nanoboot/*/*/*.i32 \
        *.log
    ls -l ${VERSION}.tar.gz
fi

end_prg

