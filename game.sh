#!/bin/bash

# --------------------------------

# Pre-define output colors
BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# --------------------------------

# Get ready the crucial files:
FILE="game_data"

touch $FILE word_list

# --------------------------------

watch_script ()
{
 while read -r line
 do
   stripped=${line:3:${#line}}

   if [[ ${line:0:1} == "Y" ]]
   then
     echo -e "${GREEN}$stripped${NC}"
   elif [[ ${line:0:1} == "N" ]]
   then
     echo -e "${RED}$stripped${NC}"
   fi
 done <<< "$(cat $FILE)"
}

watch_script_formated ()
{
 COUNT=1
 while true
 do
   clear
   if [ "$COUNT" == 0 ]; then echo -e "${BOLD}Watching \n${NC}"; ((COUNT++))
   elif [ "$COUNT" == 1 ]; then echo -e "${BOLD}Watching .\n${NC}"; ((COUNT++))
   elif [ "$COUNT" == 2 ]; then echo -e "${BOLD}Watching ..\n${NC}"; ((COUNT++))
   elif [ "$COUNT" == 3 ]; then echo -e "${BOLD}Watching ...\n${NC}"; COUNT=0
   fi
 watch_script
 sleep 1
 done
}

# --------------------------------

generate ()
{
 STRING=""
 if [ $((RANDOM%2)) -eq 0 ]
 then
   STRING="Y: "
 else
   STRING="N: "
 fi

 GENERATED_WORD=$( tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w $((1+RANDOM%15)) | head -n 1)

 FINAL_STRING="$STRING$GENERATED_WORD"

 flock -x $FILE -c "echo $FINAL_STRING >> $FILE"
}

# --------------------------------

check_win ()
{
 flock $FILE -c :
 if [ "$(grep -c -e "^N: .+" "$FILE")" -eq 0 ]
 then
   kill "$GENERATOR_PID"
   echo -e "${BOLD}DATABÁZE VYČIŠTĚNA; VIRUS ZASTAVEN${NC}"
   exit 0;
 fi
 flock -u $FILE -c :
}

# --------------------------------

if [ -n "$1" ]
then
  if [ "$1" = "--watch" ]
  then
    watch_script_formated
    exit 0;
  elif [ "$1" = "--show" ]
  then
    clear
    watch_script
    exit 0;
  elif [ "$1" = "--generate" ]
  then
    while true
    do
      generate
      sleep 10
    done
  else
    # Nápověda
    echo -e "\nPoužití: $0 [--help|--watch|--show|--generator]\n\n\t--help\t\tVypíše nápovědu\n\t--watch\t\tBude sledovat databázi\n\t--show\t\tVypíše databázi\n\t--generate\tZačne periodicky generovat nové záznamy do databáze\n";
    echo -e "Základní ovládání:\n\tZadejte slovo (řetězec bez bílých znaků)\n\tTento řetězec bude použit jako regulární výraz pro vyhledávání v databázi.\n"
    echo -e "\tPokud byly vybrány pouze položky nebezpečné položky (červené), všechny tyto položky budou z databáze odstraněny\n"
    echo -e "Základy regulárních výrazů:\n\t.\tlibovolný znak\n\t?\tnula jeden výskyt\n\t*\tlibovolný počet\n\t+\tjedna nebo více opakování\n\t[ ]\todpovídá jednomu ze znaků v závorkách\n\t[^ ]\tlibovolný znak neuvedený v závorkách\n\t[ - ]\tlibovolný znak z rozsahu (kupř \"[a-z]\" odpov8d8 libovolnému malému písmenu)\n\t\\ \tvrací metaznaku původní význam (kupř. \"a\\+b\" znamená \"a+b\")\n\t^\tna začátku výrazu\n\t$\tna konci výrazu\n\t{x}\tprávě 'x' opakování\n\t{x,y}\topakování mezi počtem 'x' a 'y'\n"
    echo -e "Příklady použití regulárních výrazů:\n\t\n\t^pi[vl][oa]$\t\tvybrere: \"pivo, pila, piva, pilo\"\n\t.*\t\t\tlibovolný počet libovolných znaků - vybere úplně vše\n\t^[ab].{4,5}[x-z]$\tvybere všechny řetězce které mají 6 až 7 znaků, začínají 'a' anebo 'b' končí 'x' nebo 'y' nebo 'z'\n"
    exit 0;
  fi
fi


# --------------------------------

sh "$0" --generate &
GENERATOR_PID=$!

while true
do
Y_COUNTER=0
LINE_COUNTER=0
LINE_ARRAY=()

  # Read an input from the user
  # First word is used, the rest will be ignored
  while true
  do
    read -e -p -r "Zadejte výraz: " regexp _
    if [ "$regexp" != "" ]; then break; fi
  done

  # Obtain a file lock
  flock -x $FILE -c :

  # Select the matching lines with the provided REGEXP
  while read -r line
  do
    ((LINE_COUNTER++))
    stripped=${line:3:${#line}}
    match_count=$(echo "$stripped" | sed -E -n /"$regexp"/p | wc -l)
    if [ "$match_count" != 0 ]
    then
      if [ "${line:0:1}" == "Y" ]
      then
        echo -e "${GREEN}$stripped${NC}"
        ((Y_COUNTER++))
      elif [ "${line:0:1}" == "N" ]
      then
        echo -e "${RED}$stripped${NC}"
        LINE_ARRAY+=("$LINE_COUNTER")
      fi
    fi
  done <<< "$(cat $FILE)"


  if [ "$Y_COUNTER" != 0 ]
  then
    echo -e "${BOLD}OZNAČENÉ ZÁZNAMY NEOBSAHUJÍ POUZE ZÁVADNÁ DATA !${NC}"
    generate
  else
    for LINE_NUMBER in "${LINE_ARRAY[@]}"
    do
      sed -i "$LINE_NUMBER""d" $FILE
    done
    echo -e "${BOLD}OZNAČENÉ ZÁZNAMY BYLY VYMAZÁNY !${NC}"
  fi

  flock -u $FILE -c :

  check_win

  sleep 1

done
