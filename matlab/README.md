# MathWorks SIH26038: MATLAB & Simulink Telemedicine Simulation

This folder contains the official MATLAB script and Simulink workflow model for **Problem Statement SIH26038 (MathWorks)**:
> *"Model the telemedicine screening pipeline in Simulink — image acquisition rates, bandwidth constraints, processing throughput, and review capacity — to optimize resource allocation for district-level programs serving 100,000+ patients annually."*

---

## 📂 Contents

1. **`simulink_telemedicine_model.m`**:
   - Complete district-level queuing network and bandwidth simulation script.
   - Models **100,000 patients annually** across 20 rural PHCs and 5 mobile vision vans.
   - Evaluates rural cellular upload bottlenecks (384 kbps uplink) vs. on-device Edge AI triage.
   - Computes ophthalmologist workload reduction ($<30$-second assisted review).
   - Generates engineering comparison plots and programmatically creates `simulink_telemedicine_district_model.slx`.

---

## 🚀 How to Run in MATLAB

1. Launch MATLAB (R2023a or newer recommended).
2. Ensure you have the following installed:
   - *MATLAB*
   - *Simulink* (optional, for `.slx` model diagram generation)
   - *Statistics and Machine Learning Toolbox*
3. Navigate to the `matlab/` directory:
   ```matlab
   cd('matlab');
   ```
4. Execute the simulation script:
   ```matlab
   simulink_telemedicine_model
   ```

---

## 📊 Key Engineering Findings (MathWorks Benchmark)

| Operational Parameter | Centralized Cloud (Upload All) | Our Edge AI Triage Pipeline | Impact / Savings |
|---|:---:|:---:|:---:|
| **Annual Cellular Data Footprint** | **1,125.0 GB** | **15.3 GB** | **98.6% Bandwidth Saved** |
| **Patient On-Site Turnaround Time** | **~1.85 minutes** | **~1.0 second** | **Immediate camp triage** |
| **Ophthalmologist Headcount Needed** | **14 full-time specialists** | **1 tele-ophthalmologist** | **14× Specialist Capacity** |
| **Queue Stability at 100k/year** | Unstable (Network choked) | **100% Stable ($<30$s review)** | District-scale feasible |
