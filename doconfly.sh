#! /usr/bin/env bash

set -euo pipefail

config_tinycss2() {
    number_versions=0
}

get_project_name() {
    # GitHub gives org/project_name
    project_name=${1##*/}
}

get_ref_type() {
    # GitHub gives refs/heads/master (for a branch)
    # or refs/tags/v51 (for a tag)
    without_head=${1#*/}
    ref_type=${without_head%/*}
    tag=${without_head#*/}
}

install_doc_requirements() {
    \cd $project_clone
    \python -m venv .venv
    \git checkout master
    echo $PWD
    .venv/bin/pip install .[doc]
}

sphinx_build() {
    \cd $project_clone
    .venv/bin/sphinx-build docs $1
}

generate_doc() {
    \sed -i "s,version = .*,version = $2," docs/conf.py
    install_doc_requirements
    sphinx_build $1
    \git checkout docs/conf.py
}

mai() {
    \cd $project_clone
    \git pull origin master
    if [[ $ref_type == "heads" ]]
    then
        doc_directory="$project_path/latest"
        generate_doc $doc_directory "'latest'"
    elif [[ $ref_type == "tags" ]]
    then
        doc_directory="$project_path/$tag"
        generate_doc $doc_directory \'$tag\'
        doc_directory="$project_path/stable"
        generate_doc $doc_directory "'stable'"
    else
        echo "This is not a push on master nor a tag"
        exit 1
    fi
}

get_project_name $1
get_ref_type $2

project_path="/home/lameche/Projets/$project_name"
project_clone="$project_path"
#project_path="/var/www/$project_name"
#project_clone="$project_path/$project_name"

config_$project_name
main
