#!/bin/bash

# overhoor.sh
# @author rene voorburg
# @version 2017-09-26

trap ctrl_c INT

IFS=$'\n'
INFILE=""
WORKFILE=work_$$
ERRORFILE=error_$$
CORRECT=0
WRONG=0
ORDER=0  # (0= left to right, 1=right to left, 2=random)
LIMITER='cat'
RET=''   # used to store return value of functions

usage()
{
    echo "Start het programma met:"
    echo " $0 bestandsnaam"
    echo "of"
    echo " $0 [opties] bestandsnaam"
    echo
    echo "Het bestand bevat tekst met regels als:"
    echo " vraag = antwoord"
    echo " het meisje = la fille "
    echo 
    echo "Als er twee antwoorden goed zijn dan kan dat aangeduid worden als:"
    echo " vraag = antwoord1 ; antwoord 2"
    echo
    echo "De bestanden maak je zelf met een teksteditor (gedit, TextEditor e.d.) of download je van http://www.woordjesleren.nl ."
    echo
    echo "Het is mogelijk om de vragen in omgekeerde volgorde te stellen. Start het programma hiervoor met:"
    echo " $0 -q r bestandsnaam  (ofwel '--question r' => 'right to left')".
    echo "Vragen kunnen ook in beide richtingen gesteld worden. Start het programma hiervoor met:"
    echo " $0 -q b bestandsnaam  (ofwel '--question b' => 'both directions')".
    echo
    echo "Beperk het aantal vragen dat gesteld wordt met de optie '-l aantal' (of '--limit aantal'):"
    echo " $0 -l 10 bestandsnaam (stelt maximaal 10 vragen)."
    echo
}

ctrl_c()
{
    if [ -e $ERRORFILE ] ; then
        rm $ERRORFILE
    fi
        if [ -e $WORKFILE ] ; then
        rm $WORKFILE
    fi 
    exit 1
}

wait_for_key()
{
    local key="$1"
    local msg="$2"
    local pressed

    echo -e "$2"
    while : ; do
        read -t 1 -n 1 pressed 
        #read -t 1 -n ${#key} pressed 
        if [[ "$pressed" = "$key" ]] ; then
            break
        fi
    done
}

strip_spaces()
{
    echo "$1" | perl -pe 's/\s\s+//g' | perl -pe 's/^\s//' | perl -pe 's/\s$//'
}

strip()
{
    strip_spaces "`echo "$1" | perl -pe 's/{.*}//'`"
}

print_array() 
{
    local e
    local sep=''

    for e; do
        echo -n "$sep\""
        echo -n `strip "$e"`
        echo -n "\""
        sep=", "
    done
}

in_array_stripped () 
{
    local e
    local match="`strip "$1"`"
    shift
    for e; do [[ "`strip "$e"`" == "$match" ]] && return 0; done
    return 1
}

get_parts_array()
{
    local in="$1"
    local IFS=';'

    read -r -a RET <<< "$in"
}

randomize_file()
{
    local INFILE=$1
    local outfile=$2
    local line
    
    for line in `cat $INFILE` ; do
        echo "$RANDOM $line"
    done | sort -n | perl -pe 's/^[0-9]+ //' > $outfile
}


# verify parameters given:
while [[ $# -gt 1 ]] ; do
    key="$1"
    case $key in
        -q|--question)
        case "$2" in
            "r")
            ORDER=1
            ;;
            "b")
            ORDER=2
            ;;
            *)
            ORDER=1
            ;;
        esac
        shift # past argument
        ;;
        -l|--limit)
        LIMITER="head -n $2"
        shift
        ;;
        -h|--help)
        usage
        exit 1
        ;;
        *)
        echo "Optie $key onbekend."
        usage
        exit 1
        ;;
    esac
    shift # past argument or value
done

if [ $# -eq 0 ] ; then
    echo "Geen bestand met vragen en antwoorden opgegeven."
    usage
    exit 1
fi

INFILE=$1
if [ ! -e $INFILE ] ; then
    echo "Bestand met vragen en antwoorden ($1) niet gevonden."
    exit 1
fi

# main
clear
randomize_file $INFILE $WORKFILE
while [ $(cat $WORKFILE | grep "=" | eval "$LIMITER" | wc -l) -gt 0 ]  ; do

    for line in `cat $WORKFILE | grep "=" | eval "$LIMITER" ` ; do
    
    	get_parts_array "`echo "$line" | perl -pe 's@=.*@@g'`"
    	left_array=("${RET[@]}")
   		
   		get_parts_array "`echo "$line" | perl -pe 's@.*=@@g'`"
   		right_array=("${RET[@]}")
    
        if  [[ "$ORDER" == "1"  ||  "$ORDER" == "2"  &&  "$((RANDOM % 2))" == "1" ]]  ; then
            questions_array=("${right_array[@]}")
            answers_array=("${left_array[@]}")
        else
            questions_array=("${left_array[@]}")
            answers_array=("${right_array[@]}")
        fi

        echo -ne "\n "
        echo `strip_spaces "${questions_array[$RANDOM % ${#questions_array[@]} ]}"`
        echo -ne "\n "
        read given
        echo
        
        in_array_stripped "$given" "${answers_array[@]}"
        if [ $? -ne 0 ]; then
		    ((WRONG++))
            echo -n " fout,  (CORRECT: "
            print_array "${answers_array[@]}"
            echo ")"
            wait_for_key " " "\n [spatiebalk] om door te gaan" 
            echo "$line" >> $ERRORFILE
        else
            ((CORRECT++))
            if [[ "${#answers_array[@]}" != "1" ]] ; then
                echo -n " CORRECT (" 
                print_array "${answers_array[@]}"
                echo ")"
                sleep 2
            else 
                echo " CORRECT"
                sleep 1
            fi
        fi
        echo
        clear
    done

    if [ -e $ERRORFILE ] ; then
        randomize_file $ERRORFILE $WORKFILE
        rm $ERRORFILE
    else
        > $WORKFILE
    fi    
done
rm $WORKFILE
echo -en "Aantal goed: $CORRECT\nAantal fout: $WRONG\n"
