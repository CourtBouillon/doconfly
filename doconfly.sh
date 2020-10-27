#! /usr/bin/env bash

set -euo pipefail

avoid_versions_tinycss2() {
    avoided_versions="v1.0.0 v1.0.1"
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
    .venv/bin/pip install .[doc]
}

sphinx_build() {
    \cd $project_clone
    .venv/bin/sphinx-build docs $1
}

create_js_file() {
    \cd $project_path
    versions=""
    for doc in *
    do
        if ! [[ $doc == "$project_name" || $doc == "versions_list.js" ]]
        then
            versions=$versions" <li><a href=\"$doc\">$doc</a></li>"
        fi
    done
    content="
        window.onload = function(){
            document.getElementsByClassName('wy-nav-side')[0].innerHTML +=
            '<ul> \
              $versions \
              </ul>';
        }
    "
    \echo "$content" > versions_list.js
}

generate_doc() {
    \cd $project_clone
    \sed -i "s,version = .*,version = $2," docs/conf.py
    \echo "html_js_files = ['../../versions_list.js']" >> docs/conf.py
    \echo "html_css_files = ['https://www.courtbouillon.org/static/docs.css']" >> docs/conf.py
    install_doc_requirements
    sphinx_build $1
    \git checkout docs/conf.py
    create_js_file
}

main() {
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
        \echo "This is not a push on master nor a tag"
        \exit 1
    fi
}

get_project_name $1
get_ref_type $2

project_path="/home/lameche/Projets/$project_name"
#project_path="/var/www/$project_name"
project_clone="$project_path/$project_name"

avoid_versions_$project_name
main
