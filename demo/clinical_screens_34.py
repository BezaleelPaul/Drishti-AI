"""Clinical wizard screens 3 (AI triage & audit) and 4 (referral hub).

Extracted verbatim from demo/app.py lines 933-1365.
"""

import json
import os
import uuid as _uuid

import streamlit as st
from PIL import Image

from src.pipeline.schema import QualityGrade
from src.reporting import (
    export_abdm_fhir_diagnostic_report,
    generate_clinical_screening_pdf,
)


def render_screen_3(gate_config, prep, router, enhancer, segmenter) -> None:
    """Multimodal AI Triage & Clinical Audit (original lines 933-1132)."""
    record, seg_res, img_np, image_to_process = (
        prep.record,
        prep.seg_res,
        prep.img_np,
        prep.image_to_process,
    )
    enable_segmentation = gate_config.enable_segmentation
    enable_clahe_enhancer = gate_config.enable_clahe_enhancer

    st.subheader("Stage 3: Multimodal AI Triage & Clinical Audit (MathWorks Reqs 2, 3, 4)")
    st.caption(
        "Explainable severity classification, retinal structure segmentation, and <30s Grad-CAM heatmap."
    )
    _last_s = st.session_state.get("_last_infer_s")
    if _last_s is not None:
        st.caption(
            f"⏱ Last grading took {_last_s:.1f}s on Cloud CPU (real EfficientNetB0 + Grad-CAM++)."
        )

    # Executive Severity Verdict
    if record is not None and record.dr_prediction is not None:
        grade = record.dr_prediction.predicted_grade
        conf = record.dr_prediction.confidence
        dr_val = grade.value

        if dr_val >= 2:
            urgency = "HIGH RISK — Refer to District Hospital"
        elif dr_val == 1:
            urgency = "MILD RETINOPATHY — 6-Month Review"
        else:
            urgency = "NORMAL RETINA — Annual Routine Surveillance"

        st.markdown(
            f"""
        <div style="padding: 16px 20px; background: var(--secondary-background-color); border-left: 6px solid {"#DC2626" if dr_val >= 2 else ("#D97706" if dr_val == 1 else "#16A34A")}; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.04);">
            <div style="font-size: 12px; font-weight: 700; text-transform: uppercase; color: {"#DC2626" if dr_val >= 2 else ("#D97706" if dr_val == 1 else "#16A34A")};">{urgency}</div>
            <div style="font-size: 24px; font-weight: 800; color: var(--text-color); margin: 4px 0;">{grade.name.replace("_", " ")} (Grade {dr_val}) • {conf * 100:.1f}% Confidence</div>
            <div style="font-size: 13px; opacity: 0.8;">Action: {"Refer to ophthalmologist" if record.dr_prediction.is_referable else "Routine annual rescreening"}</div>
        </div>
        """,
            unsafe_allow_html=True,
        )
    else:
        dr_val = None
        st.info("Disease prediction suppressed for ungradable scan.")

    # Lazy anatomy segmentation: display-only (overlay viewport,
    # biomarkers, PDF figure). Never affects grade/quality decisions,
    # so it runs on first view of this screen instead of at grade time.
    if (
        enable_segmentation
        and img_np is not None
        and record is not None
        and record.quality_grade != QualityGrade.BAD
        and (
            seg_res is None or st.session_state.get("_seg_key") != st.session_state.get("_inf_key")
        )
    ):
        try:
            with st.spinner("🧬 Extracting retinal structures (OD, fovea, vessels)…"):
                seg_res = segmenter.segment_structures(img_np)
            st.session_state._seg_res = seg_res
            st.session_state._seg_key = st.session_state.get("_inf_key")
        except Exception as e:
            st.warning(f"Structure segmentation unavailable for this capture: {e}")
            seg_res = None

    # 3-Panel Inspection Viewport
    st.markdown("### 🔬 Multimodal Retinal Inspection Viewport")
    v_col1, v_col2, v_col3 = st.columns(3)

    with v_col1:
        if image_to_process is not None:
            st.image(
                image_to_process,
                caption="Captured Retinal Photograph (Original)",
                width="stretch",
            )
            st.caption(
                "🔒 **Section 20 Compliance:** Unaltered original pixel data preserved for audit."
            )
            if enable_clahe_enhancer and img_np is not None:
                with st.expander("✨ View Adaptive CLAHE (Req 1)"):
                    try:
                        enhanced_np = enhancer.enhance_borderline_image(img_np)
                        st.image(
                            enhanced_np,
                            caption="Adaptive CLAHE + Denoising",
                            width="stretch",
                        )
                    except Exception:
                        st.warning("Enhancement unavailable for this capture.")

    with v_col2:
        if seg_res and seg_res.annotated_overlay is not None:
            st.image(
                seg_res.annotated_overlay,
                caption="Anatomical Landmarks (Req 2): OD (Yellow), Fovea (Blue), Vessels (Cyan)",
                width="stretch",
            )
            st.caption(
                f"OD at ({seg_res.optic_disc_center[0]}, {seg_res.optic_disc_center[1]}), Fovea at ({seg_res.fovea_center[0]}, {seg_res.fovea_center[1]})"
            )
        else:
            st.info("Structure segmentation suppressed for ungradable capture.")

    with v_col3:
        # Lazy Grad-CAM: the heatmap was deferred at grade time for speed
        # and is generated on first view of this audit screen, then cached
        # per (image, gate config) alongside the screening record.
        _gc_key = st.session_state.get("_inf_key")
        _gc = st.session_state.get("_gradcam")
        if _gc is None or st.session_state.get("_gradcam_key") != _gc_key:
            _gc = None
            if record is not None and record.dr_prediction is not None and img_np is not None:
                try:
                    with st.spinner(
                        "🔥 Generating Grad-CAM explainability (one-time per capture)…"
                    ):
                        _gc = router.gradcam_explainer.generate_heatmap(
                            image_input=img_np,
                            target_grade=record.dr_prediction.predicted_grade,
                            classifier=router.dr_classifier,
                        )
                    st.session_state._gradcam = _gc
                    st.session_state._gradcam_key = _gc_key
                except Exception as e:
                    st.warning(f"Grad-CAM unavailable for this capture: {e}")
                    _gc = None
        if _gc is not None and _gc.heatmap_generated:
            st.image(
                _gc.heatmap_array,
                caption="Grad-CAM Activation Heatmap (Req 4)",
                width="stretch",
            )
            st.caption(
                f"Gradient backpropagation on `{_gc.target_layer}` (MathWorks constraint: <30s)."
            )
        elif record is None or record.dr_prediction is None:
            st.info("Grad-CAM suppressed on ungradable capture.")
        else:
            st.info("Grad-CAM deferred — revisit this screen to generate it.")

    # Quantitative Biomarkers
    if seg_res and record and record.quality_grade != QualityGrade.BAD:
        st.divider()
        st.markdown("### 📊 Quantitative Retinal Biomarkers & CSME Risk")
        b_col1, b_col2, b_col3, b_col4 = st.columns(4)
        b_col1.metric("Microaneurysms", f"{len(seg_res.microaneurysm_candidates)}")
        b_col2.metric("Vessel Density", f"{seg_res.vessel_density_pct}%")
        _fovea = seg_res.min_fovea_distance_px
        b_col3.metric("Fovea Proximity", f"{_fovea:.0f} px" if _fovea is not None else "N/A")
        b_col4.metric("CSME Risk", seg_res.csme_risk.split()[0])

    # Bilingual Rural Patient Action Card
    st.divider()
    st.subheader("🗣️ Rural Patient Action Card / रोगी परामर्श कार्ड")
    if dr_val is not None and dr_val >= 2:
        card_type = st.error
        card_title = "🚨 HIGH URGENCY / उच्च प्राथमिकता — DISTRICT HOSPITAL REFERRAL"
        eng_msg = "Signs of active diabetic retinopathy detected. You require specialized eye examination within 2 weeks at the District Hospital to prevent permanent vision loss."
        hin_msg = "आपकी आँखों के पर्दे पर मधुमेह (शुगर) के गंभीर लक्षण मिले हैं। आँखों की रोशनी बचाने के लिए कृपया अगले 2 सप्ताह में जिला अस्पताल के नेत्र विशेषज्ञ से संपर्क करें।"
    elif dr_val == 1:
        card_type = st.warning
        card_title = "🟡 MILD RETINAL CHANGES / प्रारंभिक लक्षण — MONITOR SUGAR & BP"
        eng_msg = "Early diabetic changes detected. Maintain strict control of blood sugar and blood pressure. Re-screen your eyes in 6 months."
        hin_msg = "आँखों में मधुमेह के शुरुआती हल्के लक्षण हैं। अपनी शुगर और बीपी को पूरी तरह नियंत्रित रखें और 6 महीने बाद पुनः आँखों की जांच कराएं।"
    elif dr_val == 0:
        card_type = st.success
        card_title = "🟢 NORMAL SCREENING / सामान्य — ROUTINE ANNUAL RESCREENING"
        eng_msg = "No diabetic eye damage found today. Continue prescribed medication, healthy diet, and undergo your next retinal screen in 12 months."
        hin_msg = "आज की जांच में आँखों में कोई खराबी नहीं पाई गई। नियमित दवाएं लेते रहें और 1 वर्ष बाद दोबारा वार्षिक जांच अवश्य कराएं।"
    else:
        card_type = st.info
        card_title = "🔄 RECAPTURE NEEDED / पुनः फोटो आवश्यक — UNCLEAR IMAGE"
        eng_msg = "Retinal photo was unclear or out of focus. A re-capture with proper dark-room dilation is required."
        hin_msg = (
            "फोटो धुंधली होने के कारण जांच पूरी नहीं हो सकी। कृपया कमरे में अंधेरा करके पुनः साफ फोटो खिंचवाएं।"
        )

    with card_type(card_title):
        st.write(f"**English:** {eng_msg}")
        st.write(f"**हिंदी:** {hin_msg}")

    st.divider()
    s3_b1, _, s3_b3 = st.columns([1, 1, 1.2])
    with s3_b1:
        if st.button("← Back to Retinal Capture", width="stretch"):
            st.session_state.wizard_step = 2
            st.rerun()
    with s3_b3:
        if st.button(
            "Proceed to Referral & Dispatch 📄 →",
            type="primary",
            width="stretch",
        ):
            if dr_val is None:
                st.warning(
                    "No DR grade was produced for this capture (image ungradable). "
                    "Recapture first — referral documents cannot be generated without a grade."
                )
            else:
                st.session_state.wizard_step = 4
                st.rerun()


def render_screen_4(prep) -> None:
    """Tele-Ophthalmologist Sign-Off & Patient Referral Hub (lines 1137-1365)."""
    record, seg_res, img_np = prep.record, prep.seg_res, prep.img_np
    patient_profile, assessment = prep.patient_profile, prep.assessment

    st.subheader("Stage 4: Tele-Ophthalmologist Sign-Off & Patient Referral Hub")
    st.caption("1-Click SMS dispatch, printable A4 clinical dossier, and ABDM HL7 FHIR export.")

    # Re-gate: top-bar config (camera/threshold/recaptures) recomputes
    # `record` on every rerun, so a stored step-4 can go stale (e.g. GOOD
    # -> BAD after tightening). Never render the dispatch hub ungradable.
    if record is None or record.dr_prediction is None or record.quality_grade == QualityGrade.BAD:
        st.error(
            "Current capture is ungradable with the active settings "
            "(quality gate did not certify it). Referral documents are disabled — "
            "go back and recapture."
        )
        if st.button("← Back to Retinal Capture", width="stretch"):
            st.session_state.wizard_step = 2
            st.rerun()
        return

    dr_val = record.dr_prediction.predicted_grade.value if record.dr_prediction else None

    # Tele-Review Station
    st.markdown("#### 👨‍⚕️ Tele-Ophthalmologist Clinical Orders & Verification")
    doc_col1, doc_col2 = st.columns(2)
    with doc_col1:
        st.selectbox(
            "Physician Decision / Verification",
            [
                f"Confirm AI Grade ({'Grade ' + str(dr_val) if dr_val is not None else 'Ungradable - Recapture'})",
                "Override: Grade 0 (No DR)",
                "Override: Grade 1 (Mild NPDR)",
                "Override: Grade 2 (Moderate NPDR)",
                "Override: Grade 3 (Severe NPDR)",
                "Override: Grade 4 (Proliferative DR - Urgent PRP/Anti-VEGF)",
            ],
        )
        clinical_orders = st.multiselect(
            "Clinical Management Orders",
            [
                "Strict Glycemic Control (HbA1c target < 7.0%)",
                "Blood Pressure & Lipid Optimization",
                "Optical Coherence Tomography (OCT) for Macular Edema",
                "Urgent Intravitreal Anti-VEGF Therapy",
                "Pan-Retinal Photocoagulation (PRP Laser)",
                "Slit-Lamp Biomicroscopy",
                "Annual Rescreening (12 Months)",
            ],
            default=[
                "Strict Glycemic Control (HbA1c target < 7.0%)",
                "Annual Rescreening (12 Months)",
            ]
            if (dr_val == 0 or dr_val is None)
            else [
                "Strict Glycemic Control (HbA1c target < 7.0%)",
                "Optical Coherence Tomography (OCT) for Macular Edema",
            ],
        )

    with doc_col2:
        doctor_name = st.text_input(
            "Reviewing Specialist Name & Credentials",
            "Dr. S. Ramanathan, MS (Ophthalmology), Vitreo-Retinal Consultant",
        )
        doctor_notes = st.text_area(
            "Physician Clinical Notes",
            f"Tele-triaged at District Hub. Stage 1 Risk: {assessment.risk_level.value}. Image quality verified. Orders assigned.",
        )

    # Interactive SMS Dispatch
    st.divider()
    st.markdown("#### 📱 Patient SMS Referral Slip (Ayushman Bharat Gateway)")
    sms_col_inp, sms_col_btn = st.columns([2, 1])
    with sms_col_inp:
        patient_phone = st.text_input("Patient Mobile Number", "+91 98451 22340")
    with sms_col_btn:
        st.markdown("<div style='height: 28px;'></div>", unsafe_allow_html=True)
        if st.button(
            "📲 Send Live SMS Referral Slip",
            type="primary",
            width="stretch",
        ):
            st.toast(
                f"📋 SMS Referral Slip preview ready for {patient_phone} (demo — not actually sent; integrate National Health Gateway to send.)",
                icon="📲",
            )

    if dr_val is None:
        sms_status = "RE-CAPTURE REQUIRED — unclear image, no grade assigned"
    elif dr_val >= 2:
        sms_status = "HIGH URGENCY"
    else:
        sms_status = "ROUTINE CARE"
    sms_payload = (
        f"ELYTRIVA CAMP REFERRAL:\nPatient: {patient_profile.patient_id} ({patient_profile.age}y)\n"
        f"Status: {sms_status}\n"
        f"Orders: {', '.join(clinical_orders[:2]) if clinical_orders else 'Follow PHC lifestyle guidance'}\n"
        f"जिला अस्पताल नेत्र विभाग में संपर्क करें।"
    )
    st.code(sms_payload, language="text")

    # Official Downloads
    st.divider()
    st.markdown("#### 📄 Clinical Documentation & EMR Records")

    # Prepare PDF cache paths (repo-anchored; one stable file per session)
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pdf_cache_dir = os.path.join(project_root, "results", "pdf_cache")
    os.makedirs(pdf_cache_dir, exist_ok=True)
    if "_pdf_sess" not in st.session_state:
        st.session_state._pdf_sess = _uuid.uuid4().hex[:8]
    _sess = st.session_state._pdf_sess
    orig_cache_path = os.path.join(pdf_cache_dir, f"orig_{_sess}.jpg")
    annot_cache_path = os.path.join(pdf_cache_dir, f"annot_{_sess}.jpg")

    try:
        if img_np is not None:
            Image.fromarray(img_np).save(orig_cache_path)
        if seg_res and seg_res.annotated_overlay is not None:
            Image.fromarray(seg_res.annotated_overlay).save(annot_cache_path)
        elif record and record.gradcam_result and record.gradcam_result.heatmap_array is not None:
            Image.fromarray(record.gradcam_result.heatmap_array).save(annot_cache_path)
        elif (
            st.session_state.get("_gradcam_key") == st.session_state.get("_inf_key")
            and st.session_state.get("_gradcam") is not None
            and st.session_state._gradcam.heatmap_array is not None
        ):
            # Heatmap was generated on demand on the Step 3 audit screen.
            Image.fromarray(st.session_state._gradcam.heatmap_array).save(annot_cache_path)
        else:
            annot_cache_path = None
    except Exception:
        orig_cache_path = None
        annot_cache_path = None

    patient_dict = {
        "patient_id": patient_profile.patient_id,
        "age": patient_profile.age,
        "gender": patient_profile.gender,
        "bmi": patient_profile.bmi,
        "diabetes_status": assessment.diabetes_status.value,
        "risk_score": assessment.risk_score,
    }
    biomarker_dict = {
        "microaneurysm_count": len(seg_res.microaneurysm_candidates) if seg_res else None,
        "vessel_density_pct": seg_res.vessel_density_pct if seg_res else None,
        "csme_risk": seg_res.csme_risk if seg_res else "UNGRADABLE",
        "min_fovea_distance_px": seg_res.min_fovea_distance_px if seg_res else None,
    }

    _orders_key = tuple(sorted(clinical_orders)) if clinical_orders else ()
    _pdf_key = (st.session_state.get("_inf_key"), doctor_name, doctor_notes, _orders_key)
    if st.session_state.get("_pdf_key") == _pdf_key and "_pdf_data" in st.session_state:
        pdf_data = st.session_state._pdf_data
        fhir_data_str = st.session_state._fhir_data_str
    else:
        # Evidence-linked criteria section for the report (advisory; explicit
        # absence when the chain cannot be built — never fabricated).
        criteria_evaluation = None
        grading_policy_info = None
        disagreement_info = None
        if record is not None and img_np is not None:
            seg_src = seg_res or getattr(record, "reassessment_structures", None)
            if seg_src is not None:
                from src.services.evidence_service import build_evidence_payload

                extension = build_evidence_payload(
                    img_np,
                    seg_src,
                    cnn_grade=record.dr_prediction.predicted_grade.value
                    if record.dr_prediction
                    else None,
                )
                if extension is not None:
                    criteria_evaluation = extension["criteria_evaluation"]
                    grading_policy_info = extension["grading_policy"]
                    dis_obj = extension.get("_disagreement_obj")
                    if dis_obj is not None:
                        disagreement_info = {
                            "status": dis_obj.status.value,
                            "summary": dis_obj.summary(),
                        }

        pdf_data = generate_clinical_screening_pdf(
            patient_data=patient_dict,
            screening_record=record,
            biomarkers=biomarker_dict,
            fundus_image_path=orig_cache_path,
            annotated_image_path=annot_cache_path,
            doctor_notes=doctor_notes,
            doctor_signature_name=doctor_name,
            doctor_action=", ".join(clinical_orders) if clinical_orders else "Routine Care",
            criteria_evaluation=criteria_evaluation,
            grading_policy=grading_policy_info,
            disagreement=disagreement_info,
        )

        fhir_json = export_abdm_fhir_diagnostic_report(
            patient_data=patient_dict,
            screening_record=record,
            biomarkers=biomarker_dict,
            doctor_name=doctor_name,
            doctor_action=", ".join(clinical_orders) if clinical_orders else "Routine Care",
        )
        fhir_data_str = json.dumps(fhir_json, indent=2)
        st.session_state._pdf_key = _pdf_key
        st.session_state._pdf_data = pdf_data
        st.session_state._fhir_data_str = fhir_data_str

    dl_col1, dl_col2 = st.columns(2)
    # Sanitize free-text patient ID for download filenames (mirror FHIR rules).
    safe_pid = (
        "".join(
            c if (c.isalnum() or c in ("-", ".")) else "-" for c in str(patient_profile.patient_id)
        ).strip("-.")
        or "patient"
    )
    with dl_col1:
        st.download_button(
            label="📥 Download Official Hospital Screening PDF (Printable A4)",
            data=pdf_data,
            file_name=f"DR_Screening_Report_{safe_pid}.pdf",
            mime="application/pdf",
            width="stretch",
        )
    with dl_col2:
        st.download_button(
            label="🌐 Download ABDM / FHIR R4 JSON-LD Record",
            data=fhir_data_str,
            file_name=f"ABDM_FHIR_DiagnosticReport_{safe_pid}.json",
            mime="application/json",
            width="stretch",
        )

    with st.expander("🔍 View Raw ABDM / FHIR R4 DiagnosticReport JSON"):
        st.json(fhir_json)

    # Navigation Bar
    st.divider()
    s4_b1, _, s4_b3 = st.columns([1, 1, 1.2])
    with s4_b1:
        if st.button("← Back to AI Triage Results", width="stretch"):
            st.session_state.wizard_step = 3
            st.rerun()
    with s4_b3:
        if st.button("➕ Screen Next Patient", type="primary", width="stretch"):
            st.session_state.wizard_step = 1
            st.rerun()
