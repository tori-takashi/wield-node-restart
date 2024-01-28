# https://qiita.com/cloud-solution/items/b7b05ce0f55dbfbeb36a

import fastapi
import subprocess
import traceback
import logging
import pydantic

fmt = "%(asctime)s %(levelname)s %(name)s :%(message)s"
logging.basicConfig(level=logging.INFO, format=fmt)
logger = logging.getLogger(__name__)

app = fastapi.FastAPI(docs_url=None, redoc_url=None)

dagger_password = "\n"
restart_password = "passkey"


def process_run(_command):
    logger.info('subprocess.run: ' + _command)
    ret = subprocess.run(_command, shell=True, input=dagger_password,
                         capture_output=True, text=True, check=True)
    return ret


class KeyPhrase(pydantic.BaseModel):
    key: str


@app.post("/restart")
def restart(key: KeyPhrase):
    if key.key != restart_password:
        return {
            "message": "Invalid key.",
            "status": "Error",
            "node_id": ""
        }
    try:
        get_node_id = process_run('/home/dagger/shdw-keygen pubkey id.json')
        process_run('sudo -S systemctl stop wield.service')
        process_run('sudo -S systemctl start wield.service')
        get_node_status = process_run(
            'sudo -S systemctl is-active wield.service')
    except subprocess.CalledProcessError as cpe:
        logger.error('subprocess err. ' + cpe.stderr + '\n' +
                     'returncode: ' + str(cpe.returncode) + '\n' +
                     'cmd: ' + cpe.cmd)
        t = list(traceback.TracebackException.from_exception(cpe).format())
        return {
            "message": t,
            "status": "Error",
            "node_id": ""
        }
    except Exception as e:
        traceback.format_exc()
        return {
            "message": "Restart Error occurred.",
            "status": "Error",
            "node_id": ""
        }
    return {
        "message": f"Node {get_node_id.stdout} restarted (current status: {get_node_status.stdout})",
        "status": get_node_status.stdout,
        "node_id": get_node_id.stdout
    }
