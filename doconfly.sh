#! /usr/bin/env bash

# $1 GITHUB_REPOSITORY
# $2 GITHUB_REF
# $3 documentation path
# $4 documentation base url

set -euo pipefail

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

get_stable_version() {
    \cd $project_clone
    \echo `git tag | sed '/-/!{s/$/\.0/}' | sort -rV | sed 's/\.0$//' | head -n 1`
    \cd - > /dev/null
}

install_doc_requirements() {
    \cd $project_clone
    \python3 -m venv .venv
    if [[ $1 == "'stable'" ]]
    then
        \git checkout `get_stable_version`
    elif [[ $1 == "'latest'" ]]
    then
        \git checkout origin/master
    else
        \git checkout "$tag"
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
    js_versions=""
    for doc in $(echo "latest stable $versions")
    do
        if ! [[ $doc == "$project_name" || $doc == "js_versions_list.js" ]]
        then
            js_versions=$js_versions" <li><a href=\"$documentation_base_url/$project_name/$doc\">$doc"
            if [[ $doc == "latest" ]]
            then
                js_versions=$js_versions" (master)"
            elif [[ $doc == "stable" ]]
            then
                js_versions=$js_versions" (`get_stable_version | tr -d '\n'`)"
            fi
            js_versions=$js_versions"</a></li>"
        fi
    done
    content="
        window.onload = function(){
            document.getElementsByClassName('wy-nav-side')[0].innerHTML +=
            '<ul id="js_versions"> \
              $js_versions \
            </ul>';
            document.getElementsByTagName('head')[0].innerHTML +=
            '<link rel="stylesheet" href="https://www.courtbouillon.org/static/versions.css" type="text/css" />';
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
    versions=""
    for tag in $(git tag --format='%(refname)' | sed '/-/!{s/$/\.0/}' | sort -rV | sed 's/\.0$//')
    do
        version=${tag##*/}
        if [[ "$versions" == "" || "$version" != *@(a|b|rc)* && "${version##*.}" -ge "${last_version##*.}" ]]
        then
            if [ ! -d "$documentation/$project_name/$version" ]
            then
                generate_doc "$project_path/$version" $version
                versions="$versions $version"
                versions_count=`echo "$versions" | wc -w`
                if [[ versions_count -ge 5 ]]
                then
                    break
                fi
            fi
        fi
        if [[ $version == *@(a|b|rc)* ]]
        then
            last_version=0
        else
            last_version=$version
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
    \git fetch
    \git reset --hard origin/master
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

documentation=$3
documentation_base_url=$4
github_repository=$1
project_path="$documentation/$project_name"
project_clone="$project_path/$project_name"

make_directory $project_name

main
