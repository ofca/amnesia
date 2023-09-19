#!/usr/bin/env bash

set -eo pipefail

# URL to repository with scripts.
URL=""
# Path to directory with amnesia data.
CFG_DIR="$HOME/.config/amnesia"

[[ "$AMNESIA_LOCAL" == "1" ]] && LOCAL="1" || LOCAL="0"

mkdir -p "$CFG_DIR"

DIM='\033[0;37m'
GRN='\033[0;32m'
RED='\033[0;31m'
YLW='\033[0;33m'
BLU='\033[0;34m'
MGT='\033[0;35m'
CYN='\033[0;36m'
WHT='\033[0;97m'
NC='\033[0m'
LONGEST_ID=1

# Make sure repository URL is set.
if [[ "$LOCAL" == "1" ]]; then
  URL="./repo"
else
  if [ -z "$URL" ]; then
    # Ask for repository url if not defined.
    if [ ! -f "$CFG_DIR/url" ]; then
      ask_for_url
    fi

    URL=$(cat "$CFG_DIR/url")
  fi
fi

# Ask for URL and save it to file.
#
# @return void
function ask_for_url() {
  local url=""
  if [ -f "$CFG_URL/url" ]; then
    url=$(cat "$CFG_URL/url")
    fi

  echo -e "Current URL: $url"
  echo -ne "Provide repository URL\n$BLU:$NC "
  read user_input
  if [[ -n "$user_input" ]]; then
    if ! [[ "$user_input" =~ ^http ]]; then
      user_input="https://github.com/$user_input"
      fi
    echo "$user_input" > "$CFG_DIR/url"
    echo -e "${GRN}URL set.$NC"
    rm -f "$CFG_DIR/index"
    fi;
}

# Fetch file from repository url.
#
# @param string Path to the file.
# @return string File content.
function fetch() {
  local path=$1

  if [ "$LOCAL" == "1" ]; then
    cat "$URL/$path"
  else
    curl -s -o - "$URL/$path"
    fi
}

function print_scripts_list() {
  local match="$*"
  local index=1
  local group
  local _group
  local group_rendered="0"

  while read -r line; do
    _group=$(get_group_from_index_entry "$line")
    if [[ -n "$_group" ]]; then
      group="$_group"
      group_rendered="0"
      continue
      fi
    [ -n "$(skip_entry "$line")" ] && continue

    id="$group:$(get_id_from_index_entry "$line")"
    desc="$(get_description_from_index_entry "$line")"
    if [[ "$(match_entry "$id" "$desc" "$match")" == "1" ]]; then
      if [ "$group_rendered" == "0" ]; then
        group_rendered="1"
        echo -e "\n$GRN# ${group^}.$NC"
        fi
      echo -e "$(build_entry "$line" "$index" "$group")"
      fi
    index=$((index+1))
  done < "$(get_index_file)"
}

# Calculate longest id name.
#
# @param ... Arguments provided by user.
# @return void
function get_longest() {
  local match="$*"
  local group
  local _group
  local id
  local desc

  while read -r line; do
    _group=$(get_group_from_index_entry "$line")
    [[ -n "$_group" ]] && group="$_group"
    [ -n "$(skip_entry "$line")" ] && continue

    id="$group:$(get_id_from_index_entry "$line")"
    desc="$(get_description_from_index_entry "$line")"

    if [[ "$(match_entry "$id" "$desc" "$match")" == "1" ]]; then
      if (( max_id < ${#id} )); then
        max_id=${#id}
        fi
      fi
  done < "$(get_index_file)"

  LONGEST_ID="$(( $max_id + 2 ))"
}

function ask_to_select_script() {
  #echo -en "\nSelect script (provide number from ${GRN}1$NC to $GRN$MAX_SCRIPT_INDEX$NC).\nAdd ${GRN}question mark$NC (${GRN}?$NC) after number to see script help.\nProvide ${RED}q$NC to exit.\n$BLU:$NC "
  echo -en "$BLU:$NC "
  read user_input

  if [[ "$user_input" == "q" ]]; then
    echo -e "${YLW}Bye!$NC"
    exit 0
  fi

  if ! [[ "$user_input" =~ ^[0-9]+\??$ ]]; then
    echo -e "${RED}Invalid.$NC"
    ask_to_select_script
    fi

  echo -en "\n"

  if [[ "$user_input" =~ \? ]]; then
    execute_script "$(get_script_file_name "${user_input/\?/}")" "help"
    ask_to_select_script
  else
    execute_script "$(get_script_file_name "$user_input")"
    fi
}

# Execute script.
#
# @param $1 Script name.
# @param ... Arguments passed to the script.
# @return Script output.
function execute_script() {
  local name=$1
  local args="${*:2}"

  if [ "$LOCAL" == "1" ]; then
    echo -e ""
    bash -c "$URL/$name $args"
  else
    curl -s "$URL/$name" | bash -s "$args"
    fi
}

# Get script file name.
#
# @param $1 Script index or script id.
# @return Script file name.
function get_script_file_name() {
  local name=$1

  if [[ "$name" =~ ^[0-9]+$ ]]; then
    name=$(get_script_id_by_index "$name")
  elif [[ -z "$(index_has_id "$name")" ]]; then
    echo -n ""
    return
    fi

  echo -n "${name/:/_}.sh"
}

# Check if index has script with provided id.
#
# @param $1 Script id.
# @return 1 if script with id exists, 0 otherwise.
function index_has_id() {
  local id=$1
  local out
  out=$(iterate_index "_loop_has_id_check" "_loop_has_id" "$id")
  [[ -n "$out" ]] && echo -n "1" || echo -n ""
}
function _loop_has_id_check() {
  [[ "$1" == "$5" ]] && echo -n "1"
}
function _loop_has_id() {
  echo -n "1"
}

function _loop_pass() {
  echo -n "1"
}
function iterate_index() {
  local callback_check="$1"
  local callback="$2"
  local args="${*:3}"

  while read -r line; do
    _group=$(get_group_from_index_entry "$line")
    [[ -n "$_group" ]] && group="$_group"
    [ -n "$(skip_entry "$line")" ] && continue

    id="$group:$(get_id_from_index_entry "$line")"
    desc="$(get_description_from_index_entry "$line")"

    if [[ $("$callback_check" "$id" "$desc" "$group" "$i" "$args") == "1" ]]; then
      "$callback" "$id" "$desc" "$group" "$i" "$args"
      i=$((i+1))
      fi
  done < "$(get_index_file)"
}

# Get script id by index.
#
# @param $1 Script index.
# @return Script name.
function get_script_id_by_index() {
  local index=$1
  local i=1
  local group
  local _group
  while read -r line; do
    _group=$(get_group_from_index_entry "$line")
    [[ -n "$_group" ]] && group="$_group"
    [ -n "$(skip_entry "$line")" ] && continue

    if [ $i -eq "$index" ]; then
      echo -n "$group:$(echo -n "$line" | grep -oP "(?<=id:)[^|]+" | xargs | tr -d '\n')"
      fi

    i=$((i+1))
  done < "$(get_index_file)"
}

# Get script name by id.
#
# @param $1 Script id.
# @return Script name.
function get_script_name_by_id() {
  local id=$1
  local str
  local group
  local _group
  while read -r line; do
    _group=$(get_group_from_index_entry "$line")
    [[ -n "$_group" ]] && group="$_group"
    [ -n "$(skip_entry "$line")" ] && continue

    str="$group:$(get_id_from_index_entry "$line")"

    if [ "$id" == "$str" ]; then
      get_name_from_index_entry "$line"
      break
      fi
  done < "$(get_index_file)"

  echo ""
}

function get_group_from_index_entry() {
  local entry=$1

  if [[ $entry =~ ^#.* ]]; then
    group=$(sed -E "s/[^a-zA-Z]+//g" <<< "$entry" | tr '[:upper:]' '[:lower:]' | xargs | tr -d '\n')
    echo -n "$group"
  fi

  echo ""
}

function skip_entry() {
  local entry=$1

  # Empty line.
  [ -z "$line" ] && echo "1"

  # Print group header.
  [[ $line =~ ^#.* ]] && echo "1"

  echo ""
}

function match_entry() {
  local id=$1
  local desc=$2
  local match=$3
  if [[ -z "$match" || ( "$id" == *"$match"* || "$desc" == *"$match"* ) ]]; then
    echo -n "1"
  else
    echo -n "0"
    fi
}

function get_id_from_index_entry() {
  local entry=$1
  echo -n "$entry" | grep -oP "(?<=id:)[^|]+" | xargs | tr -d '\n'
}

function get_description_from_index_entry() {
  local entry=$1
  echo -n "$entry" | grep -oP "(?<=description:)[^|]+" | xargs | tr -d '\n'
}

# Return path to index file (if index file does not exists it is downloaded first).
#
# @return string Absolute path to index file.
function get_index_file() {
  if [[ ! -f "$CFG_DIR/index" ]]; then
    fetch "index" > "$CFG_DIR/index"
    # Empty line on the end of the file is needed for proper parsing.
    echo -e "" >> "$CFG_DIR/index"
    fi

  echo "$CFG_DIR/index"
}

function build_entry() {
  local line=$1
  local index=$2
  local group=$3
  local str

  # Print script index.
  echo -n "$index. "

  # Print script identifier.
  echo -n "$BLU$group:"
  str=$(echo -n "$line" | grep -oP "(?<=id:)[^|]+" | xargs | tr -d '\n')
  echo -n "$str"
  str="$group:$str"
  repeat $(($LONGEST_ID-${#str})) " "
  echo -n "$NC"

  # Print script description.
  echo -n "$line" | grep -oP "(?<=description:)[^|]+" | xargs | tr -d '\n'
}

function repeat() {
  local gap=$1
  local str=$2
  while [ $gap -gt 0 ]; do
    echo -n "$str"
    gap=$((gap-1));
  done
}

action=$1

if [[ "$action" == ":refresh" ]]; then
  rm -f "$CFG_DIR/index"
  echo -e "${GRN}Index refreshed.$NC"
  exit 0
  fi
if [[ "$action" == ":url" ]]; then
  ask_for_url
  exit 0
  fi

script_name="$(get_script_file_name "$action")"
if [ -n "$script_name" ]; then
  execute_script "$script_name" "${@:2}"
  exit 0
  fi

get_longest "${@:1}"
print_scripts_list "${@:1}"
ask_to_select_script