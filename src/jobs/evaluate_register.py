"""Step 3 - evaluate + register: new model vs current champion on 'new' trips.

Registers a new model version only if it is good enough. The champion tag itself is set by
GitHub Actions after the endpoint really serves the version.
"""

import argparse
from pathlib import Path

import mlflow
import pandas as pd
from mlflow import MlflowClient
from mlflow.exceptions import MlflowException

from taxi_aml.model import (
    CHAMPION_TAG,
    SKOPS_TRUSTED_TYPES,
    TARGET,
    evaluate,
    promotion_decision,
)


def find_champion(client: MlflowClient, name: str):
    try:
        versions = client.search_model_versions(f"name='{name}'")
    except MlflowException:  # model not registered yet
        return None
    champs = [v for v in versions if v.tags.get(CHAMPION_TAG) == "true"]
    return max(champs, key=lambda v: int(v.version)) if champs else None


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--model_input", required=True)
    p.add_argument("--scoring_data", required=True)
    p.add_argument("--model_name", default="taxi-fare-model")
    p.add_argument("--max_rmse", type=float, default=6.0)
    p.add_argument("--build_id", default="local")
    args = p.parse_args()

    scoring = pd.read_parquet(Path(args.scoring_data) / "data.parquet")
    y = scoring[TARGET]

    candidate = mlflow.pyfunc.load_model(args.model_input)
    cand = evaluate(candidate, scoring, y)
    mlflow.log_metrics({f"candidate_{k}": v for k, v in cand.items()})
    print(f"candidate: {cand}")

    client = MlflowClient()
    champion_rmse = None
    champ = find_champion(client, args.model_name)
    if champ:
        champion = mlflow.pyfunc.load_model(f"models:/{args.model_name}/{champ.version}")
        champion_rmse = evaluate(champion, scoring, y)["rmse"]
        mlflow.log_metric("champion_rmse", champion_rmse)
        print(f"champion v{champ.version}: rmse={champion_rmse:.3f}")

    promote, reason = promotion_decision(cand["rmse"], champion_rmse, args.max_rmse)
    mlflow.set_tag("decision", reason)
    print(f"promote={promote}: {reason}")
    if not promote:
        print("no new version registered - the current champion stays")
        return

    info = mlflow.sklearn.log_model(
        mlflow.sklearn.load_model(args.model_input),
        name="model",
        registered_model_name=args.model_name,
        skops_trusted_types=SKOPS_TRUSTED_TYPES,
    )
    version = str(info.registered_model_version)
    for key, value in {
        "rmse": f"{cand['rmse']:.4f}",
        "r2": f"{cand['r2']:.4f}",
        "build_id": args.build_id,
        "decision": reason,
    }.items():
        client.set_model_version_tag(args.model_name, version, key, value)
    print(f"registered {args.model_name} v{version}")


if __name__ == "__main__":
    main()
