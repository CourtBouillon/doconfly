from os import getenv
from subprocess import run

ROOT = getenv('DOCONFLY_DOC_ROOT')
SCRIPT = getenv('DOCONFLY_SCRIPT')

def app(environ, start_response):
    path = environ['PATH_INFO'].strip('/')
    group, repository, refs, ref_type, ref_name = path.split('/')
    args = (SCRIPT, f'{group}/{repository}', f'{refs}/{ref_type}/{ref_name}', ROOT)
    run(args, check=True)
    start_response('200 OK', [('Content-Type', 'text/plain')])
    return [b'OK']
