#!/bin/bash
# Run benchmarks and prepare local visualisation assets.

set -euo pipefail

JAVA_OPTS=(
  --add-opens=java.base/java.lang=ALL-UNNAMED
  --add-opens=java.base/java.lang.reflect=ALL-UNNAMED
  --add-opens=java.base/java.io=ALL-UNNAMED
  --add-opens=java.base/java.nio=ALL-UNNAMED
  --add-opens=java.base/sun.nio.ch=ALL-UNNAMED
  --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED
  --add-exports=java.base/sun.nio.ch=ALL-UNNAMED
  --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED
)

REPORTS_DIR="reports"
RUN_STAMP=$(date -u +%Y%m%d-%H%M%SZ)
RUN_LABEL=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
OUTPUT_DIR="${REPORTS_DIR}/${RUN_STAMP}"
RESULT_JSON="${OUTPUT_DIR}/results.json"
RESULT_LOG="${OUTPUT_DIR}/benchmark-output.log"
mkdir -p "${OUTPUT_DIR}"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <data_size> <payload_lines>" >&2
  echo "  data_size must be one of: 1, 10, 100, 1000, 10000" >&2
  echo "  payload_lines must be one of: 1, 10, 100, 1000" >&2
  exit 1
fi

DATA_SIZE_ARG=$1
PAYLOAD_LINES=$2

if ! [[ "${DATA_SIZE_ARG}" =~ ^[0-9]+$ ]]; then
  echo "Data size must be a positive integer (received: ${DATA_SIZE_ARG})." >&2
  exit 1
fi

if ! [[ "${PAYLOAD_LINES}" =~ ^[0-9]+$ ]]; then
  echo "Payload must be a positive integer representing the number of lines (received: ${PAYLOAD_LINES})." >&2
  exit 1
fi

if (( DATA_SIZE_ARG <= 0 )); then
  echo "Data size must be greater than zero (received: ${DATA_SIZE_ARG})." >&2
  exit 1
fi

if (( PAYLOAD_LINES <= 0 )); then
  echo "Payload line count must be greater than zero (received: ${PAYLOAD_LINES})." >&2
  exit 1
fi

VALUE_PROFILE_ARG="LINES_${PAYLOAD_LINES}"

DEFAULT_WARMUP_ITER=${WARMUP_ITER:-0}
DEFAULT_MEAS_ITER=${MEAS_ITER:-1}
DEFAULT_FORKS=${FORKS:-1}
JMH_ARGS=${JMH_ARGS:-}

echo "Cleaning previous artifacts..."
rm -f benchmark-summary.html

echo "Building project..."
mvn clean package -q

echo "Running benchmarks..."
if [[ -z "${JMH_ARGS}" ]]; then
  JMH_ARGS="-wi ${DEFAULT_WARMUP_ITER} -i ${DEFAULT_MEAS_ITER} -f ${DEFAULT_FORKS} -p dataSize=${DATA_SIZE_ARG} -p valueProfileSpec=${VALUE_PROFILE_ARG}"
  echo "Using JMH args: ${JMH_ARGS}"
else
  echo "Using custom JMH args: ${JMH_ARGS}"
fi
# shellcheck disable=SC2086
java "${JAVA_OPTS[@]}" -jar target/benchmarks.jar -rf json -rff "${RESULT_JSON}" ${JMH_ARGS} | tee "${RESULT_LOG}"

echo "Updating benchmark catalog..."
python3 - "$OUTPUT_DIR" "$RUN_STAMP" "$RUN_LABEL" "$JMH_ARGS" "$RESULT_JSON" "$RESULT_LOG" "$DATA_SIZE_ARG" "$PAYLOAD_LINES" "$VALUE_PROFILE_ARG" <<'PY'
import json
import math
import sys
from pathlib import Path

output_dir = Path(sys.argv[1])
run_id = sys.argv[2]
run_label = sys.argv[3]
jmh_args = sys.argv[4]
results_path = Path(sys.argv[5])
log_path = Path(sys.argv[6])
data_size = int(sys.argv[7])
payload_lines = int(sys.argv[8])
value_profile = sys.argv[9]

runs_path = output_dir.parent / "runs.json"
summary_path = output_dir / "summary.json"

CACHE_METADATA = {
    ("CacheBenchmark", "LocalCache"): {"name": "LocalCache", "location": "disk"},
    ("CacheBenchmark", "Caffeine"): {"name": "Caffeine", "location": "memory"},
    ("CacheBenchmark", "Guava"): {"name": "Guava", "location": "memory"},
    ("CacheBenchmark", "MapDB"): {"name": "MapDB", "location": "disk"},
}

ALLOWED_SUITE = {"CacheBenchmark"}

def camel_to_words(name: str) -> str:
    if not name:
        return ""
    result = []
    current = name[0]
    for char in name[1:]:
        if char.isupper() and (current and current[-1].islower()):
            result.append(current)
            current = char
        else:
            current += char
    result.append(current)
    return " ".join(result)

def load_results():
    if not results_path.exists():
        return []
    try:
        with results_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (json.JSONDecodeError, OSError):
        return []
    if not isinstance(data, list):
        return []

    filtered = []
    for entry in data:
        benchmark = entry.get("benchmark", "")
        parts = benchmark.split(".")
        if len(parts) < 2:
            continue
        suite = parts[-2]
        if suite not in ALLOWED_SUITE:
            continue
        filtered.append(entry)
    return filtered

def format_entry(entry):
    benchmark = entry.get("benchmark", "")
    if not benchmark:
        return None
    parts = benchmark.split(".")
    if len(parts) < 2:
        return None
    suite = parts[-2]
    if suite not in ALLOWED_SUITE:
        return None
    method = parts[-1]
    if method.startswith("get"):
        operation = "read"
        cache_name = method[3:]
    elif method.startswith("put"):
        operation = "write"
        cache_name = method[3:]
    else:
        return None
    if not cache_name:
        return None
    primary = entry.get("primaryMetric", {})
    score = primary.get("score")
    unit = primary.get("scoreUnit", "")
    if score in (None, 0):
        return None
    latency_ms = None
    if unit.endswith("ops/s"):
        latency_ms = 1000.0 / score if score else None
    metadata = CACHE_METADATA.get((suite, cache_name), {})
    return {
        "suite": suite,
        "cache": cache_name,
        "displayName": metadata.get("name") or camel_to_words(cache_name),
        "location": metadata.get("location", "unknown"),
        "operation": operation,
        "throughput": score,
        "unit": unit,
        "latencyMs": latency_ms,
    }

results = load_results()
read_entries = []
write_entries = []
for entry in results:
    formatted = format_entry(entry)
    if not formatted:
        continue
    if formatted["operation"] == "read":
        read_entries.append(formatted)
    elif formatted["operation"] == "write":
        write_entries.append(formatted)

def sort_entries(items):
    return sorted(
        items,
        key=lambda item: (
            math.inf if item.get("latencyMs") in (None, 0) else item["latencyMs"],
            item.get("displayName", ""),
        ),
    )

summary = {
    "run": {
        "id": run_id,
        "label": run_label,
        "jmhArgs": jmh_args.strip(),
        "dataSize": data_size,
        "payload": {
            "lines": payload_lines,
            "profile": value_profile,
        },
        "resultsPath": results_path.as_posix(),
        "logPath": log_path.as_posix(),
    },
    "metrics": {
        "read": sort_entries(read_entries),
        "write": sort_entries(write_entries),
    },
}

with summary_path.open("w", encoding="utf-8") as handle:
    json.dump(summary, handle, indent=2, ensure_ascii=False)
    handle.write("\n")

latest_js_path = runs_path.parent / "latest-summary.js"
with latest_js_path.open("w", encoding="utf-8") as handle:
    handle.write("window.__LATEST_BENCHMARK__ = ")
    json.dump(summary, handle, ensure_ascii=False)
    handle.write(";\n")

run_entry = {
    "id": run_id,
    "label": run_label,
    "dataSize": data_size,
    "payload": {
        "lines": payload_lines,
        "profile": value_profile,
    },
    "summaryPath": summary_path.as_posix(),
    "resultsPath": results_path.as_posix(),
    "logPath": log_path.as_posix(),
    "jmhArgs": jmh_args.strip(),
}

existing = []
if runs_path.exists():
    try:
        with runs_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
            if isinstance(data, list):
                existing = data
    except json.JSONDecodeError:
        existing = []

existing = [item for item in existing if item.get("id") != run_id]
existing.append(run_entry)
existing.sort(key=lambda item: item.get("id", ""), reverse=True)

with runs_path.open("w", encoding="utf-8") as handle:
    json.dump(existing, handle, indent=2, ensure_ascii=False)
    handle.write("\n")

print(f"Wrote summary to {summary_path.as_posix()}")
print(f"Updated run catalog at {runs_path.as_posix()}")
PY
