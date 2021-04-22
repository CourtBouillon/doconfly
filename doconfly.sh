#! /usr/bin/env bash

# $1 GITHUB_REPOSITORY
# $2 GITHUB_REF
# $3 documentation path
# $4 documentation base url

set -euo pipefail

avoid_versions_tinycss2() {
    avoided_versions="v0.1 v0.2 v0.3 v0.4 v0.5 v0.6.0 v0.6.1"
}

avoid_versions_cssselect2() {
    avoided_versions="0.1 0.2.0 0.2.1 0.2.2"
}

avoid_versions_pydyf() {
    avoided_versions=""
}

avoid_versions_weasyprint() {
    avoided_versions="v47 v46 v45 v44 v43rc2 v43rc1 v43 v0.9 v0.8 v0.7.1 v0.7
    v0.6.1 v0.6 v0.5 v0.42.2 v0.42.1 v0.42 v0.41 v0.40 v0.4 v0.39 v0.38 v0.37
    v0.36 v0.35 v0.34 v0.33 v0.32 v0.31 v0.3.1 v0.30 v0.3 v0.29 v0.28 v0.27
    v0.26 v0.25 v0.24 v0.23 v0.22 v0.2.2 v0.21 v0.2.1 v0.20.2 v0.20.1 v0.20
    v0.2 v0.19.2 v0.19.1 v0.19 v0.18 v0.17.1 v0.17 v0.16 v0.15 v0.14 v0.13
    v0.12 v0.11 v0.10 v0.1"
}

get_project_name() {
    # GitHub gives org/project_name
    project_name=${1##*/}
    project_name=${project_name,,}
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
    \python3 -m venv .venv
    if ! [[ $1 == "'stable'" || $1 == "'latest'" ]]
    then
        \git checkout $1
    else
        \git checkout master
    fi
    .venv/bin/pip install --upgrade pip setuptools
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
            versions=$versions" <li><a href=\"$documentation_base_url/$project_name/$doc\">$doc</a></li>"
        fi
    done
    content="
        window.onload = function(){
            document.getElementsByClassName('wy-nav-side')[0].innerHTML +=
            '<ul id="versions"> \
              $versions \
              </ul>';
            current_version = window.location.href.split('/').reverse()[1];
            document.querySelector(\`#versions a[href\$=\"\${current_version}\"]\`).parentElement.classList.add('current');
        }
    "
    \echo "$content" > versions_list.js
}

generate_doc() {
    \cd $project_clone
    \git checkout docs/conf.py
    install_doc_requirements $2
    \sed -i "s,version = .*,version = \"$2\"," docs/conf.py
    \echo "html_js_files = ['../../versions_list.js']" >> docs/conf.py
    sphinx_build $1
    create_js_file
}

build_doc_versions() {
    \cd $project_clone
    for tag in $(git for-each-ref refs/tags --format='%(refname)')
    do
        version=${tag##*/}
        if [[ ! $avoided_versions =~ "$version" ]]
        then
            if [ ! -d "$documentation/$project_name/$version" ]
            then
                doc_directory="$project_path/$version"
                generate_doc $doc_directory $version
            fi
        fi
    done
}

make_directory() {
    if [ ! -d "$documentation/$project_name" ]
    then
        \cd "$documentation"
        \mkdir "$project_name"
        \cd "$project_name"
        \git clone "git@github.com:$github_repository.git" "$project_name"
    fi
}

main() {
    \cd $project_clone
    \git checkout docs/conf.py
    \git pull origin master -t
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
    build_doc_versions
}

get_project_name $1
get_ref_type $2
avoid_versions_$project_name

documentation=$3
documentation_base_url=$4
github_repository=$1
project_path="$documentation/$project_name"
project_clone="$project_path/$project_name"

make_directory $project_name

main
