// Labelled hunks for the noise question: each case is one small review, each hunk has the verdict
// a careful reviewer would give. `null` leaves a hunk unlabelled (it is context for the others).
export interface NoiseCaseFile {
  path: string;
  patch: string;
  /** One entry per hunk: whether it is noise, and what it is. */
  hunks: [isNoise: boolean | null, what: string][];
}

export interface NoiseCase {
  name: string;
  files: NoiseCaseFile[];
}

export const NOISE_CASES: NoiseCase[] = [
  {
    name: "rename rippling through call sites, tests and docs",
    files: [
      {
        path: "app/users.py",
        hunks: [[false, "origin: the renamed definition"]],
        patch: `@@ -10,5 +10,5 @@ class User:
 
-def get_name(user):
+def get_display_name(user):
     """Return the name shown in the UI."""
     return f"{user.first} {user.last}".strip()
`,
      },
      {
        path: "app/views.py",
        hunks: [
          [true, "import following the rename"],
          [true, "call site following the rename"],
        ],
        patch: `@@ -1,5 +1,5 @@
 from flask import render_template
 
-from app.users import get_name
+from app.users import get_display_name
 from app.auth import current_user
 
@@ -22,5 +22,5 @@ def profile():
     user = current_user()
-    return render_template("profile.html", name=get_name(user))
+    return render_template("profile.html", name=get_display_name(user))
 
 
`,
      },
      {
        path: "tests/test_users.py",
        hunks: [[true, "test following the rename"]],
        patch: `@@ -8,5 +8,5 @@ def test_name_is_stripped():
     user = User(first="Ada", last="")
 
-    assert get_name(user) == "Ada"
+    assert get_display_name(user) == "Ada"
 
 
`,
      },
      {
        path: "docs/usage.md",
        hunks: [[true, "doc following the rename"]],
        patch: `@@ -14,3 +14,3 @@ ## Users
 
-Call \`get_name(user)\` to get the name shown in the UI.
+Call \`get_display_name(user)\` to get the name shown in the UI.
 
`,
      },
    ],
  },
  {
    name: "signature change with followers and a new test",
    files: [
      {
        path: "billing/invoice.py",
        hunks: [[false, "origin: new argument and rounding logic"]],
        patch: `@@ -30,6 +30,7 @@ class Invoice:
 
-def compute_total(lines):
-    return sum(line.amount for line in lines)
+def compute_total(lines, *, currency):
+    total = sum(line.amount for line in lines)
+    return round(total, currency.decimals)
 
 
`,
      },
      {
        path: "billing/api.py",
        hunks: [[true, "call site passing the new argument"]],
        patch: `@@ -51,5 +51,5 @@ def get_invoice(invoice_id):
     invoice = load(invoice_id)
-    total = compute_total(invoice.lines)
+    total = compute_total(invoice.lines, currency=invoice.currency)
 
     return {"id": invoice.id, "total": total}
`,
      },
      {
        path: "billing/report.py",
        hunks: [[true, "call site passing the new argument"]],
        patch: `@@ -12,5 +12,5 @@ def monthly_report(invoices):
     rows = []
     for invoice in invoices:
-        rows.append((invoice.id, compute_total(invoice.lines)))
+        rows.append((invoice.id, compute_total(invoice.lines, currency=invoice.currency)))
 
     return rows
`,
      },
      {
        path: "tests/test_invoice.py",
        hunks: [
          [true, "existing test updated for the new argument"],
          [false, "newly added test"],
        ],
        patch: `@@ -9,5 +9,5 @@ def test_total_sums_lines():
     lines = [Line(amount=10), Line(amount=5)]
 
-    assert compute_total(lines) == 15
+    assert compute_total(lines, currency=EUR) == 15
 
 
@@ -20,3 +20,10 @@ def test_total_of_no_line_is_zero():
     assert compute_total([], currency=EUR) == 0
+
+
+def test_total_is_rounded_to_the_currency_decimals():
+    lines = [Line(amount=0.105), Line(amount=0.2)]
+
+    assert compute_total(lines, currency=EUR) == 0.31
+    assert compute_total(lines, currency=JPY) == 0
`,
      },
    ],
  },
  {
    name: "formatting and reordering next to a one-character logic change",
    files: [
      {
        path: "sync/worker.py",
        hunks: [
          [true, "imports reordered"],
          [true, "call rewrapped, same arguments"],
          [false, "comparison changed from > to >="],
          [true, "dict keys reordered"],
        ],
        patch: `@@ -1,6 +1,6 @@
+import json
 import logging
 import os
-import json
 from datetime import datetime
 
 from sync.client import Client
@@ -30,5 +30,9 @@ def push(client, record):
-    response = client.post("/records", payload=record.to_dict(), timeout=DEFAULT_TIMEOUT, retries=3)
+    response = client.post(
+        "/records",
+        payload=record.to_dict(),
+        timeout=DEFAULT_TIMEOUT,
+        retries=3,
+    )
 
     return response.status
@@ -52,5 +56,5 @@ def should_retry(attempt, response):
     if response.status < 500:
         return False
-    return attempt > MAX_ATTEMPTS
+    return attempt >= MAX_ATTEMPTS
 
 
@@ -70,8 +74,8 @@ def describe(record):
     return {
-        "updated_at": record.updated_at,
         "id": record.id,
         "kind": record.kind,
+        "updated_at": record.updated_at,
     }
 
`,
      },
    ],
  },
  {
    name: "deletions: one that follows another, two that stand alone",
    files: [
      {
        path: "exports/service.py",
        hunks: [
          [true, "import made useless by the removed function"],
          [false, "standalone removal of a function"],
          [false, "standalone removal of a guard"],
        ],
        patch: `@@ -1,5 +1,4 @@
-import csv
 import io
 
 from exports.models import Export
 
@@ -40,14 +39,4 @@ def export_json(rows):
     return json.dumps(rows)
 
 
-def export_csv(rows):
-    buffer = io.StringIO()
-    writer = csv.writer(buffer)
-    for row in rows:
-        writer.writerow(row)
-
-    return buffer.getvalue()
-
-
 def start_export(user, kind):
@@ -58,7 +47,4 @@ def start_export(user, kind):
     export = Export(owner=user, kind=kind)
-    if not user.is_active:
-        raise PermissionError("inactive users cannot export")
-
     export.save()
 
`,
      },
    ],
  },
  {
    name: "comments and docs: trivial edits against new content",
    files: [
      {
        path: "cache/store.py",
        hunks: [
          [true, "typo fixed in a comment"],
          [false, "new docstring"],
          [true, "comment rewrapped, same words"],
        ],
        patch: `@@ -12,5 +12,5 @@ class Store:
     def get(self, key):
-        # Retrun the cached value, or None once it has expired.
+        # Return the cached value, or None once it has expired.
         entry = self._entries.get(key)
 
@@ -30,4 +30,10 @@ class Store:
     def evict(self, now):
+        """Drop every entry that expired before \`now\`.
+
+        Eviction is lazy: entries are only checked here, never on read, so a store
+        nobody evicts keeps growing.
+        """
         for key, entry in list(self._entries.items()):
             if entry.expires_at <= now:
@@ -50,6 +56,5 @@ class Store:
-    # Sizes are counted in entries, not in
-    # bytes, so a large value costs as much
-    # as a small one.
+    # Sizes are counted in entries, not in bytes, so a large value costs as much as a small
+    # one.
     def size(self):
         return len(self._entries)
`,
      },
      {
        path: "README.md",
        hunks: [[false, "new documentation section"]],
        patch: `@@ -20,3 +20,11 @@ ## Usage
 store.set("a", 1, ttl=60)
 \`\`\`
+
+## Eviction
+
+Expired entries are not removed on read. Call \`store.evict(now)\` from a periodic job,
+otherwise the store grows without bound.
+
+Eviction walks every entry, so run it at most once a minute on a large store.
`,
      },
    ],
  },
  {
    name: "type annotations: added hints against a changed contract",
    files: [
      {
        path: "mail/sender.py",
        hunks: [
          [true, "type hints added, nothing else"],
          [false, "default and accepted values changed"],
        ],
        patch: `@@ -8,7 +8,7 @@ log = logging.getLogger(__name__)
 
-def normalize(address):
+def normalize(address: str) -> str:
     return address.strip().lower()
 
 
-def is_valid(address):
+def is_valid(address: str) -> bool:
     return "@" in address
@@ -25,5 +25,5 @@ def is_valid(address):
 
-def send(message, timeout=30):
+def send(message: Message, timeout: float | None = None) -> None:
     connection = connect(timeout=timeout)
     connection.deliver(message)
`,
      },
    ],
  },
  {
    name: "messages: rewording against a change of behaviour",
    files: [
      {
        path: "jobs/runner.py",
        hunks: [
          [true, "log message reworded"],
          [true, "error message reworded"],
          [false, "raise replaced by a silent return"],
        ],
        patch: `@@ -18,5 +18,5 @@ def run(job):
     started = time.monotonic()
-    log.info("job %s start", job.id)
+    log.info("Starting job %s", job.id)
     result = job.execute()
 
@@ -33,5 +33,5 @@ def load(job_id):
     job = Job.get(job_id)
     if job is None:
-        raise LookupError(f"no job {job_id}")
+        raise LookupError(f"Job {job_id} does not exist")
 
     return job
@@ -47,6 +47,6 @@ def cancel(job):
     if job.state == "done":
-        raise ValueError("job already finished")
+        log.warning("Ignoring cancel of finished job %s", job.id)
+        return
 
     job.state = "cancelled"
`,
      },
    ],
  },
  {
    name: "manifests, configuration and settings",
    files: [
      {
        path: "pyproject.toml",
        hunks: [
          [false, "own version bump in a manifest"],
          [false, "dependency upgraded"],
        ],
        patch: `@@ -1,5 +1,5 @@
 [project]
 name = "relay"
-version = "1.4.0"
+version = "1.4.1"
 requires-python = ">=3.12"
 
@@ -9,5 +9,5 @@ dependencies = [
     "httpx>=0.27",
-    "pydantic>=2.6",
+    "pydantic>=2.9",
     "structlog>=24.1",
 ]
`,
      },
      {
        path: ".github/workflows/ci.yml",
        hunks: [[false, "CI configuration changed"]],
        patch: `@@ -12,5 +12,5 @@ jobs:
       - uses: actions/setup-python@v5
         with:
-          python-version: "3.12"
+          python-version: "3.13"
       - run: pip install -e .[dev]
 
`,
      },
      {
        path: "relay/settings.py",
        hunks: [[false, "default value changed"]],
        patch: `@@ -6,5 +6,5 @@ import os
 
-DEFAULT_TIMEOUT = 30
+DEFAULT_TIMEOUT = 60
 MAX_CONNECTIONS = int(os.environ.get("RELAY_MAX_CONNECTIONS", "10"))
 
`,
      },
      {
        path: "ruff.toml",
        hunks: [[false, "lint configuration changed"]],
        patch: `@@ -1,4 +1,4 @@
-line-length = 88
+line-length = 100
 target-version = "py312"
 
`,
      },
    ],
  },
  {
    name: "generated files: meaningless churn against a real change",
    files: [
      {
        path: "api/openapi.json",
        hunks: [[false, "API contract gains a required field"]],
        patch: `@@ -120,8 +120,12 @@
         "Invoice": {
           "type": "object",
-          "required": ["id", "total"],
+          "required": ["id", "total", "currency"],
           "properties": {
             "id": { "type": "string" },
-            "total": { "type": "number" }
+            "total": { "type": "number" },
+            "currency": {
+              "type": "string",
+              "description": "ISO 4217 code"
+            }
           }
         },
`,
      },
      {
        path: "client/generated/api.ts",
        hunks: [[true, "generation timestamp only"]],
        patch: `@@ -1,5 +1,5 @@
 // This file is generated. Do not edit.
-// Generated at 2026-11-02T08:14:55Z by openapi-gen 4.2.0 (build 9f31c2a)
+// Generated at 2026-11-10T17:02:11Z by openapi-gen 4.2.0 (build 9f31c2a)
 
 export interface Invoice {
`,
      },
      {
        path: "tests/__snapshots__/test_report.ambr",
        hunks: [
          [true, "snapshot: run id and timestamp only"],
          [false, "snapshot: reported total changed"],
        ],
        patch: `@@ -2,6 +2,6 @@
 # name: test_monthly_report
   dict({
-    'generated_at': '2026-11-02T08:14:55',
-    'run_id': 'a41f0c9e',
+    'generated_at': '2026-11-10T17:02:11',
+    'run_id': 'c7d2e815',
     'rows': list([
       dict({
@@ -14,5 +14,5 @@
         'id': 'inv_002',
-        'total': 15.305,
+        'total': 15.31,
       }),
     ]),
`,
      },
    ],
  },
  {
    name: "moved code, unchanged or edited on the way",
    files: [
      {
        path: "text/utils.py",
        hunks: [
          [false, "old place of a function moved unchanged (moves are never noise)"],
          [false, "old place of a function moved and edited"],
        ],
        patch: `@@ -10,12 +10,4 @@ import re
 
 
-def truncate(text, limit):
-    if len(text) <= limit:
-        return text
-
-    return text[: limit - 1] + "…"
-
-
 def word_count(text):
     return len(text.split())
@@ -30,8 +22,3 @@ def word_count(text):
 
 
-def slugify(text):
-    text = re.sub(r"[^a-zA-Z0-9]+", "-", text)
-
-    return text.strip("-")
-
`,
      },
      {
        path: "text/formatting.py",
        hunks: [
          [false, "new place of a function moved unchanged (moves are never noise)"],
          [false, "new place of a function moved and edited (now lowercases)"],
        ],
        patch: `@@ -5,3 +5,11 @@ import re
 
 
+def truncate(text, limit):
+    if len(text) <= limit:
+        return text
+
+    return text[: limit - 1] + "…"
+
+
 def indent(text, width):
     return "\\n".join(" " * width + line for line in text.splitlines())
@@ -20,3 +28,9 @@ def indent(text, width):
 
 
+def slugify(text):
+    text = re.sub(r"[^a-zA-Z0-9]+", "-", text.lower())
+
+    return text.strip("-")
+
+
`,
      },
    ],
  },
  {
    name: "TypeScript: renamed field, new behaviour and a new test",
    files: [
      {
        path: "src/types.ts",
        hunks: [[false, "origin: the renamed field"]],
        patch: `@@ -4,5 +4,5 @@ export interface Task {
   id: string;
   title: string;
-  done: boolean;
+  isCompleted: boolean;
   dueAt: Date | null;
 }
`,
      },
      {
        path: "src/TaskRow.tsx",
        hunks: [
          [true, "usage following the renamed field"],
          [false, "new behaviour: overdue styling"],
        ],
        patch: `@@ -10,5 +10,5 @@ export function TaskRow({ task, onToggle }: Props) {
   return (
     <li>
-      <input type="checkbox" checked={task.done} onChange={() => onToggle(task.id)} />
+      <input type="checkbox" checked={task.isCompleted} onChange={() => onToggle(task.id)} />
       <span>{task.title}</span>
@@ -17,3 +17,6 @@ export function TaskRow({ task, onToggle }: Props) {
       <span>{task.title}</span>
+      {task.dueAt !== null && task.dueAt < new Date() && !task.isCompleted && (
+        <span className="overdue">overdue</span>
+      )}
     </li>
`,
      },
      {
        path: "src/store.ts",
        hunks: [[true, "usage following the renamed field"]],
        patch: `@@ -22,5 +22,5 @@ export function toggle(tasks: Task[], id: string): Task[] {
   return tasks.map((task) =>
-    task.id === id ? { ...task, done: !task.done } : task,
+    task.id === id ? { ...task, isCompleted: !task.isCompleted } : task,
   );
 }
`,
      },
      {
        path: "src/TaskRow.test.tsx",
        hunks: [
          [true, "fixture following the renamed field"],
          [false, "newly added test"],
        ],
        patch: `@@ -5,5 +5,5 @@ const task: Task = {
   id: "t1",
   title: "Write the report",
-  done: false,
+  isCompleted: false,
   dueAt: null,
 };
@@ -18,3 +18,10 @@ test("renders the title", () => {
   expect(screen.getByText("Write the report")).toBeTruthy();
 });
+
+test("marks an unfinished task past its due date as overdue", () => {
+  const late = { ...task, dueAt: new Date("2020-01-01") };
+  render(<TaskRow task={late} onToggle={() => {}} />);
+
+  expect(screen.getByText("overdue")).toBeTruthy();
+});
`,
      },
    ],
  },
  {
    name: "small standalone logic changes",
    files: [
      {
        path: "net/retry.py",
        hunks: [
          [false, "constant changed"],
          [false, "new early return"],
        ],
        patch: `@@ -3,5 +3,5 @@ import time
 
-MAX_RETRIES = 3
+MAX_RETRIES = 5
 BACKOFF_SECONDS = 0.5
 
@@ -14,4 +14,6 @@ def call(request):
     for attempt in range(MAX_RETRIES):
         response = request()
+        if response.status == 429:
+            return response
         if response.ok:
             return response
`,
      },
    ],
  },
];
