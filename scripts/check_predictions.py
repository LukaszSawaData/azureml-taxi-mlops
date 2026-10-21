"""Sanity check for the smoke test: 3 prices, all in range, the longer trip costs more."""

import json
import sys


def check(raw: str) -> list[float]:
    data = json.loads(raw)
    if isinstance(data, str):  # the endpoint may return a JSON-encoded string
        data = json.loads(data)
    preds = [float(x) for x in (data["predictions"] if isinstance(data, dict) else data)]
    if len(preds) != 3 or not all(0 < p < 500 for p in preds):
        raise SystemExit(f"predictions out of range: {preds}")
    if not preds[1] > preds[0]:
        raise SystemExit(f"a longer trip should cost more: {preds}")
    return preds


if __name__ == "__main__":
    print(f"OK {check(sys.argv[1])}")
