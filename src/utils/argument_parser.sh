#!/usr/bin/env bash
set -euo pipefail

key_exists() {
  eval '[ ${'$2'[$1]+key_exists} ]'
}

is_option() {
  if [[ $1 == --* ]] || [[ $1 == -* ]]; then
    return 0
  fi

  return 1
}


parse_arguments() {
  command=''
  subcommand=''
  declare -g -A args=()

  #get function agruments
  #local command_arguments=("${!1}")
  #local command_options=("${!2}")
  #local raw_arguments=("${!3}")

  local raw_arguments=("${@}")

  #get definied options
  local opt_required=()
  local opt_map opt_type_map
  declare -A opt_map=()
  declare -A opt_type_map=()

  for opt in "${!command_options[@]}"; do
    local full_opt_name=''
    local opt_names=( $(echo ${opt} | grep -o '[a-z0-9\-]*') )

    if [[ ${#opt_names[@]} == 2 ]]; then
      full_opt_name="--${opt_names[1]}"
      opt_map["-${opt_names[0]}"]=${full_opt_name}
    elif [[ ${#opt_names[@]} == 1 ]]; then
      full_opt_name="--${opt_names[0]}"
      opt_map[${full_opt_name}]=${full_opt_name}
    else
      echo "Error wrong defined options"
      exit 1
    fi

    local opt_type=$(echo ${opt} | grep -o '[:?+]')

    if [[ ${opt_type} == "" ]]; then
      echo "Error no option type given for ${full_opt_name}"
      exit 1
    elif [[ ${opt_type} == ":" ]]; then
      opt_required+=(${full_opt_name})
    fi

    opt_type_map[${full_opt_name}]=${opt_type}
  done


  #iterate over the raw argumgents
  local number_commands=${#commands[@]}
  local number_command_arguments=${#command_arguments[@]}
  local start_options=$((number_commands + number_command_arguments))
  local no_raw_arguments=${#raw_arguments[@]}
  local arg=''
  local current_arg=''
  local counter=0
  local req_param_name=''

  while [[ ${counter} -lt ${no_raw_arguments} ]]; do
    arg=${raw_arguments[${counter}]}

    if [[ ${counter} -lt ${number_commands} ]] && !(is_option ${arg}); then
      if [[ ${arg} != ${commands[$counter]} ]]; then
        echo "Unknown command ${arg} called"
        exit 1
      fi
    elif [[ ${counter} -lt ${start_options} ]] && [[ ${counter} -ge ${number_commands} ]] && !(is_option ${arg}); then
      req_param_name=${command_arguments[$((counter - number_commands))]}
      args[${req_param_name}]=${arg}
    elif [[ ${counter} -ge ${start_options} ]] && is_option ${arg}; then
      if (key_exists ${arg} opt_map); then
        arg=${opt_map[${arg}]}
      else
        echo "Invalid option ${arg}"
        exit 1
      fi

      current_arg=${arg}
      local is_multiple_opt=false

      if [[ ${opt_type_map[$current_arg]} == '+' ]]; then
        is_multiple_opt=true
      fi

      if ${is_multiple_opt} && !(key_exists "${current_arg},#" args); then
        args["${current_arg},#"]=0
      elif !(${is_multiple_opt}) && !(key_exists ${current_arg} args); then
        args[${current_arg}]=''
      elif (key_exists ${current_arg} args) && [[ ${is_multiple_opt} ]]; then
        echo "Error ${current_arg} can't be multiple definied"
        exit 1
      fi

      local next=$((counter + 1))

      if [[ ${next} -lt ${no_raw_arguments} ]]; then
        arg=${raw_arguments[${next}]}

        if [[ ${arg} != "" ]] && !(is_option ${arg}); then
          if ${is_multiple_opt}; then
            local no_opt_args=${args["${current_arg},#"]}
            args["${current_arg},${no_opt_args}"]="${arg}"
            args["${current_arg},#"]=$((no_opt_args+1))
          else
            args[${current_arg}]="${arg}"
          fi

          counter=${next}
        fi
      fi
    else
      if [[ ${counter} == 0 ]]; then
        echo "invalide command ${arg}"
      elif [[ ${counter} -le ${number_command_arguments} ]]; then
        req_param_name=${command_arguments[$((counter - 1))]}
        echo "missing required parameter ${req_param_name}"
      elif [[ ${counter} -gt ${number_command_arguments} ]]; then
        echo "wrong option ${arg}"
      fi

      exit 1
    fi

    counter=$((counter + 1))
  done

  #Check for missing required vars
  for req_opt in "${opt_required[@]}"; do
    if !(key_exists ${req_opt} args); then
      echo "Option ${req_opt} is required"
      exit 1
    fi
  done
}

#test
commands=(
  'com'
  'subcommand'
  'subsubcom'
)

command_arguments=(
  "version"
  "name"
)

declare -g -A command_options=(
  ["single-required:"]="Desc 1"
  ["single-optional?"]="Desc 2"
  ["single-repeatable+"]="Desc 3"
  ["r|required-opt:"]="Desc 4"
  ["o|optional-opt?"]="Desc 5"
  ["p|repeatable-opt+"]="Desc 6"
)

parse_arguments ${@}

echo "---- Args -----"

for key in "${!args[@]}"; do
  k=$(echo ${key} | grep -o '[a-z0-9\-]*')


  if [[ $(echo ${key} | grep -o '[\#]*') == "#" ]] && (key_exists "${k},#" args); then
    echo "|> ${k}"

    i=0
    while [[ ${i} -lt ${args["${k},#"]} ]] ; do
      echo "|==> ${args[${k},${i}]}"
      i=$[$i+1]
    done
  elif [[ $(echo ${key} | grep -o '[\,]*') == "" ]]; then
    echo "|> ${k}"
    echo "|==> ${args[${k}]}"
  fi
done