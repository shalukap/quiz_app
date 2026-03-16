# Quiz App — Flutter Project

A Flutter quiz app with 4 screens built from Stitch designs.

## Screens & Navigation

```
Login → Grade Selection → Subject Selection → MCQ Quiz
```

## Setup Instructions

### Step 1 — Initialize the project (one-time only)

Open a terminal inside the `quiz_app` folder and run:

```bash
flutter create --project-name quiz_app --org com.quizbank .
```

This generates the missing platform folders (android/, ios/, web/, etc.).

### Step 2 — Install dependencies

```bash
flutter pub get
```

### Step 3 — Run the app

Connect an Android device (or start an emulator) and run:

```bash
flutter run
```

Or to run on Chrome (web):

```bash
flutter run -d chrome
```

## Project Structure

```
quiz_app/
├── pubspec.yaml
└── lib/
    ├── main.dart                          ← App entry + routes
    └── screens/
        ├── login_screen.dart              ← Login page
        ├── grade_selection_screen.dart    ← Pick grade (1–13)
        ├── subject_selection_screen.dart  ← Pick subject
        └── mcq_screen.dart               ← MCQ quiz
```
