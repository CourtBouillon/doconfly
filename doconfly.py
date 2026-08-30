from os import chdir, getenv
from pathlib import Path
from subprocess import PIPE, run

ROOT = Path(getenv('DOCONFLY_DOC_ROOT'))
JS = """
window.onload = function(){
  document.querySelector('.wy-nav-side, .sidebar-sticky').innerHTML +=
  '<ul id="versions">%s</ul>';
  current_version = window.location.href.split('/').reverse()[1];
  document.querySelector(
    `#versions a[href$="${current_version}"]`
  ).parentElement.classList.add('current');
}
"""


def git(*args):
    stdout = run(('git', *args), stdout=PIPE, check=True).stdout
    return stdout.decode().strip().split('\n')


def generate_doc(version_path, version, label):
    configuration = Path('docs/conf.py')
    git('restore', configuration)
    git('reset', '--hard', version)
    run(('.venv/bin/pip', 'install', '.[doc]'), check=True)
    with configuration.open('a') as fd:
        fd.write(f'\nversion = "{label}"\nhtml_js_files = ["../../versions_list.js"]')
    run(('.venv/bin/sphinx-build', 'docs', version_path), check=True)


def app(environ, start_response):
    url_path = environ['PATH_INFO'].strip('/')
    group, repository, _, _, ref_name = url_path.split('/')
    repository = repository.lower()

    # Create documentation folder.
    doc_path = ROOT / repository
    if not doc_path.exists():
        doc_path.mkdir()

    # Create repository folder.
    chdir(doc_path)
    repository_path = doc_path / repository
    if not repository_path.exists():
        git('clone', f'https://github.com/{group}/{repository}.git')

    # Fetch changes and create virtual environment.
    chdir(repository_path)
    git('fetch')
    venv = Path('.venv')
    if not venv.exists():
        run(('python3', '-m', 'venv', venv), check=True)
    run(('.venv/bin/pip', 'install', '--upgrade', 'pip'), check=True)

    # Create JavaScript file adding latest minor versions in menu.
    last_minor = None
    versions = 0
    html = ''
    stable_version = None
    for version in ('latest', *git('tag', '--sort=-v:refname')):
        minor = version.split('.')[1] if '.' in version else version
        if minor == last_minor:
            continue
        versions += 1
        stable = not stable_version and not any(
            string in version for string in ('latest', 'a', 'b', 'rc'))
        page = 'stable' if stable else version
        extra = ' (main)' if version == 'latest' else ' (stable)' if stable else ''
        html += f'<li><a href="/{repository}/{page}">{version}{extra}</a></li>'
        version_path = doc_path / version
        if not version_path.exists() or (version == 'latest' and ref_name == 'main'):
            generate_doc(version_path, ref_name, version)
        if stable:
            stable_version = version
            stable_link = doc_path / 'stable'
            if stable_link.exists():
                stable_link.unlink()
            stable_link.symlink_to(version_path)
        if versions == 5:
            break
        last_minor = minor
    Path(doc_path / 'versions_list.js').write_text(JS % html)

    # Send HTTP response.
    start_response('200 OK', [('Content-Type', 'text/plain')])
    return [b'OK']
