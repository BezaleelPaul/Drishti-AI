"""Simulink district telemedicine simulation + MathWorks compliance tabs.

Extracted verbatim from demo/app.py lines 1652-1773.
"""

import streamlit as st

from src.simulation import DistrictSimulationParams, TelemedicineSimulinkEngine


def render_simulink_tab(tab) -> None:
    with tab:
        st.subheader("📡 Simulink District Telemedicine Screening Simulation")
        st.caption(
            "MathWorks SIH26038 Requirement #5: Modeling image acquisition rates, bandwidth bottlenecks, "
            "processing throughput, and specialist review capacity for 100,000+ patients annually."
        )

        col_sim_ctrl, col_sim_res = st.columns([1, 2])

        with col_sim_ctrl:
            st.markdown("#### ⚙️ District Simulation Parameters")
            sim_patients = st.slider("Annual Target Population", 50000, 250000, 100000, step=10000)
            sim_phcs = st.number_input(
                "Number of Rural PHCs Connected", min_value=5, max_value=50, value=20
            )
            sim_bandwidth = st.slider(
                "Average Rural Cellular Uplink (kbps)",
                128,
                2048,
                384,
                step=64,
                help="Represents 3G / congested 4G connectivity in rural camps.",
            )
            sim_doctors = st.slider("Assigned Tele-Ophthalmologists", 1, 10, 2)
            sim_assisted_time = st.slider("Assisted Review Time (<30s target)", 15, 60, 28, step=1)

            sim_params = DistrictSimulationParams(
                annual_target_patients=sim_patients,
                num_phcs=sim_phcs,
                rural_bandwidth_kbps=float(sim_bandwidth),
                num_tele_ophthalmologists=sim_doctors,
                assisted_review_time_sec=float(sim_assisted_time),
            )
            _sim_key = (
                sim_patients,
                sim_phcs,
                float(sim_bandwidth),
                sim_doctors,
                float(sim_assisted_time),
            )
            if st.session_state.get("_sim_key") == _sim_key and "_sim_report" in st.session_state:
                report = st.session_state._sim_report
            else:
                sim_engine = TelemedicineSimulinkEngine(sim_params)
                report = sim_engine.run_simulation()
                st.session_state._sim_key = _sim_key
                st.session_state._sim_report = report

        with col_sim_res:
            st.markdown("#### 📊 Simulation Results: Edge AI vs. Centralized Cloud")

            col_m1, col_m2, col_m3 = st.columns(3)
            col_m1.metric(
                "Bandwidth Reduction",
                f"{report.bandwidth_saved_pct:.1f}%",
                "Saved Cellular Traffic",
            )
            col_m2.metric(
                "Ophthalmologist Need",
                f"{report.doctors_needed_with_our_system:.0f} Doctor(s)",
                f"vs {report.doctors_needed_without_our_system:.0f} Traditional",
            )
            col_m3.metric(
                "On-Site Patient Latency",
                f"{report.avg_turnaround_time_edge_sec:.1f}s",
                f"vs {report.avg_turnaround_time_cloud_min:.1f}m Cloud",
            )

            # Comparative Data Chart
            st.markdown("##### 📈 Annual Data Upload Footprint (GB/Year)")
            st.bar_chart(
                {
                    "Centralized Cloud (Upload All)": report.cloud_total_data_uploaded_gb_annual,
                    "Our Edge AI Triage Pipeline": report.edge_total_data_uploaded_gb_annual,
                }
            )

            st.markdown("##### 👨‍⚕️ District Ophthalmologist Headcount Required")
            st.bar_chart(
                {
                    "Traditional Manual Screening": report.doctors_needed_without_our_system,
                    "With Our AI-Assisted Triage": report.doctors_needed_with_our_system,
                }
            )

            if report.queue_stable:
                st.success(
                    f"✅ **System Stability Verified:** Queue is STABLE. "
                    f"Daily tele-consultation capacity ({report.doctor_daily_review_capacity_assisted} cases/day) exceeds "
                    f"flagged intake ({report.daily_flagged_for_review} cases/day)."
                )
            else:
                st.error(
                    f"⛔ **System OVERLOADED:** flagged intake ({report.daily_flagged_for_review} cases/day) exceeds "
                    f"daily tele-consultation capacity ({report.doctor_daily_review_capacity_assisted} cases/day). "
                    "Add reviewers, extend hours, or narrow the screening target before go-live."
                )

            with st.expander("📄 View MATLAB / Simulink Code & Instructions"):
                st.markdown(
                    "MathWorks evaluators can execute the full `.m` script and generate the `.slx` model directly in MATLAB:\n"
                    "```matlab\n"
                    "cd('matlab');\n"
                    "simulink_telemedicine_model;\n"
                    "```"
                )
                st.caption("File path: `matlab/simulink_telemedicine_model.m`")


def render_specs_tab(tab) -> None:
    with tab:
        st.subheader("📋 SIH26038 Problem Statement Compliance Checklist")
        st.markdown("""
        | # | MathWorks Requirement | Our Technical Implementation | Status |
        |---|---|---|:---:|
        | **1** | **Image Quality Assessment & Adaptive Enhancement** | Model 1 evaluates focus, illumination, and FOV; Adaptive CLAHE, background illumination normalization & bilateral denoising implemented in `src/quality/enhancer.py`. | **100% DONE** |
        | **2** | **Retinal Structure Segmentation** | Optic disc, fovea center, blood vessel tree, and microaneurysm candidate morphology implemented in `src/segmentation/structure_segmenter.py`. | **100% DONE** |
        | **3** | **DR Severity Grading (0–4)** | 5-class transfer learning CNN on APTOS 2019 dataset with referable DR threshold (Grade ≥ 2) and class-weighted loss in `src/classification/classifier.py`. | **100% DONE** |
        | **4** | **Explainability Module (<30s Workflow)** | Grad-CAM activation maps, calibrated confidence reporting, and combined anatomical lesion overlays enabling ophthalmologist validation in under 30 seconds. | **100% DONE** |
        | **5** | **Simulink Workflow Simulation (100k Patients)** | District telemedicine queuing network modeling bandwidth, throughput, and specialist capacity in `src/simulation/telemedicine_sim.py` and `matlab/simulink_telemedicine_model.m`. | **100% DONE** |
        """)
