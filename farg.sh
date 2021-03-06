#!/usr/bin/env bash
# shellcheck disable=SC2016

# FARG - Removes unseeable and ghost alpha from PNG images.
# Copyright 2016 Daemon Lee Schmidt

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Flags
OPTIND=1
RMUNSEEABLEALPHA=false
GHOSTOPTS=0

# GHOSTOPTS Explained
# 1 = Optimize - Enable a shitton of wacky calls to optipng because why not.
# 2 = Ghostpass - Passes the name of the file containing the ghost data
#                 to be dealt with by a different piece of software.
# 3 = Ghostbust - Removes ghost data in a simple way.

# Variables
IMAGE=""
OPTILEVEL="2"

print_usage() {
  echo "Usage: $0 [-h -g -r -o -p -e] -i <image>"
  echo "See 'man farg' for more information."
}

while getopts ":hi:grope:" opt; do
  case "$opt" in
    h)
      print_usage
      exit 0
      ;;
    i)
      IMAGE=$OPTARG
      ;;
    g)
      GHOSTOPTS=3
      ;;
    r)
      RMUNSEEABLEALPHA=true
      ;;
    o)
      GHOSTOPTS=1
      ;;
    p)
      GHOSTOPTS=2
      ;;
    e)
      OPTILEVEL=$OPTARG
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Missing argument for -$OPTARG!" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$IMAGE" ]]; then
  print_usage
  exit 1
fi

if [[ "$GHOSTOPTS" == 0 ]]; then
  echo "You must specify one of -g, -o, or -p."
  echo "See 'man farg' for more information."
  exit 1
fi

if test "$(identify -format %A "$IMAGE")" == True; then
  RESULTSCACHE=$(convert "$IMAGE" -verbose info:)

  ALPHAMIN=$(echo "$RESULTSCACHE" | grep -m1 -A1 Alpha: | sed -e :a -e '$q;N;1,$D;ba' | sed -e 's/([^()]*)//g;s/[^0-9]*//g')

  if (($(bc <<< "$ALPHAMIN==255"))); then
    case "$GHOSTOPTS" in
      1)
        optipng -o"$OPTILEVEL" -strip all "$IMAGE"
        ;;
      2)
        echo "$IMAGE"
        ;;
      3)
        mogrify -alpha off "$IMAGE"
        ;;
    esac

  else
    ALPHAMEAN=$(echo "$RESULTSCACHE" | grep -m1 -A3 Alpha: | sed -e :a -e '$q;N;1,$D;ba' | sed -r 's/.*\(|\)//g')
    if (($(bc <<< "$ALPHAMEAN>0.999500"))); then
      if "$RMUNSEEABLEALPHA"; then
        mogrify -flatten -alpha off "$IMAGE"
        if [ "$GHOSTOPTS" = "1" ]; then
          optipng -o"$OPTILEVEL" -strip all "$IMAGE"
        elif [ "$GHOSTOPTS" = "2" ]; then
          echo "$IMAGE"
        fi
      fi
    fi
  fi
elif [ "$GHOSTOPTS" = "1" ]; then
  optipng -o"$OPTILEVEL" -strip all "$IMAGE"
else
  echo "No alpha channel(s) present, and -o not specified."
  echo "Exiting as there is nothing to do."
  exit 0
fi
