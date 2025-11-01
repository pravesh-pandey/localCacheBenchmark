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

JMH_ARGS=${JMH_ARGS:-}

echo "Cleaning previous artifacts..."
rm -f benchmark-summary.html

echo "Building project..."
mvn clean package -q

echo "Running benchmarks..."
JAVA_CMD=(java "${JAVA_OPTS[@]}" -jar target/benchmarks.jar -rf json -rff "${RESULT_JSON}")
if [[ -n "${JMH_ARGS}" ]]; then
  # shellcheck disable=SC2086
  read -r -a EXTRA_ARGS <<< "${JMH_ARGS}"
  JAVA_CMD+=("${EXTRA_ARGS[@]}")
fi
"${JAVA_CMD[@]}" | tee "${RESULT_LOG}"

echo "Updating benchmark catalog..."
python3 - "$OUTPUT_DIR" "$RUN_STAMP" "$RUN_LABEL" "$JMH_ARGS" <<'PY'
import json
import sys
from pathlib import Path

output_dir = Path(sys.argv[1])
run_id = sys.argv[2]
run_label = sys.argv[3]
jmh_args = sys.argv[4]
reports_dir = output_dir.parent
runs_path = reports_dir / "runs.json"
results_path = output_dir / "results.json"
log_path = output_dir / "benchmark-output.log"

def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

try:
    results = load_json(results_path)
except FileNotFoundError:
    results = []
except json.JSONDecodeError:
    results = []

if not isinstance(results, list):
    results = []

benchmarks = sorted({entry.get("benchmark", "unknown") for entry in results})
data_sizes = sorted({entry.get("params", {}).get("dataSize") for entry in results if entry.get("params", {}).get("dataSize") is not None}, key=lambda v: int(v))
value_profiles = sorted({entry.get("params", {}).get("valueProfile") for entry in results if entry.get("params", {}).get("valueProfile")})

entry = {
    "id": run_id,
    "label": run_label,
    "resultsPath": results_path.as_posix(),
    "logPath": log_path.as_posix(),
    "benchmarkCount": len(benchmarks),
    "measurementCount": len(results),
    "dataSizes": data_sizes,
    "valueProfiles": value_profiles,
    "jmhArgs": jmh_args.strip(),
}

if benchmarks:
    entry["benchmarks"] = benchmarks

existing = []
if runs_path.exists():
    try:
        with runs_path.open("r", encoding="utf-8") as handle:
            existing = json.load(handle)
    except json.JSONDecodeError:
        existing = []

existing = [item for item in existing if item.get("id") != run_id]
existing.append(entry)
existing.sort(key=lambda item: item.get("id", ""), reverse=True)

with runs_path.open("w", encoding="utf-8") as handle:
    json.dump(existing, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PY

echo "Generating index.html..."
cat <<'EOF' > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Cache Benchmark Dashboard</title>
    <style>
        :root {
            color-scheme: light;
            font-family: 'Segoe UI', Roboto, Arial, sans-serif;
        }
        body {
            margin: 0;
            background: #f5f7fb;
            color: #142033;
        }
        header {
            background: linear-gradient(135deg, #2563eb, #1e3a8a);
            color: white;
            padding: 32px 20px;
            box-shadow: 0 4px 16px rgba(30, 58, 138, 0.25);
        }
        header h1 {
            margin: 0 0 8px;
            font-size: 28px;
        }
        header p {
            margin: 0;
            font-size: 16px;
            opacity: 0.85;
        }
        main {
            margin: -24px auto 60px;
            max-width: 1100px;
            padding: 0 20px;
        }
        section {
            background: white;
            padding: 24px;
            border-radius: 16px;
            box-shadow: 0 14px 32px rgba(15, 23, 42, 0.08);
            margin-bottom: 24px;
        }
        h2 {
            margin: 0 0 16px;
            font-size: 20px;
            color: #1f2937;
        }
        .runs-list {
            display: grid;
            gap: 12px;
        }
        .runs-list select {
            padding: 12px 14px;
            border-radius: 10px;
            border: 1px solid #cbd5f5;
            font-size: 15px;
            background: #f8faff;
            color: #1f2937;
        }
        .run-summary p {
            margin: 6px 0;
            font-size: 15px;
            color: #334155;
        }
        .controls {
            display: flex;
            flex-wrap: wrap;
            gap: 16px;
            margin-top: 12px;
        }
        .control {
            display: flex;
            flex-direction: column;
            gap: 6px;
            min-width: 160px;
        }
        .control label {
            font-weight: 600;
            color: #1f2937;
        }
        .control select {
            padding: 8px 12px;
            border-radius: 8px;
            border: 1px solid #d1d5db;
            font-size: 14px;
            background: #f9fafb;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 16px;
        }
        th, td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
        }
        th {
            background: #f8fafc;
            color: #1e3a8a;
            font-size: 14px;
            position: sticky;
            top: 0;
            z-index: 2;
        }
        tbody tr:nth-child(odd) {
            background: #fefeff;
        }
        tbody tr:hover {
            background: #eef2ff;
        }
        .notice {
            padding: 16px;
            border-radius: 12px;
            background: #eff6ff;
            color: #1d4ed8;
            border: 1px solid #bfdbfe;
            margin-top: 20px;
        }
        .error {
            color: #b91c1c;
            font-weight: 600;
        }
        .links {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            margin-top: 12px;
        }
        .links a {
            text-decoration: none;
            background: #2563eb;
            color: white;
            padding: 8px 14px;
            border-radius: 8px;
            font-size: 14px;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.25);
        }
        .links a.secondary {
            background: #64748b;
            box-shadow: 0 4px 12px rgba(100, 116, 139, 0.2);
        }
        @media (max-width: 720px) {
            header h1 {
                font-size: 24px;
            }
            section {
                padding: 18px;
            }
            .control {
                min-width: 120px;
            }
            th, td {
                font-size: 13px;
            }
        }
    </style>
</head>
<body>
    <header>
        <h1>Cache Benchmark Dashboard</h1>
        <p>Compare LocalCache against popular alternatives across datasets and payload profiles.</p>
    </header>
    <main>
        <section>
            <h2>Select Benchmark Run</h2>
            <div class="runs-list">
                <select id="run-select">
                    <option value="">Loading runs...</option>
                </select>
                <div id="run-summary" class="run-summary"></div>
            </div>
        </section>

        <section>
            <h2>Interactive Results</h2>
            <div class="controls">
                <div class="control">
                    <label for="data-size-filter">Data size</label>
                    <select id="data-size-filter">
                        <option value="">All</option>
                    </select>
                </div>
                <div class="control">
                    <label for="value-profile-filter">Value profile</label>
                    <select id="value-profile-filter">
                        <option value="">All</option>
                    </select>
                </div>
                <div class="control">
                    <label for="benchmark-filter">Benchmark</label>
                    <select id="benchmark-filter">
                        <option value="">All</option>
                    </select>
                </div>
            </div>

            <div class="notice" id="summary">Select a run to load measurements.</div>

            <table id="results-table">
                <thead>
                <tr>
                    <th>Benchmark</th>
                    <th>Data Size</th>
                    <th>Value Profile</th>
                    <th>Mode</th>
                    <th>Score</th>
                    <th>± Error</th>
                    <th>Units</th>
                </tr>
                </thead>
                <tbody></tbody>
            </table>
        </section>

        <section>
            <h2>How to add new results</h2>
            <p>Run <code>./run-and-publish.sh</code> locally to build the benchmarks, execute the suite, and append a new entry under <code>reports/</code>. Commit the generated folder, <code>reports/runs.json</code>, and this <code>index.html</code> to publish updates.</p>
        </section>
    </main>

    <script>
        const RUNS_URL = 'reports/runs.json';

        const runSelect = document.getElementById('run-select');
        const runSummary = document.getElementById('run-summary');
        const summaryEl = document.getElementById('summary');
        const tableBody = document.querySelector('#results-table tbody');
        const dataSizeFilter = document.getElementById('data-size-filter');
        const valueProfileFilter = document.getElementById('value-profile-filter');
        const benchmarkFilter = document.getElementById('benchmark-filter');

        let runs = [];
        let currentRun = null;
        let currentResults = [];
        const resultsCache = new Map();

        function setSummaryMessage(message, isError = false) {
            summaryEl.classList.toggle('error', isError);
            summaryEl.textContent = message;
        }

        function populateOptions(select, values) {
            select.innerHTML = '<option value=\"\">All</option>';
            values.forEach(value => {
                const option = document.createElement('option');
                option.value = value;
                option.textContent = value;
                select.appendChild(option);
            });
        }

        function formatNumber(value) {
            return Number(value).toLocaleString(undefined, { maximumFractionDigits: 2 });
        }

        function renderRunSummary(run, results) {
            if (!run) {
                runSummary.innerHTML = '';
                return;
            }

            const dataSizes = [...new Set(results.map(entry => entry.params?.dataSize).filter(Boolean))];
            const valueProfiles = [...new Set(results.map(entry => entry.params?.valueProfile).filter(Boolean))];
            const benchmarks = [...new Set(results.map(entry => entry.benchmark))];

            runSummary.innerHTML = `
                <p><strong>Run:</strong> ${run.label}</p>
                <p><strong>Measurements:</strong> ${results.length} rows across ${benchmarks.length} benchmarks</p>
                <p><strong>Data sizes:</strong> ${dataSizes.join(', ') || 'n/a'}</p>
                <p><strong>Value profiles:</strong> ${valueProfiles.join(', ') || 'n/a'}</p>
                <div class="links">
                    <a href="${run.resultsPath}" download>Download results.json</a>
                    <a class="secondary" href="${run.logPath}" download>Download benchmark log</a>
                </div>
            `;
        }

        function renderTable() {
            if (!currentResults.length) {
                tableBody.innerHTML = '';
                setSummaryMessage('Select a run to load measurements.');
                return;
            }

            const size = dataSizeFilter.value;
            const profile = valueProfileFilter.value;
            const benchmark = benchmarkFilter.value;

            const filtered = currentResults.filter(entry => {
                if (size && entry.params?.dataSize !== size) return false;
                if (profile && entry.params?.valueProfile !== profile) return false;
                if (benchmark && entry.benchmark !== benchmark) return false;
                return true;
            });

            tableBody.innerHTML = '';

            if (!filtered.length) {
                const row = document.createElement('tr');
                const cell = document.createElement('td');
                cell.colSpan = 7;
                cell.textContent = 'No results match the selected filters.';
                row.appendChild(cell);
                tableBody.appendChild(row);
                setSummaryMessage('No rows match the current filters.');
                return;
            }

            filtered.forEach(entry => {
                const row = document.createElement('tr');
                const cells = [
                    entry.benchmark,
                    entry.params?.dataSize ?? '—',
                    entry.params?.valueProfile ?? '—',
                    entry.mode,
                    formatNumber(entry.primaryMetric.score),
                    formatNumber(entry.primaryMetric.scoreError),
                    entry.primaryMetric.scoreUnit
                ];
                cells.forEach(text => {
                    const cell = document.createElement('td');
                    cell.textContent = text;
                    row.appendChild(cell);
                });
                tableBody.appendChild(row);
            });

            const benchmarkCount = new Set(filtered.map(entry => entry.benchmark)).size;
            setSummaryMessage(`${filtered.length} measurements across ${benchmarkCount} benchmarks.`);
        }

        async function fetchRunResults(run) {
            if (resultsCache.has(run.id)) {
                return resultsCache.get(run.id);
            }
            const response = await fetch(run.resultsPath);
            if (!response.ok) {
                throw new Error(`Unable to load ${run.resultsPath}`);
            }
            const data = await response.json();
            data.sort((a, b) => {
                const sizeA = Number(a.params?.dataSize ?? 0);
                const sizeB = Number(b.params?.dataSize ?? 0);
                if (sizeA === sizeB) {
                    const profileA = a.params?.valueProfile ?? '';
                    const profileB = b.params?.valueProfile ?? '';
                    if (profileA === profileB) {
                        return a.benchmark.localeCompare(b.benchmark);
                    }
                    return profileA.localeCompare(profileB);
                }
                return sizeA - sizeB;
            });
            resultsCache.set(run.id, data);
            return data;
        }

        async function handleRunChange() {
            const runId = runSelect.value;
            if (!runId) {
                currentRun = null;
                currentResults = [];
                runSummary.innerHTML = '';
                tableBody.innerHTML = '';
                setSummaryMessage('Select a run to load measurements.');
                return;
            }
            currentRun = runs.find(run => run.id === runId);
            if (!currentRun) {
                setSummaryMessage('Selected run metadata not found.', true);
                return;
            }
            try {
                setSummaryMessage('Loading results…');
                const data = await fetchRunResults(currentRun);
                currentResults = data;
                renderRunSummary(currentRun, data);
                populateOptions(dataSizeFilter, [...new Set(data.map(entry => entry.params?.dataSize).filter(Boolean))]);
                populateOptions(valueProfileFilter, [...new Set(data.map(entry => entry.params?.valueProfile).filter(Boolean))]);
                populateOptions(benchmarkFilter, [...new Set(data.map(entry => entry.benchmark).filter(Boolean))]);
                renderTable();
            } catch (error) {
                console.error(error);
                setSummaryMessage('Failed to load the selected run. Ensure the JSON files are published.', true);
                runSummary.innerHTML = '';
                tableBody.innerHTML = '';
            }
        }

        async function loadRuns() {
            try {
                const response = await fetch(RUNS_URL, { cache: 'no-cache' });
                if (!response.ok) {
                    throw new Error('Unable to fetch run catalog.');
                }
                const data = await response.json();
                if (!Array.isArray(data) || !data.length) {
                    throw new Error('No runs recorded yet.');
                }
                runs = data;
                runSelect.innerHTML = '';
                data.forEach((run, index) => {
                    const option = document.createElement('option');
                    option.value = run.id;
                    option.textContent = `${run.label} (${run.id})`;
                    if (index === 0) {
                        option.selected = true;
                    }
                    runSelect.appendChild(option);
                });
                await handleRunChange();
            } catch (error) {
                console.error(error);
                runSelect.innerHTML = '<option value=\"\">No runs available</option>';
                setSummaryMessage('No results yet. Run ./run-and-publish.sh to generate the first report.', true);
            }
        }

        runSelect.addEventListener('change', handleRunChange);
        dataSizeFilter.addEventListener('change', renderTable);
        valueProfileFilter.addEventListener('change', renderTable);
        benchmarkFilter.addEventListener('change', renderTable);

        loadRuns();
    </script>
</body>
</html>
EOF

echo "✅ Benchmark complete!"
echo "📂 Archived run: ${OUTPUT_DIR}"
echo "📊 View dashboard: file://$(pwd)/index.html"
