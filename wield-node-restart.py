# https://qiita.com/cloud-solution/items/b7b05ce0f55dbfbeb36a

import fastapi
import subprocess
import traceback
import logging
import pydantic
import time

fmt = "%(asctime)s %(levelname)s %(name)s :%(message)s"
logging.basicConfig(level=logging.INFO, format=fmt)
logger = logging.getLogger(__name__)

app = fastapi.FastAPI(docs_url=None, redoc_url=None)

dagger_password = "\n"
restart_password = ""

WIELD_PATH = "/home/dagger/wield"
KEYGEN_PATH = "/home/dagger/shdw-keygen"
ID_PATH = "/home/dagger/id.json"
WIELD_URL = "https://shdw-drive.genesysgo.net/4xdLyZZJzL883AbiZvgyWKf2q55gcZiMgMkDNQMnyFJC/wield-latest"
KEYGEN_URL = "https://shdw-drive.genesysgo.net/4xdLyZZJzL883AbiZvgyWKf2q55gcZiMgMkDNQMnyFJC/shdw-keygen-latest"
SERVICE_NAME = "wield.service"
CONFIG_FILE = "/home/dagger/config.toml"
TRUSTED_NODES = [
    "184.154.98.116:2030",
    "184.154.98.117:2030",
    "184.154.98.118:2030",
    "184.154.98.119:2030",
    "184.154.98.120:2030",
]

SAME_VERSION_LOOP_LIMIT = 100


class SameVersionError(Exception):
    pass


def process_run(_command, check=True):
    logger.info('subprocess.run: ' + _command)
    ret = subprocess.run(_command, shell=True, input=dagger_password,
                         capture_output=True, text=True, check=check)
    return ret


class KeyPhrase(pydantic.BaseModel):
    key: str


def create_config(trusted_nodes):
    # Join the array elements with comma and space
    joined_nodes = ', '.join(f'"{node}"' for node in trusted_nodes)
    # Create the configuration string
    config_content = f"""trusted_nodes = [{joined_nodes}]
dagger = "JoinAndRetrieve"

[node_config]
socket = 2030
keypair_file = "id.json"

[storage]
peers_db = "dbs/peers.db"
"""
    # Write the configuration to a file
    with open('/home/dagger/config.toml', 'w') as config_file:
        config_file.write(config_content)


def get_current_version():
    try:
        output = subprocess.check_output(
            ['/home/dagger/wield', '--version'], stderr=subprocess.STDOUT)
        # Python3ではoutputはbytes型なので、decodeして文字列に変換
        output = output.decode('utf-8')
        return output.split()[1]
    except:
        return 0


def download_latest_version():
    process_run(f'sudo -S systemctl stop {SERVICE_NAME}')
    process_run(f'rm "{WIELD_PATH}"', check=False)
    process_run(f'wget -O "{WIELD_PATH}" "{WIELD_URL}"')
    process_run(f'chmod +x {WIELD_PATH}')
    updated_version = get_current_version()
    return updated_version


def get_node_status():
    return process_run(f'sudo -S systemctl is-active {SERVICE_NAME}', check=False).stdout


def get_node_id():
    return process_run(f'{KEYGEN_PATH} pubkey {ID_PATH}', check=False).stdout


@app.get("/")
def root():
    return {"message": "Hello World"}


@app.post("/restart")
def restart(key: KeyPhrase):
    if key.key != restart_password:
        return {
            "message": "Invalid key.",
            "status": "Error",
            "node_id": ""
        }
    node_id = get_node_id()
    node_status = get_node_status()
    try:
        current_version = get_current_version()
        loop_count = 0
        while (current_version == download_latest_version() and loop_count < SAME_VERSION_LOOP_LIMIT):
            time.sleep(1)
            logger.info(
                f"Same version. Loop count: {loop_count}, current version: {current_version}, Limit: {SAME_VERSION_LOOP_LIMIT}")
            loop_count += 1
        process_run(f'rm /home/dagger/config.toml')
        create_config(TRUSTED_NODES)
        time.sleep(2)
        process_run(f'sudo -S systemctl start {SERVICE_NAME}')
        updated_version = get_current_version()
        node_status = get_node_status()
        if updated_version == current_version:
            raise SameVersionError()
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
    except SameVersionError:
        updated_version = get_current_version()
        node_status = get_node_status()
        node_id = get_node_id()
        return {
            "message": f"{node_id}: Same version. Update Faillure {updated_version} -> {updated_version}. status: {node_status}",
            "status": node_status,
            "node_id": node_id
        }
    except Exception as e:
        node_status = get_node_status()
        node_id = get_node_id()
        return {
            "message": f"{node_id}: Restart Error occurred., status: {node_status}" + str(e),
            "status": node_status,
            "node_id": node_id
        }
    node_status = get_node_status()
    node_id = get_node_id()
    return {
        "message": f"Node {node_id} updated (v{current_version} -> v{updated_version}) restarted (current status: {node_status})",
        "status": node_status,
        "node_id": node_id
    }
