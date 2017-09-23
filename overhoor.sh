#!/bin/bash

# overhoor.sh
# @author rene voorburg
# @version 2017-09-23

trap ctrl_c INT

IFS=$'\n'
infile=""
workfile=work_$$
errorfile=error_$$
correct=0
wrong=0
order=0  # (0= left to right, 1=right to left, 2=random)

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
}

ctrl_c()
{
    if [ -e $errorfile ] ; then
        rm $errorfile
    fi
        if [ -e $workfile ] ; then
        rm $workfile
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
        read -st 1 -n ${#key} pressed 
        if [[ "$pressed" = "$key" ]] ; then
            break
        fi
    done
}

strip_spaces()
{
    echo "$1" | perl -pe 's/\s\s+//g' | perl -pe 's/^\s//' | perl -pe 's/\s$//' | perl -pe 's/{.*}//'
}

print_array() 
{
    local e
    local sep=''

    for e; do
        echo -n "$sep\""
        echo -n `strip_spaces "$e"`
        echo -n "\""
        sep=", "
    done
}

in_array_stripped () 
{
    local e
    local match="`strip_spaces "$1"`"
    shift
    for e; do [[ "`strip_spaces "$e"`" == "$match" ]] && return 0; done
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
    local infile=$1
    local outfile=$2
    local line
    
    for line in `cat $infile` ; do
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
            order=1
            ;;
            "b")
            order=2
            ;;
            *)
            order=1
            ;;
        esac
        shift # past argument
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

infile=$1
if [ ! -e $infile ] ; then
    echo "Bestand met vragen en antwoorden ($1) niet gevonden."
    exit 1
fi

# main
clear
randomize_file $infile $workfile
while [ $(cat $workfile | grep "=" | wc -l) -gt 0 ]  ; do

    for line in `cat $workfile | grep "="` ; do
    
    	get_parts_array "`echo "$line" | perl -pe 's@=.*@@g'`"
    	left_array=("${RET[@]}")
   		
   		get_parts_array "`echo "$line" | perl -pe 's@.*=@@g'`"
   		right_array=("${RET[@]}")
    
        if  [[ "$order" == "1"  ||  "$order" == "2"  &&  "$((RANDOM % 2))" == "1" ]]  ; then
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
		    ((wrong++))
            echo -n " fout,  (correct: "
            print_array "${answers_array[@]}"
            echo ")"
            wait_for_key " " "\n [spatiebalk] om door te gaan" 
            echo "$line" >> $errorfile
        else
            ((correct++))
            if [[ "${#answers_array[@]}" != "1" ]] ; then
                echo -n " correct (" 
                print_array "${answers_array[@]}"
                echo ")"
                sleep 2
            else 
                echo " correct"
                sleep 1
            fi
        fi
        echo
        clear
    done

    if [ -e $errorfile ] ; then
        randomize_file $errorfile $workfile
        rm $errorfile
    else
        > $workfile
    fi    
done
rm $workfile
echo -en "Aantal goed: $correct\nAantal fout: $wrong\n"
