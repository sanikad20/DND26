# Centralized CFPZA

> A centralized digital wellness and occupational stress assessment platform that combines behavioral signals, occupational factors, machine learning, and personalized insights to identify burnout and stress risks.

---

## 📌 Overview

**Centralized CFPZA** is a full-stack wellness and stress-monitoring platform designed to provide a unified view of an individual's digital behavior, occupational stress, recovery patterns, and burnout risk.

The system combines:

- Digital burnout detection
- Occupational stress assessment
- Behavioral and lifestyle indicators
- Machine learning-based predictions
- Personalized assessment results
- Historical stress tracking
- Stress contributors and protective factors
- A Flutter-based mobile frontend
- A FastAPI-based backend
- Firebase-based user identification and integration

The project is designed as a modular system where different wellness signals can be processed independently while being presented through a centralized platform.

---

# 🎯 Objectives

The main objectives of Centralized CFPZA are:

1. Detect early indicators of digital burnout.
2. Assess occupational stress using work and recovery-related factors.
3. Analyze behavioral patterns associated with stress and burnout.
4. Provide machine-learning-based risk predictions.
5. Identify major contributors to an individual's stress.
6. Identify protective factors that may reduce stress.
7. Maintain historical assessment data.
8. Provide personalized insights through a mobile interface.
9. Create a centralized architecture that can support additional wellness modules in the future.

---

# 🏗️ System Architecture

The project follows a client-server architecture.

```text
                    ┌─────────────────────────┐
                    │     Flutter Frontend    │
                    │                         │
                    │  • Login / Register     │
                    │  • Dashboard            │
                    │  • Digital Burnout      │
                    │  • Occupational Stress  │
                    │  • Predictions          │
                    │  • History              │
                    └────────────┬────────────┘
                                 │
                                 │ REST API
                                 ▼
                    ┌─────────────────────────┐
                    │      FastAPI Backend    │
                    │                         │
                    │  • Authentication       │
                    │  • Prediction APIs      │
                    │  • Stress Assessment    │
                    │  • History APIs         │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
       ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
       │ ML Models   │    │ Assessment  │    │  Database   │
       │             │    │   Engine    │    │             │
       │ Burnout     │    │ Occupational│    │ User data   │
       │ LSTM        │    │   Stress    │    │ Assessments │
       │ ML Models   │    │   Analysis  │    │ History     │
       └─────────────┘    └─────────────┘    └─────────────┘
```

---

# 🧪 Running the backend tests

```bash
cd Backend
pip install -r requirements-dev.txt
pytest
```

- Occupational Stress tests (personas, contributor direction, context layer,
  plan rules, wording guard, weekly trend) run against a throwaway database —
  `users.db` is never touched.
- The Digital Burnout regression tests boot the full app and need `torch` and
  `tensorflow` installed; they are skipped automatically if those can't load.
