from os import getenv
from pathlib import Path
from subprocess import run

ROOT = Path(getenv('DOCONFLY_DOC_ROOT'))
SCRIPT = Path(getenv('DOCONFLY_SCRIPT'))

def app(environ, start_response):
    url_path = environ['PATH_INFO'].strip('/')
    group, repository, refs, ref_type, ref_name = url_path.split('/')

    # Create documentation folder and repository clone.
    doc_path = ROOT / group / repository
    if not doc_path.exists():
        doc_path.mkdir()
        repository_path = doc_path / repository
        if not repository_path.exists():
            args = (
                'git', 'clone', f'https://github.com:{group}/{repository}.git',
                repository_path)
            run(args, check=True)

    args = (SCRIPT, f'{group}/{repository}', f'{refs}/{ref_type}/{ref_name}', ROOT)
    run(args, check=True)
    start_response('200 OK', [('Content-Type', 'text/plain')])
    return [b'OK']
