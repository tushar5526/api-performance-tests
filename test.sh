#!/bin/bash

set -e

[ -d "./results" ] && rm -rf results
mkdir -p results

npm install

poetry --version || (curl -sSL https://install.python-poetry.org | python3 -)
poetry update

[ ! -d "./venv" ] &&
  python -m venv .venv &&
  source .venv/bin/activate &&
  pip install --upgrade pip &&
  pip install cython &&
  pip install wheel &&
  poetry export -f requirements.txt --output requirements.txt &&
  pip install -r requirements.txt && rm requirements.txt;

for TYPE in json plaintext; do
  for TARGET in starlite starlette fastapi sanic blacksheep; do
    (cd "$TARGET" && gunicorn main:app -k uvicorn.workers.UvicornWorker -c gunicorn.config.py) &
    printf "\n\nwaiting for service to become available\n\n"
    sleep 5
    printf "\n\ninitializing test sequence for $TARGET-$TYPE\n\n"
    endpoints=(
      "async-${TYPE}-no-params"
      "sync-${TYPE}-no-params"
      "async-${TYPE}/abc"
      "sync-${TYPE}/abc"
      "async-${TYPE}-query-param?first=abc"
      "sync-${TYPE}-query-param?first=abc"
      "async-${TYPE}-mixed-params/def?first=abc"
      "sync-${TYPE}-mixed-params/def?first=abc"
    )
    for i in {1..2}; do
      for ENDPOINT in "${endpoints[@]}"; do
        name=$(echo "${TARGET}-${ENDPOINT}-${i}.json" | sed 's/^\///;s/\//-/g')
        npx -y autocannon -j "http://0.0.0.0:8001/$ENDPOINT" >>"./results/$name"
      done
    done
    printf "\n\ntest sequence finished\n\nterminating all running python instances\n\n"
    pkill python
  done
done
[ -f "./result-json.png" ] && rm "./result-json.png"
[ -f "./result-plaintext.png" ] && rm "./result-plaintext.png"
python analysis/analyzer.py
printf "\n\nTests Finished Successfully!"
deactivate
