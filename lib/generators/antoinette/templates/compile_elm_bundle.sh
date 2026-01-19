#!/bin/bash

# Usage:
#   bin/compile_elm_bundle.sh development elm.js CaseBuilder.elm SearchForm.elm
#   bin/compile_elm_bundle.sh production elm.js CaseBuilder.elm SearchForm.elm

set -e
set -o pipefail # if the process fails, stop

env=$1
output=$2
shift 2
elm_files="$@"

if [ "$env" = "production" ]; then
  temp_js="elm_temp.js"

  echo "Compiling Elm (optimized)..."
  ./bin/elm make --optimize --output=$temp_js $elm_files

  echo "Initial size: $(cat $temp_js | wc -c) bytes"

  ./node_modules/.bin/uglifyjs $temp_js --compress 'pure_funcs=["F2","F3","F4","F5","F6","F7","F8","F9","A2","A3","A4","A5","A6","A7","A8","A9"],pure_getters,keep_fargs=false,unsafe_comps,unsafe' | ./node_modules/.bin/uglifyjs --mangle --output $output

  echo "Minified size: $(cat $output | wc -c) bytes"
  echo "Gzipped size: $(cat $output | gzip -c | wc -c) bytes"

  rm $temp_js
else
  echo "Compiling Elm (development)..."
  ./bin/elm make --output=$output $elm_files
fi
