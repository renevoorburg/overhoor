#!/bin/bash

# overhoor.sh
# @author rene voorburg
# @version 2017-09-20

trap ctrl_c INT

IFS=$'\n'
infile=""
workfile=work_$$
errorfile=error_$$
correct=0
wrong=0
order=0  # (0= left to right, 1=right to left, 2=random)

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
    local pressed

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

left_part()
{
    echo $(strip_spaces "`echo "$1" | perl -pe 's/;.*$//'`")
}

right_part()
{
    echo $(strip_spaces "`echo "$1" | perl -pe 's/^.*;//'`")
}

select_question_part()
{
    if [[ "$((RANDOM % 2))" == "1" ]] ; then
        echo $(left_part "$1")
    else
        echo $(right_part "$1")
    fi
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

    for regel in `cat $workfile | grep "="` ; do
        left="`echo "$regel" | perl -pe 's@=.*@@g'`"
        right="`echo "$regel" | perl -pe 's@.*=@@g'`"

        if  [[ "$order" == "1"  ||  "$order" == "2"  &&  "$((RANDOM % 2))" == "1" ]]  ; then
            question="$right"
            answer=$(left_part "$left")
            alt=$(right_part "$left")
        else
            question="$left"
            answer=$(left_part "$right")
            alt=$(right_part "$right")
        fi

        echo -ne "\n "
        echo $(select_question_part "$question")
        echo -ne "\n "
        read given
        given=$(strip_spaces "$given")
        echo

        if [[ "$given" == "$answer" || "$given" == "$alt" ]] ; then
            ((correct++))
            if [[ "$answer" != "$alt" ]] ; then
                echo " correct (\"$answer\", \"$alt\")" 
                sleep 2
            else 
                echo " correct"
                sleep 1
            fi
        else
            ((wrong++))
            echo " fout, moest zijn \"$answer\""
            echo -e "\n [spatiebalk] om door te gaan" 
            wait_for_key " "
            echo "$left = $right" >> $errorfile
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
