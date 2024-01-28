# Wield Node Restart.

## Usage
1. Install necessary Packages.

```
$ sudo apt install python3 python3-pip uvicorn
$ poetry install
```

2. Set dagger password on wield-node-restart.py.
3. Set keyphrase to run restart command.
4. Run this command.

```
$ nohup uvicorn wield-node-restart:app --host=0.0.0.0 --port=4987 &
```

5. Send Post Request with keyphrase.

```
$ curl -X POST -H "accept: application/json" -H "Content-Type: application/json" -d '{"key":"passkey"}' 207.180.205.155:4987/restart   
```