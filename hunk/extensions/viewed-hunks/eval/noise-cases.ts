// Labelled hunks for the noise and reach questions: each case is one small review, each hunk has
// the verdict a careful reviewer would give. `null` leaves a hunk unlabelled (it is context for
// the others). The reach is labelled on hunks that are not noise, where it decides whether the
// architecture view shows them.
import type { Reach } from "../src/noise.ts";

export interface NoiseCaseFile {
  path: string;
  patch: string;
  /** One entry per hunk: whether it is noise, what it is, and how far it reaches. */
  hunks: [isNoise: boolean | null, what: string, reach?: Reach][];
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
        hunks: [[false, "origin: the renamed definition", "interface"]],
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
        hunks: [[false, "origin: new argument and rounding logic", "interface"]],
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
          [false, "newly added test", "detail"],
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
          [false, "comparison changed from > to >=", "detail"],
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
          [false, "standalone removal of a function", "structure"],
          [false, "standalone removal of a guard", "detail"],
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
          [false, "new docstring", "detail"],
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
        hunks: [[false, "new documentation section", "detail"]],
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
          [false, "default and accepted values changed", "interface"],
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
          [false, "raise replaced by a silent return", "detail"],
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
          [false, "own version bump in a manifest", "detail"],
          [false, "dependency upgraded", "detail"],
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
        hunks: [[false, "CI configuration changed", "detail"]],
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
        hunks: [[false, "default value changed", "detail"]],
        patch: `@@ -6,5 +6,5 @@ import os
 
-DEFAULT_TIMEOUT = 30
+DEFAULT_TIMEOUT = 60
 MAX_CONNECTIONS = int(os.environ.get("RELAY_MAX_CONNECTIONS", "10"))
 
`,
      },
      {
        path: "ruff.toml",
        hunks: [[false, "lint configuration changed", "detail"]],
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
        hunks: [[false, "API contract gains a required field", "interface"]],
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
          [false, "snapshot: reported total changed", "detail"],
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
          [false, "old place of a function moved unchanged (moves are never noise)", "structure"],
          [false, "old place of a function moved and edited", "structure"],
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
          [false, "new place of a function moved unchanged (moves are never noise)", "structure"],
          [false, "new place of a function moved and edited (now lowercases)", "structure"],
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
        hunks: [[false, "origin: the renamed field", "detail"]],
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
          [false, "new behaviour: overdue styling", "detail"],
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
          [false, "newly added test", "detail"],
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
    name: "imports: added and removed for code changed in other hunks",
    files: [
      {
        path: "orders/service.py",
        hunks: [
          [true, "imports added for the new code, one dropped"],
          [false, "new logic using the new imports", "detail"],
          [false, "logic no longer using the dropped import", "detail"],
        ],
        patch: `@@ -1,8 +1,10 @@
 import logging
-import random
+from datetime import timedelta
+from decimal import Decimal
 
 from orders.models import Order
+from orders.pricing import apply_discount
 
 log = logging.getLogger(__name__)
 
@@ -24,5 +26,8 @@ def total(order):
     amount = sum(line.amount for line in order.lines)
-    return amount
+    if order.created_at < now() - timedelta(days=30):
+        amount = apply_discount(amount, Decimal("0.1"))
+
+    return amount
 
 
@@ -40,5 +45,5 @@ def reference(order):
-    return f"{order.id}-{random.randint(0, 999)}"
+    return f"{order.id}-{order.sequence}"
 
 
`,
      },
    ],
  },
  {
    name: "imports: a new third-party library, with its manifest and its use",
    files: [
      {
        path: "fetch/client.py",
        hunks: [
          [true, "import swapped for the new library"],
          [false, "call rewritten for the new library", "detail"],
        ],
        patch: `@@ -1,5 +1,5 @@
 import json
-import urllib.request
+import httpx
 
 from fetch.errors import FetchError
 
@@ -12,7 +12,7 @@ def fetch(url):
-    with urllib.request.urlopen(url, timeout=10) as response:
-        body = response.read()
+    response = httpx.get(url, timeout=10, follow_redirects=True)
+    body = response.content
 
     return json.loads(body)
`,
      },
      {
        path: "pyproject.toml",
        hunks: [[false, "new dependency declared"]],
        patch: `@@ -8,4 +8,5 @@ dependencies = [
     "structlog>=24.1",
+    "httpx>=0.27",
 ]
 
`,
      },
    ],
  },
  {
    name: "imports: TypeScript import lists following the code",
    files: [
      {
        path: "src/Cart.tsx",
        hunks: [
          [true, "named imports extended, a type import added"],
          [false, "new memoised total", "detail"],
        ],
        patch: `@@ -1,6 +1,7 @@
-import { useState } from "react";
+import { useMemo, useState } from "react";
 
-import { formatPrice } from "./format";
+import { formatPrice, sumPrices } from "./format";
+import type { CartLine } from "./types";
 import { Row } from "./Row";
 
@@ -14,5 +15,6 @@ export function Cart({ lines }: Props) {
   const [open, setOpen] = useState(false);
+  const total = useMemo(() => sumPrices(lines.map((line: CartLine) => line.price)), [lines]);
 
   return (
`,
      },
      {
        path: "src/Checkout.tsx",
        hunks: [[true, "import path updated for a module that moved"]],
        patch: `@@ -1,5 +1,5 @@
 import { useState } from "react";
 
-import { formatPrice } from "./format";
+import { formatPrice } from "./lib/format";
 import { Button } from "./Button";
 
`,
      },
    ],
  },
  {
    name: "imports: the ones that are the change itself",
    files: [
      {
        path: "app/__init__.py",
        hunks: [[false, "import added only for its side effects"]],
        patch: `@@ -4,4 +4,5 @@ from app.config import settings
 
 import app.routes  # noqa: F401
+import app.signals  # noqa: F401  (registers the signal handlers)
 
`,
      },
      {
        path: "app/reports.py",
        hunks: [
          [true, "top-level import removed, it moved into the function"],
          [false, "import moved into the function to load lazily", "detail"],
        ],
        patch: `@@ -1,5 +1,4 @@
 import logging
-import pandas as pd
 
 from app.models import Report
 
@@ -18,4 +17,6 @@ def build(report_id):
     report = Report.get(report_id)
+    import pandas as pd  # heavy: only load it when a report is built
+
     frame = pd.DataFrame(report.rows)
 
`,
      },
      {
        path: "app/limits.py",
        hunks: [[false, "import next to a changed constant in the same hunk", "detail"]],
        patch: `@@ -1,5 +1,6 @@
 import os
+import math
 
-MAX_UPLOAD_MB = 10
+MAX_UPLOAD_MB = 25
 
 
`,
      },
    ],
  },
  {
    name: "configuration: a moved entry against a changed value",
    files: [
      {
        path: ".claude/settings.json",
        hunks: [
          [false, "configuration value changed", "detail"],
          [true, "configuration entry moved, same value"],
        ],
        patch: `@@ -3,5 +3,5 @@
   "theme": "dark",
-  "model": "opus",
+  "model": "opus[1m]",
   "verbose": false,
   "permissions": {
@@ -40,8 +40,8 @@
   "hooks": {
     "enabled": true
-  "promptSuggestionEnabled": false,
-  }
+  },
+  "promptSuggestionEnabled": false
 }
`,
      },
      {
        path: "tsconfig.json",
        hunks: [[true, "configuration keys reordered, same values"]],
        patch: `@@ -2,7 +2,7 @@
   "compilerOptions": {
-    "strict": true,
     "module": "ESNext",
     "moduleResolution": "bundler",
+    "strict": true,
     "noEmit": true
   }
`,
      },
    ],
  },
  {
    name: "comments beside noise against comments on their own",
    files: [
      {
        path: "src/pane.tsx",
        hunks: [
          [true, "new comment line beside an added import"],
          [false, "new function using the import", "structure"],
          [false, "new comment on unchanged code", "detail"],
        ],
        patch: `@@ -1,6 +1,8 @@
 // Panes docked beside the review.
+// A narrow map pane lists every hunk with its status.
 import { useState } from "react";
+import { basename } from "node:path";
 
 import { Row } from "./Row";
 
@@ -20,4 +22,10 @@ export function StatusPane({ rows }: Props) {
 }
 
+export function MapPane({ files }: MapProps) {
+  const names = files.map((file) => basename(file.path));
+
+  return <List items={names} />;
+}
+
@@ -48,5 +56,7 @@ function clamp(value: number, max: number) {
+  // Negative values come from a selection that scrolled out of view: pin them to the first
+  // row instead of letting the window start before the list.
   return Math.min(Math.max(0, value), max);
 }
`,
      },
      {
        path: "src/format.ts",
        hunks: [[false, "origin: the renamed function", "interface"]],
        patch: `@@ -3,5 +3,5 @@
 
-export function fmt(price: number): string {
+export function formatPrice(price: number): string {
   return price.toFixed(2);
 }
`,
      },
      {
        path: "src/Total.tsx",
        hunks: [[true, "call site following the rename, with its comment reworded"]],
        patch: `@@ -9,6 +9,6 @@ export function Total({ lines }: Props) {
   const sum = lines.reduce((total, line) => total + line.price, 0);
 
-  // fmt keeps two decimals
-  return <span>{fmt(sum)}</span>;
+  // formatPrice keeps two decimals
+  return <span>{formatPrice(sum)}</span>;
 }
`,
      },
    ],
  },
  {
    name: "reach: added, removed and re-signed definitions against body changes",
    files: [
      {
        path: "shop/cart.py",
        hunks: [
          [false, "new function", "structure"],
          [false, "signature gains a parameter", "interface"],
          [false, "logic changed inside a body", "detail"],
          [false, "class removed", "structure"],
        ],
        patch: `@@ -10,4 +10,12 @@ def subtotal(cart):
     return sum(item.price * item.quantity for item in cart.items)
 
 
+def apply_coupon(cart, coupon):
+    if coupon.expired:
+        raise CouponExpired(coupon.code)
+
+    cart.discount = coupon.amount
+    return cart
+
+
@@ -30,6 +38,6 @@ def apply_coupon(cart, coupon):
 
-def checkout(cart):
-    order = Order.from_cart(cart)
+def checkout(cart, *, payment_method):
+    order = Order.from_cart(cart, payment_method=payment_method)
     order.save()
 
@@ -52,7 +60,9 @@ def shipping_cost(cart):
     weight = sum(item.weight for item in cart.items)
-    if weight > 20:
-        return 15
+    if weight > 30:
+        return 25
+    if weight > 10:
+        return 15
 
     return 5
@@ -70,12 +80,3 @@ def shipping_cost(cart):
 
 
-class LegacyCart:
-    def __init__(self, rows):
-        self.rows = rows
-
-    def total(self):
-        return sum(row[1] for row in self.rows)
-
-
 def empty(cart):
`,
      },
      {
        path: "shop/models.py",
        hunks: [
          [false, "new method on a class", "structure"],
          [false, "new class", "structure"],
        ],
        patch: `@@ -18,4 +18,9 @@ class Order:
         return cls(lines=list(cart.items))
 
+    def refund(self, reason):
+        self.state = "refunded"
+        self.refund_reason = reason
+        self.save()
+
     def save(self):
@@ -40,3 +45,12 @@ class Order:
         db.commit(self)
+
+
+class Refund:
+    def __init__(self, order, amount):
+        self.order = order
+        self.amount = amount
+
+    def issue(self):
+        gateway.refund(self.order.payment_id, self.amount)
`,
      },
      {
        path: "tests/test_cart.py",
        hunks: [[false, "new tests for the new function", "detail"]],
        patch: `@@ -30,3 +30,17 @@ def test_subtotal_multiplies_quantity():
     assert subtotal(cart) == 30
+
+
+def test_apply_coupon_sets_the_discount():
+    cart = apply_coupon(Cart(items=[]), Coupon(code="X", amount=5))
+
+    assert cart.discount == 5
+
+
+def test_apply_coupon_rejects_an_expired_coupon():
+    coupon = Coupon(code="X", amount=5, expired=True)
+
+    with pytest.raises(CouponExpired):
+        apply_coupon(Cart(items=[]), coupon)
`,
      },
    ],
  },
  {
    name: "reach: types, routes, commands and a new dependency between modules",
    files: [
      {
        path: "src/api/types.ts",
        hunks: [[false, "exported type gains a field", "detail"]],
        patch: `@@ -4,5 +4,6 @@ export interface Invoice {
   id: string;
   total: number;
+  currency: string;
   lines: InvoiceLine[];
 }
`,
      },
      {
        path: "src/api/cache.ts",
        hunks: [
          [false, "fields of a type used only in this module", "detail"],
          [false, "body adapted to the internal type", "detail"],
        ],
        patch: `@@ -3,6 +3,7 @@ import type { Invoice } from "./types";
 interface Entry {
   value: Invoice;
-  expiresAt: number;
+  storedAt: number;
+  ttlMs: number;
 }
 
@@ -18,5 +19,5 @@ export function read(id: string): Invoice | null {
   const entry = entries.get(id);
-  if (!entry || entry.expiresAt < Date.now()) return null;
+  if (!entry || entry.storedAt + entry.ttlMs < Date.now()) return null;
 
   return entry.value;
`,
      },
      {
        path: "src/api/routes.ts",
        hunks: [
          [true, "import for the new route"],
          [false, "new route", "structure"],
        ],
        patch: `@@ -1,4 +1,5 @@
 import { Router } from "express";
 
+import { exportInvoices } from "../exports/service";
 import { getInvoice, listInvoices } from "./invoices";
 
@@ -12,4 +13,9 @@ router.get("/invoices", async (req, res) => {
 router.get("/invoices/:id", async (req, res) => {
   res.json(await getInvoice(req.params.id));
 });
+
+router.post("/invoices/export", async (req, res) => {
+  const job = await exportInvoices(req.body.ids);
+  res.status(202).json({ jobId: job.id });
+});
`,
      },
      {
        path: "src/cli.ts",
        hunks: [[false, "new command registered", "structure"]],
        patch: `@@ -22,4 +22,11 @@ program
   .action(() => sync());
 
+program
+  .command("export <ids...>")
+  .description("export invoices as CSV")
+  .action(async (ids: string[]) => {
+    await exportInvoices(ids);
+  });
+
 program.parse();
`,
      },
      {
        path: "src/billing/reminders.ts",
        hunks: [
          [true, "import for the new call"],
          [false, "body now calls another module of the project for the first time", "structure"],
        ],
        patch: `@@ -1,4 +1,5 @@
 import { listOverdue } from "./invoices";
+import { sendMail } from "../notifications/mailer";
 
 const log = createLogger("reminders");
@@ -10,5 +11,6 @@ export async function remind(): Promise<void> {
   for (const invoice of await listOverdue()) {
     log.info("overdue", invoice.id);
+    await sendMail(invoice.customerEmail, "reminder", { invoice });
   }
 }
`,
      },
    ],
  },
  {
    name: "reach: hunks mixing levels",
    files: [
      {
        path: "src/colors.ts",
        hunks: [
          [false, "imports, new constants and a type alias, no function", "detail"],
          [false, "a body edited, then two new functions below it", "structure"],
        ],
        patch: `@@ -1,8 +1,14 @@
-import { parse } from "./parse";
+import { parse, tokenize } from "./parse";
+import type { Theme } from "./theme";
 
 const DEFAULT_ALPHA = 1;
+const FADE_AMOUNT = 0.5;
+// From this contrast up, text is readable on its background.
+const MIN_CONTRAST = 4.5;
+
+type Channel = "red" | "green" | "blue";
 
 export function toHex(color: Color): string {
@@ -20,6 +26,24 @@ export function toHex(color: Color): string {
 export function names(colors: Color[]): string[] {
-  return colors.map(({ name }) => name);
+  return colors.map(({ name, alias }) => alias ?? name);
 }
+
+/** \`color\` moved towards \`background\` by \`amount\`. */
+export function fade(color: string, background: string, amount: number): string {
+  const from = parse(color);
+  const to = parse(background);
+
+  return toHex(mix(from, to, amount));
+}
+
+/** The first row to show so that the selected one stays in view. */
+export function windowStart(selected: number, count: number, height: number): number {
+  const last = Math.max(0, count - height);
+
+  return Math.min(Math.max(0, selected - Math.floor(height / 2)), last);
+}
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
          [false, "constant changed", "detail"],
          [false, "new early return", "detail"],
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
