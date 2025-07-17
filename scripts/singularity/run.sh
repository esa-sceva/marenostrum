source /mistral-synth-gen/.venv/bin/activate
echo "Starting vLLM server for Llama-3.1-8B-Instruct..."

WORK_PATH="/gpfs/projects/<project_id>/satcom"

vllm serve  "$WORK_PATH/hf_cache/models/models--meta-llama--Llama-3.1-8B-Instruct/snapshots/0e9e39f249a16976918f6564b8830bc894c89659" --dtype bfloat16 --served-model-name "llama-3-8b" &
SERVER_PID=$!


MAX_WAIT=300  # in seconds
# Wait for the server to be ready using Python, with timeout
echo "Waiting for vLLM server to start (max ${MAX_WAIT}s)..."
SECONDS=0
while ! python -c "import socket; s = socket.socket(); s.settimeout(1); s.connect(('localhost', 8000))" 2>/dev/null; do
  sleep 2
  if [ $SECONDS -ge $MAX_WAIT ]; then
    echo "Timeout: vLLM server did not start within ${MAX_WAIT} seconds."
    kill $SERVER_PID 2>/dev/null
    exit 1
  fi
done
echo "vLLM server is ready!"

export OPENAI_API_KEY="EMPTY"
export OPENAI_BASE_URL="http://localhost:8000/v1/"
export NLTK_DATA=$WORK_PATH/nltk


sauceduchef process $WORK_PATH/single_hop_qa_w_bonus.yaml $WORK_PATH/out/qa
kill $SERVER_PID