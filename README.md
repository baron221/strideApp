# Stride — an AI running coach for iPhone

ACT Group Lab · Assignment 1: an iOS app (SwiftUI + Xcode) that uses on-device machine learning

Ulugbek Tursunaliev (u.tursunaliev@npuu.uz) · Bakhromjon Tulkinov (b.tulkinov@npuu.uz)
National Pedagogical University of Uzbekistan

## Open and run (Xcode 26)

1. Unzip `Stride_Xcode.zip` and double-click **`Stride.xcodeproj`**. It is a ready-made project, so you don't need to create a new one.
2. At the top of the window, choose the **Stride** scheme and an **iPhone 17** simulator.
3. Press **⌘R**. The first build takes 1–2 minutes.
4. In the app, tap **Load sample runs** to see six weeks of runs that have already been analysed by the AI.
5. Press **⌘U** to run the tests (unit tests with Swift Testing, plus 2 UI tests).

If Xcode asks for a team when you run the app on a real iPhone: Target **Stride** → **Signing & Capabilities** → choose your team. You don't need a team for the simulator.

## User story

> **Dilnoza** is a first-year student in Tashkent training for her first **10K race** (10 km). She runs 3–4 times a week and writes a short note after each run. She runs almost every run hard, she is often tired, her knee has started to hurt, and she doesn't know what finish time is realistic.

## What the app does

| Need from the story | Feature | Apple technology |
|---|---|---|
| "Am I training right?" | Each run is classified as **Recovery, Easy, Long, Tempo or Intervals**, with a confidence bar for every type, updated live while you type | **Core ML** (bundled `RunTypeClassifier.mlmodel`) |
| "I always run hard" | **80/20 balance** donut and warnings (about 80% of runs should be easy) | Swift Charts + Core ML results |
| "My knee hurts" | The post-run note is read for **mood** (positive/neutral/negative) and **pain words** ("hurts", "aching", "sore"), ignoring "no pain" | **Natural Language** framework (sentiment + lemmatizer) |
| "What time can I run?" | **Race predictor** for 5K / 10K / half marathon that learns your personal endurance factor | On-device **linear regression** (Riegel model) |
| "What should I do this week?" | **AI coach** writes a 3-tip weekly plan | **Foundation Models** (Apple Intelligence, on-device). Falls back to coaching rules when Apple Intelligence isn't available |
| Keep a history | History saved as readable **JSON**, exportable with the share sheet | Codable |

Everything runs on the iPhone. No data is uploaded.

## Project structure

```
Stride/
├─ App/          StrideApp (entry point, tabs)
├─ Models/       Run, RunType, RunAnalysis, RunnerProfile (Codable) · Format helpers
├─ ML/           RunClassifier (Core ML) · MoodAnalyzer (Natural Language)
│                RacePredictor (regression) · AICoach (Foundation Models + rules)
├─ Analysis/     TrainingStats (weekly km, 80/20 balance…) · SampleData (the user story)
├─ Store/        RunStore (@Observable, single source of truth) · RunStorage (JSON file)
├─ Views/        Runs, Log a run (live AI preview), Run detail ("Why this type?"), Insights, Settings
└─ Resources/    RunTypeClassifier.mlmodel
StrideTests/     Swift Testing unit tests (features, Core ML, NL, regression, stats, coach, JSON)
StrideUITests/   XCTest UI tests
MLTraining/      Training data (CSV) and the script that made the Core ML model (not part of the app)
```

## How the Core ML model was made

`MLTraining/train_run_classifier.py` creates 3,000 labelled example runs from standard coaching guidelines (heart-rate zones as % of max heart rate, typical duration and perceived effort, with overlap and noise for runners of different fitness). It trains a **Random Forest** (40 trees) and exports it as a Core ML **Tree Ensemble Classifier**.

- Inputs: `distanceKm`, `durationMin`, `relativePace` (pace ÷ your usual pace), `heartRatePercent` (avg HR ÷ max HR), `effort` (1–10)
- Outputs: `runType` (String) and `runTypeProbability` (probability for each type)
- Accuracy on held-out runs: about **94%**. Most mistakes are between Tempo and Intervals, which also overlap in real life.

No heart-rate monitor? The app estimates heart rate from effort (0.55 + 0.04 × effort), using the same rule as the training data.

### Retrain it yourself with Create ML (good classroom activity)

1. In Xcode: **Xcode → Open Developer Tool → Create ML**. Choose **Tabular Classification**.
2. Training data: `MLTraining/run_types.csv`. Target: `runType`. Features: the other five columns.
3. Click **Train**, then compare the evaluation accuracy with ours.
4. Export the model as `RunTypeClassifier.mlmodel` and replace the file in `Stride/Resources/`. Keep the same name and the input/output names, so no code changes are needed.

## Ideas to discuss with students

- **Rules vs. learning:** `RuleBasedClassifier` (hand-written rules) vs. the trained model. Which one handles in-between runs better?
- **Bias in data:** the training runs are generated from guidelines for adult runners. Who might the model be unfair to?
- **Honest AI:** the app always shows the model's confidence and says when it is using rules instead of AI.
