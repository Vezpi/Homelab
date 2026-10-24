#!/bin/sh

#----------------------------------------------------------------------------------------------------
#~ Name         : Script name
#~ Description  : Skel script
#~ Author       : Etienne Girault <etienne.girault@gmail.com>
#~
#~ Usage        : [-h] [-D] [-V]
#~
#~ Options      : -h, --help ; Print help
#~ Options      : -V, --version ; Print version
#~ Options      : -D, --debug ; Debug

#----------------------------------------------------------------------------------------------------
# Variables
#----------------------------------------------------------------------------------------------------
script_name="$(grep '^#~ Name' "$0" | sed 's/^.*: //')"
script_version="$(grep '^#~ v' "$0" | tail -1 | sed -e 's/^#~ //' -e 's/ *\-.*$//')"

FOLDERS="Documents Ebook photo video download"

#----------------------------------------------------------------------------------------------------
# Functions
#----------------------------------------------------------------------------------------------------
print_script_name_version() { echo "$script_name $script_version" && sed -n '/^#~ Version/,$p' "$0" | grep '^#~' | sed 's/^#~ //'; }
print_script_description() { grep '^#~ Description' "$0" | sed 's/^.*: //'; }
print_script_usage() { grep '^#~ Usage' "$0" | sed -e 's/^.*: //' -e '1 s/^/Usage: '"${0##*/}"' /' -e '2,$ s/^/'"$(printf '%*s' "$(echo "Usage: ${0##*/}" | wc -c)")"'/'; }
print_script_options() { echo "Options" &&  grep '^#~ Options' "$0" | sed -e 's/^.*://' -e 's/^ --/     --/' | column -ts \;; }
print_script_help() { echo "$script_name $script_version"  && print_script_description && print_script_usage && print_script_options; }

folder_is_empty() {
  if [ -n "$(ls $1)" ]; then
    return 1
  fi
  return 0
}

# Signals
trap 'exit 1' INT TERM

#----------------------------------------------------------------------------------------------------
# Options
#----------------------------------------------------------------------------------------------------
while getopts ":-:hVD" OPTION; do
  case $OPTION in
    h)  print_script_help; exit;;
    V)  print_script_name_version; exit;;
    D)  set -x;;
    :)  ;;
    -)  case $OPTARG in
          help) print_script_help; exit;;
          version)  print_script_name_version; exit;;
          debug)  set -x;;
        esac ;;
    *)  ;;
  esac
done
shift $((OPTIND-1))

#----------------------------------------------------------------------------------------------------
# Start
#----------------------------------------------------------------------------------------------------

for folder in $FOLDERS; do
  if folder_is_empty /mnt/data/$folder; then
    exit 1
  fi
done

#----------------------------------------------------------------------------------------------------
# End
#----------------------------------------------------------------------------------------------------

#~ Version changelog
#~ v0.1     - Script creation



