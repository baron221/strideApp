"""
Stride — Run Type Classifier training script
============================================

Creates the Core ML model `RunTypeClassifier.mlmodel` that the Stride app uses
to recognise what kind of run the user just did:

    Recovery · Easy · Long · Tempo · Intervals

Steps
-----
1. Generate a labelled training set of 3,000 sample runs. Each class follows
   standard running-coach guidance (heart-rate zones as % of max heart rate,
   typical duration and perceived effort), with natural overlap and noise,
   for runners of different fitness levels.
2. Save it as `run_types.csv` (you can open this file in Create ML on a Mac
   and train your own Tabular Classifier from it — see README).
3. Train a Random Forest (40 trees) and report accuracy on a held-out 20%.
4. Export the forest to Core ML (Tree Ensemble Classifier) with readable
   input/output names, author and descriptions.

Run:  python3 train_run_classifier.py
Needs: numpy, scikit-learn, coremltools
"""
import csv
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, confusion_matrix
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.tree_ensemble import TreeEnsembleClassifier

RNG = np.random.default_rng(2026)
FEATURES = ["distanceKm", "durationMin", "relativePace", "heartRatePercent", "effort"]
CLASSES = ["Recovery", "Easy", "Long", "Tempo", "Intervals"]

# Per-class ranges: (duration min, relative pace vs. the runner's usual pace,
# average heart rate as fraction of max, perceived effort 1–10)
PROFILES = {
    "Recovery":  dict(dur=(15, 40),  rel=(1.05, 1.30), hr=(0.56, 0.70), eff=(1, 3)),
    "Easy":      dict(dur=(25, 68),  rel=(0.95, 1.16), hr=(0.64, 0.79), eff=(3, 5)),
    "Long":      dict(dur=(70, 160), rel=(0.98, 1.18), hr=(0.66, 0.82), eff=(4, 7)),
    "Tempo":     dict(dur=(20, 55),  rel=(0.84, 0.98), hr=(0.80, 0.89), eff=(6, 8)),
    "Intervals": dict(dur=(25, 60),  rel=(0.88, 1.03), hr=(0.80, 0.93), eff=(8, 10)),
}


def impute_hr(effort):
    """Same rule the app uses when the runner has no heart-rate monitor."""
    return 0.55 + 0.04 * effort


def sample_run(label):
    p = PROFILES[label]
    usual_pace = RNG.uniform(4.6, 8.2)                    # min/km, runner fitness
    dur = RNG.uniform(*p["dur"])
    rel = np.clip(RNG.uniform(*p["rel"]) + RNG.normal(0, 0.02), 0.7, 1.4)
    pace = usual_pace * rel
    dist = dur / pace
    eff = int(np.clip(round(RNG.uniform(p["eff"][0] - 0.49, p["eff"][1] + 0.49) + RNG.normal(0, 0.4)), 1, 10))
    if RNG.random() < 0.25:                               # no heart-rate monitor
        hr = impute_hr(eff) + RNG.normal(0, 0.015)
    else:
        hr = RNG.uniform(*p["hr"]) + RNG.normal(0, 0.015)
    return [round(dist, 2), round(dur, 1), round(rel, 3), round(float(np.clip(hr, 0.5, 1.0)), 3), eff, label]


def main():
    rows = [sample_run(c) for c in CLASSES for _ in range(600)]
    RNG.shuffle(rows)
    with open("run_types.csv", "w", newline="") as f:
        w = csv.writer(f); w.writerow(FEATURES + ["runType"]); w.writerows(rows)

    X = np.array([r[:5] for r in rows], dtype=float)
    y = np.array([r[5] for r in rows])
    Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, random_state=7, stratify=y)
    rf = RandomForestClassifier(n_estimators=40, max_depth=8, min_samples_leaf=3, random_state=7)
    rf.fit(Xtr, ytr)
    acc = accuracy_score(yte, rf.predict(Xte))
    print(f"Held-out accuracy: {acc:.1%}")
    print("Classes:", list(rf.classes_))
    print(confusion_matrix(yte, rf.predict(Xte), labels=CLASSES))
    print("Feature importance:", dict(zip(FEATURES, np.round(rf.feature_importances_, 3))))

    # ---- Export to Core ML -------------------------------------------------
    class_labels = list(rf.classes_)
    builder = TreeEnsembleClassifier(
        features=[(n, datatypes.Double()) for n in FEATURES],
        class_labels=class_labels,
        output_features=[("runType", datatypes.String()),
                         ("runTypeProbability", datatypes.Dictionary(datatypes.String()))],
    )
    n_trees = len(rf.estimators_)
    for t_id, est in enumerate(rf.estimators_):
        tree = est.tree_
        for node in range(tree.node_count):
            left, right = tree.children_left[node], tree.children_right[node]
            if left == right:  # leaf
                counts = tree.value[node][0]
                probs = counts / counts.sum()
                builder.add_leaf_node(t_id, node, list(probs / n_trees))
            else:
                builder.add_branch_node(t_id, node, int(tree.feature[node]), float(tree.threshold[node]),
                                        "BranchOnValueLessThanEqual", int(left), int(right))
    builder.set_default_prediction_value([0.0] * len(class_labels))
    builder.set_post_evaluation_transform("NoTransform")

    spec = builder.spec
    spec.description.metadata.author = "Ulugbek Tursunaliev & Bakhromjon Tulkinov — ACT Group Lab"
    spec.description.metadata.shortDescription = (
        "Classifies a run as Recovery, Easy, Long, Tempo or Intervals from distance, "
        "duration, pace relative to the runner's usual pace, heart rate (% of max) and effort.")
    spec.description.metadata.license = "For training and education"
    spec.description.metadata.versionString = "1.0"
    desc = {
        "distanceKm": "Distance of the run in kilometres",
        "durationMin": "Moving time in minutes",
        "relativePace": "Pace divided by the runner's usual pace (1.0 = usual, <1 = faster)",
        "heartRatePercent": "Average heart rate as a fraction of max heart rate (0.5–1.0)",
        "effort": "Perceived effort, 1 (very easy) to 10 (maximal)",
    }
    for inp in spec.description.input:
        inp.shortDescription = desc[inp.name]
    for out in spec.description.output:
        out.shortDescription = ("Most likely run type" if out.name == "runType"
                                else "Probability for each run type")
    ct.models.utils.save_spec(spec, "RunTypeClassifier.mlmodel")
    print("Saved RunTypeClassifier.mlmodel")

    # ---- Self-check: evaluate the exported spec in pure Python -------------
    import collections
    nodes = collections.defaultdict(dict)
    for n in spec.treeEnsembleClassifier.treeEnsemble.nodes:
        nodes[n.treeId][n.nodeId] = n
    def predict(x):
        score = [0.0] * len(class_labels)
        for t in nodes.values():
            n = t[0]
            while len(n.evaluationInfo) == 0:  # walk branches until a leaf
                n = t[n.trueChildNodeId] if x[n.branchFeatureIndex] <= n.branchFeatureValue else t[n.falseChildNodeId]
            for e in n.evaluationInfo:
                score[e.evaluationIndex] += e.evaluationValue
        return class_labels[int(np.argmax(score))]
    agree = np.mean([predict(x) == p for x, p in zip(Xte, rf.predict(Xte))])
    print(f"Exported model agrees with scikit-learn on {agree:.1%} of test runs")


if __name__ == "__main__":
    main()
