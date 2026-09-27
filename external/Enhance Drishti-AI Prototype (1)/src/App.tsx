import { useState, createContext, useContext } from "react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Screen =
  | "dashboard" | "register" | "capture" | "ai-analysis"
  | "ai-result" | "specialist" | "referral" | "report"
  | "history" | "offline-queue" | "help";

type StatusBadgeType =
  | "awaiting-ai" | "ai-complete" | "awaiting-specialist"
  | "specialist-verified" | "referral-required" | "offline";

type Lang = "en" | "kn" | "hi" | "te" | "ta";

// ─── Translations ─────────────────────────────────────────────────────────────

const T = {
  en: {
    // Nav
    nav_dashboard: "Dashboard", nav_history: "Patient History",
    nav_offline: "Offline Queue", nav_help: "Help",
    online: "Online", offline: "Offline",
    demo_data: "Demo Data — Not real clinical records",

    // Dashboard
    dash_title: "PHC Dashboard",
    dash_subtitle: "Drishti-AI · Rural Diabetic Retinopathy Screening",
    start_screening: "+ Start New Screening",
    todays_screenings: "Today's Screenings",
    awaiting_ai: "Awaiting AI",
    awaiting_specialist: "Awaiting Specialist",
    urgent_referrals: "Urgent Referrals",
    case_waiting: "case waiting to sync",
    captured_offline: "Captured offline. Will sync when connected.",
    view_arrow: "View →",
    recent_screenings: "Recent Screenings",
    col_patient: "Patient", col_date: "Date",
    col_ai_result: "AI Result", col_status: "Status",

    // Status badges
    badge_awaiting_ai: "Awaiting AI", badge_ai_complete: "AI Complete",
    badge_awaiting_specialist: "Awaiting Specialist", badge_verified: "Verified",
    badge_referral: "Referral Required", badge_offline: "Waiting to Sync",

    // Registration
    reg_title: "Patient Registration",
    reg_subtitle: "Enter the patient's details to begin screening.",
    basic_info: "Basic Information", medical_history: "Medical History",
    optional: "(Optional)",
    patient_name: "Patient Name", patient_id: "Patient ID",
    age: "Age", gender: "Gender", phone: "Phone Number",
    village: "Village / PHC", diabetes_duration: "Diabetes Duration",
    prev_eye: "Previous Eye Disease",
    gender_f: "Female", gender_m: "Male", gender_o: "Other",
    continue_btn: "Continue to Eye Screening →",
    privacy_note: "Patient information is used only for screening and referral.",

    // Capture
    capture_title: "Fundus Image Capture",
    select_eye: "Select Eye",
    right_eye: "Right Eye (OD)", left_eye: "Left Eye (OS)",
    viewfinder_msg: "Position patient's eye in the viewfinder",
    viewfinder_sub: "Align retina with the circle above",
    btn_capture: "📷 Capture Image", btn_upload: "⬆️ Upload Image",
    btn_proceed_ai: "Proceed to AI Screening →", btn_retake: "Retake Image",
    captured_label: "✓ Captured",

    // Quality
    quality_title: "Image Quality Check",
    retina_visible: "Retina visible", focus_ok: "Focus acceptable",
    brightness_ok: "Brightness acceptable",
    quality_label: "Image Quality:", quality_good: "GOOD",
    quality_fail: "Image quality is insufficient. Please capture another image.",

    // AI Analysis
    ai_title: "AI Screening",
    ai_subtitle: "Analyzing retinal image for signs of diabetic retinopathy",
    analyzing: "Analyzing…",
    step_quality: "Image Quality Check", step_retina: "Retina Detection",
    step_lesion: "Lesion Analysis", step_severity: "DR Severity Assessment",
    step_explain: "Explainability",
    ai_disclaimer: "AI screening supports specialist decision-making and does not replace specialist diagnosis.",
    btn_view_result: "View AI Result →",

    // AI Result
    ai_result_title: "AI Screening Result",
    awaiting_verif: "Awaiting specialist verification",
    ai_detected: "AI Detected",
    confidence: "Confidence", severity_scale: "Severity Scale",
    risk_level: "Risk Level:", risk_moderate: "MODERATE",
    ai_findings: "AI Findings",
    finding_ma: "Microaneurysms detected", finding_hm: "Haemorrhages detected",
    finding_ex: "Exudates detected", finding_iq: "Image quality: Good",
    xai_label: "Explainable AI — AI Attention Map",
    original_fundus: "Original Fundus Image", ai_attn: "AI Attention Map",
    heatmap_caption: "Highlighted regions show areas that influenced the AI prediction.",
    ai_note_label: "Note:", ai_note_text: "AI screening is decision support and does not replace specialist diagnosis.",
    btn_proceed_specialist: "Proceed to Specialist Review →",

    // Severity names
    sev_no_dr: "No DR", sev_mild: "Mild", sev_moderate: "Moderate",
    sev_severe: "Severe", sev_pdr: "PDR",
    sev_mild_npdr: "Mild NPDR", sev_moderate_npdr: "Moderate NPDR",
    sev_severe_npdr: "Severe NPDR",

    // Specialist
    specialist_title: "Specialist Review",
    ai_result_card: "AI Screening Result",
    fundus_images: "Fundus Images",
    why_result: "Why this result?",
    why_result_text: "The AI detected retinal features associated with diabetic retinopathy — microaneurysms, haemorrhages, and exudates. The highlighted regions indicate areas that contributed most to the Moderate NPDR prediction.",
    decision_label: "Specialist Decision",
    confirm_lbl: "Confirm AI Result", confirm_sub: "Agree with AI assessment",
    change_lbl: "Change Severity", change_sub: "Override AI assessment",
    reexamine_lbl: "Re-examination", reexamine_sub: "Image unclear or inconclusive",
    select_severity: "Select Corrected Severity",
    reason_lbl: "Reason for Re-examination",
    reason_ph: "e.g. Image obscured by media opacity",
    notes_lbl: "Specialist Notes",
    notes_ph: "Add clinical observations, reasoning, or instructions for the health worker…",
    btn_verify: "Verify & Submit →",

    // Referral
    referral_title: "Referral",
    referral_required: "Referral Required",
    sev_label: "Severity", urgency_label: "Urgency",
    referral_msg: "Specialist follow-up recommended within 4 weeks.",
    recommended_specialist: "Recommended Specialist",
    btn_send_referral: "Send Referral", btn_send_sms: "Send SMS to Patient",
    btn_continue_report: "Continue to Final Report →",

    // Report
    report_title: "Screening Report",
    report_header: "Drishti-AI Screening Report",
    demo_report: "Demo Report — Not a clinical document",
    patient_details: "Patient Details",
    key_findings: "Key Findings",
    grad_cam: "Grad-CAM attention map generated",
    sp_verified: "Specialist Verified",
    verified_msg: "AI result confirmed. Specialist follow-up recommended.",
    recommended_action: "Recommended Action",
    action_msg: "Refer patient to District Eye Care Centre within 4 weeks.",
    btn_download: "Download Report", btn_sms: "Send SMS",
    btn_new_screening: "+ Start New Screening",
    btn_more: "More Options", btn_hide: "Hide Options",
    technical_export: "Technical Export",

    // History
    history_title: "Patient History", screening_history: "Screening History",

    // Offline
    offline_title: "Offline Queue",
    offline_subtitle: "Images captured without internet are securely stored and synced when connectivity returns.",
    limited_connectivity: "Limited Connectivity",
    cases_waiting: "cases waiting to sync",
    btn_sync: "Sync Now", syncing: "Syncing…",
    sync_complete: "Sync Complete",
    sync1: "Images uploaded successfully",
    sync2: "AI analysis completed for all cases",
    sync3: "Cases available for specialist review",
    encrypt_note: "All images are encrypted before storage. Patient data is never transmitted unencrypted.",
    waiting_lbl: "Waiting",

    // Help
    help_title: "Help", help_subtitle: "Guidance for health workers using Drishti-AI.",
    help_q1: "How to capture a good fundus image",
    help_q2: "What does the AI result mean?",
    help_q3: "When should a patient be referred?",
    help_q4: "What happens without internet?",
    need_help: "Need more help?",
    need_help_msg: "Contact your PHC coordinator or the Drishti-AI support team.",

    // Workflow
    wf_patient: "Patient", wf_image: "Image", wf_ai: "AI",
    wf_specialist: "Specialist", wf_report: "Report",
  },

  kn: {
    nav_dashboard: "ಡ್ಯಾಶ್‌ಬೋರ್ಡ್", nav_history: "ರೋಗಿ ಇತಿಹಾಸ",
    nav_offline: "ಆಫ್‌ಲೈನ್ ಕ್ಯೂ", nav_help: "ಸಹಾಯ",
    online: "ಆನ್‌ಲೈನ್", offline: "ಆಫ್‌ಲೈನ್",
    demo_data: "ಡೆಮೊ ಡೇಟಾ — ನಿಜವಾದ ದಾಖಲೆ ಅಲ್ಲ",

    dash_title: "PHC ಡ್ಯಾಶ್‌ಬೋರ್ಡ್",
    dash_subtitle: "Drishti-AI · ಗ್ರಾಮೀಣ ಮಧುಮೇಹ ರೆಟಿನೋಪತಿ ತಪಾಸಣೆ",
    start_screening: "+ ಹೊಸ ತಪಾಸಣೆ ಆರಂಭಿಸಿ",
    todays_screenings: "ಇಂದಿನ ತಪಾಸಣೆ", awaiting_ai: "AI ನಿರೀಕ್ಷಣೆ",
    awaiting_specialist: "ತಜ್ಞರ ನಿರೀಕ್ಷಣೆ", urgent_referrals: "ತುರ್ತು ರೆಫರಲ್",
    case_waiting: "ಪ್ರಕರಣ ಸಿಂಕ್ ಆಗಲು ಕಾಯುತ್ತಿದೆ",
    captured_offline: "ಆಫ್‌ಲೈನ್ ತೆಗೆಯಲಾಗಿದೆ. ಸಂಪರ್ಕ ಬಂದಾಗ ಸಿಂಕ್ ಆಗುತ್ತದೆ.",
    view_arrow: "ನೋಡಿ →", recent_screenings: "ಇತ್ತೀಚಿನ ತಪಾಸಣೆ",
    col_patient: "ರೋಗಿ", col_date: "ದಿನಾಂಕ",
    col_ai_result: "AI ಫಲಿತಾಂಶ", col_status: "ಸ್ಥಿತಿ",

    badge_awaiting_ai: "AI ನಿರೀಕ್ಷಣೆ", badge_ai_complete: "AI ಪೂರ್ಣ",
    badge_awaiting_specialist: "ತಜ್ಞರ ನಿರೀಕ್ಷಣೆ", badge_verified: "ಪರಿಶೀಲಿಸಲಾಗಿದೆ",
    badge_referral: "ರೆಫರಲ್ ಅಗತ್ಯ", badge_offline: "ಸಿಂಕ್ ನಿರೀಕ್ಷಣೆ",

    reg_title: "ರೋಗಿ ನೋಂದಣಿ",
    reg_subtitle: "ತಪಾಸಣೆ ಆರಂಭಿಸಲು ರೋಗಿಯ ವಿವರ ನಮೂದಿಸಿ.",
    basic_info: "ಮೂಲ ಮಾಹಿತಿ", medical_history: "ವೈದ್ಯಕೀಯ ಇತಿಹಾಸ",
    optional: "(ಐಚ್ಛಿಕ)",
    patient_name: "ರೋಗಿಯ ಹೆಸರು", patient_id: "ರೋಗಿ ID",
    age: "ವಯಸ್ಸು", gender: "ಲಿಂಗ", phone: "ಫೋನ್ ಸಂಖ್ಯೆ",
    village: "ಗ್ರಾಮ / PHC", diabetes_duration: "ಮಧುಮೇಹ ಅವಧಿ",
    prev_eye: "ಹಿಂದಿನ ಕಣ್ಣಿನ ಕಾಯಿಲೆ",
    gender_f: "ಮಹಿಳೆ", gender_m: "ಪುರುಷ", gender_o: "ಇತರ",
    continue_btn: "ಕಣ್ಣಿನ ತಪಾಸಣೆಗೆ ಮುಂದುವರಿಸಿ →",
    privacy_note: "ರೋಗಿಯ ಮಾಹಿತಿ ತಪಾಸಣೆ ಮತ್ತು ರೆಫರಲ್‌ಗೆ ಮಾತ್ರ ಬಳಕೆ.",

    capture_title: "ಫಂಡಸ್ ಚಿತ್ರ ತೆಗೆಯಿರಿ",
    select_eye: "ಕಣ್ಣು ಆಯ್ಕೆ ಮಾಡಿ",
    right_eye: "ಬಲ ಕಣ್ಣು (OD)", left_eye: "ಎಡ ಕಣ್ಣು (OS)",
    viewfinder_msg: "ರೋಗಿಯ ಕಣ್ಣನ್ನು ವ್ಯೂಫೈಂಡರ್‌ನಲ್ಲಿ ಇಡಿ",
    viewfinder_sub: "ರೆಟಿನಾವನ್ನು ವೃತ್ತದೊಳಗೆ ಜೋಡಿಸಿ",
    btn_capture: "📷 ಚಿತ್ರ ತೆಗೆಯಿರಿ", btn_upload: "⬆️ ಚಿತ್ರ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ",
    btn_proceed_ai: "AI ತಪಾಸಣೆಗೆ ಮುಂದುವರಿಸಿ →", btn_retake: "ಮತ್ತೆ ತೆಗೆಯಿರಿ",
    captured_label: "✓ ತೆಗೆಯಲಾಗಿದೆ",

    quality_title: "ಚಿತ್ರ ಗುಣಮಟ್ಟ ಪರಿಶೀಲನೆ",
    retina_visible: "ರೆಟಿನಾ ಗೋಚರ", focus_ok: "ಫೋಕಸ್ ಸರಿ",
    brightness_ok: "ಪ್ರಕಾಶ ಸರಿ",
    quality_label: "ಚಿತ್ರ ಗುಣಮಟ್ಟ:", quality_good: "ಉತ್ತಮ",
    quality_fail: "ಚಿತ್ರ ಗುಣಮಟ್ಟ ಸಾಕಾಗುವುದಿಲ್ಲ. ಮತ್ತೊಮ್ಮೆ ತೆಗೆಯಿರಿ.",

    ai_title: "AI ತಪಾಸಣೆ",
    ai_subtitle: "ಮಧುಮೇಹ ರೆಟಿನೋಪತಿಗಾಗಿ ರೆಟಿನಾ ಚಿತ್ರ ವಿಶ್ಲೇಷಣೆ",
    analyzing: "ವಿಶ್ಲೇಷಿಸಲಾಗುತ್ತಿದೆ…",
    step_quality: "ಚಿತ್ರ ಗುಣಮಟ್ಟ ಪರಿಶೀಲನೆ", step_retina: "ರೆಟಿನಾ ಗುರುತಿಸುವಿಕೆ",
    step_lesion: "ಲೆಸಿಯನ್ ವಿಶ್ಲೇಷಣೆ", step_severity: "DR ತೀವ್ರತೆ ಮೌಲ್ಯಮಾಪನ",
    step_explain: "ವಿವರಣಾತ್ಮಕತೆ",
    ai_disclaimer: "AI ತಪಾಸಣೆ ತಜ್ಞರ ನಿರ್ಧಾರಕ್ಕೆ ಬೆಂಬಲ ನೀಡುತ್ತದೆ, ತಜ್ಞರ ರೋಗನಿರ್ಣಯ ಬದಲಿಸುವುದಿಲ್ಲ.",
    btn_view_result: "AI ಫಲಿತಾಂಶ ನೋಡಿ →",

    ai_result_title: "AI ತಪಾಸಣೆ ಫಲಿತಾಂಶ",
    awaiting_verif: "ತಜ್ಞರ ಪರಿಶೀಲನೆ ನಿರೀಕ್ಷಣೆ",
    ai_detected: "AI ಪತ್ತೆ ಹಚ್ಚಿದ್ದು",
    confidence: "ವಿಶ್ವಾಸ", severity_scale: "ತೀವ್ರತೆ ಮಟ್ಟ",
    risk_level: "ಅಪಾಯ ಮಟ್ಟ:", risk_moderate: "ಮಧ್ಯಮ",
    ai_findings: "AI ಆಧಾರಿತ ಸಂಶೋಧನೆ",
    finding_ma: "ಮೈಕ್ರೋಆನ್ಯೂರಿಸಂ ಪತ್ತೆ", finding_hm: "ರಕ್ತಸ್ರಾವ ಪತ್ತೆ",
    finding_ex: "ಎಕ್ಸ್‌ಯುಡೇಟ್ ಪತ್ತೆ", finding_iq: "ಚಿತ್ರ ಗುಣಮಟ್ಟ: ಉತ್ತಮ",
    xai_label: "ವಿವರಣಾತ್ಮಕ AI — AI ಗಮನ ನಕ್ಷೆ",
    original_fundus: "ಮೂಲ ಫಂಡಸ್ ಚಿತ್ರ", ai_attn: "AI ಗಮನ ನಕ್ಷೆ",
    heatmap_caption: "ಗುರುತಿಸಿದ ಪ್ರದೇಶಗಳು AI ಭವಿಷ್ಯವಾಣಿಗೆ ಕಾರಣ.",
    ai_note_label: "ಟಿಪ್ಪಣಿ:", ai_note_text: "AI ತಪಾಸಣೆ ನಿರ್ಧಾರ ಬೆಂಬಲ, ತಜ್ಞರ ರೋಗನಿರ್ಣಯ ಬದಲಿಸುವುದಿಲ್ಲ.",
    btn_proceed_specialist: "ತಜ್ಞರ ಪರಿಶೀಲನೆಗೆ ಮುಂದುವರಿಸಿ →",

    sev_no_dr: "DR ಇಲ್ಲ", sev_mild: "ಸಣ್ಣ", sev_moderate: "ಮಧ್ಯಮ",
    sev_severe: "ತೀವ್ರ", sev_pdr: "PDR",
    sev_mild_npdr: "ಸಣ್ಣ NPDR", sev_moderate_npdr: "ಮಧ್ಯಮ NPDR",
    sev_severe_npdr: "ತೀವ್ರ NPDR",

    specialist_title: "ತಜ್ಞರ ಪರಿಶೀಲನೆ",
    ai_result_card: "AI ತಪಾಸಣೆ ಫಲಿತಾಂಶ",
    fundus_images: "ಫಂಡಸ್ ಚಿತ್ರಗಳು",
    why_result: "ಈ ಫಲಿತಾಂಶ ಏಕೆ?",
    why_result_text: "AI ಮಧುಮೇಹ ರೆಟಿನೋಪತಿಗೆ ಸಂಬಂಧಿತ ರೆಟಿನಾ ಲಕ್ಷಣಗಳನ್ನು ಪತ್ತೆ ಮಾಡಿದೆ.",
    decision_label: "ತಜ್ಞರ ನಿರ್ಧಾರ",
    confirm_lbl: "AI ಫಲಿತಾಂಶ ದೃಢೀಕರಿಸಿ", confirm_sub: "AI ಮೌಲ್ಯಮಾಪನಕ್ಕೆ ಒಪ್ಪಿಗೆ",
    change_lbl: "ತೀವ್ರತೆ ಬದಲಿಸಿ", change_sub: "AI ಮೌಲ್ಯಮಾಪನ ಬದಲಿಸಿ",
    reexamine_lbl: "ಮರು ಪರೀಕ್ಷೆ", reexamine_sub: "ಚಿತ್ರ ಅಸ್ಪಷ್ಟ ಅಥವಾ ಅನಿರ್ಣಾಯಕ",
    select_severity: "ಸರಿಪಡಿಸಿದ ತೀವ್ರತೆ ಆಯ್ಕೆ ಮಾಡಿ",
    reason_lbl: "ಮರು ಪರೀಕ್ಷೆ ಕಾರಣ",
    reason_ph: "ಉದಾ. ಚಿತ್ರ ಅಸ್ಪಷ್ಟವಾಗಿದೆ",
    notes_lbl: "ತಜ್ಞರ ಟಿಪ್ಪಣಿ",
    notes_ph: "ಕ್ಲಿನಿಕಲ್ ವೀಕ್ಷಣೆ ಅಥವಾ ಆರೋಗ್ಯ ಕಾರ್ಯಕರ್ತರಿಗೆ ಸೂಚನೆ ಸೇರಿಸಿ…",
    btn_verify: "ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಸಲ್ಲಿಸಿ →",

    referral_title: "ರೆಫರಲ್",
    referral_required: "ರೆಫರಲ್ ಅಗತ್ಯ",
    sev_label: "ತೀವ್ರತೆ", urgency_label: "ತುರ್ತು",
    referral_msg: "4 ವಾರಗಳಲ್ಲಿ ತಜ್ಞರ ಅನುಸರಣೆ ಶಿಫಾರಸ್ಸು.",
    recommended_specialist: "ಶಿಫಾರಸ್ಸು ಮಾಡಿದ ತಜ್ಞರು",
    btn_send_referral: "ರೆಫರಲ್ ಕಳುಹಿಸಿ", btn_send_sms: "ರೋಗಿಗೆ SMS ಕಳುಹಿಸಿ",
    btn_continue_report: "ಅಂತಿಮ ವರದಿಗೆ ಮುಂದುವರಿಸಿ →",

    report_title: "ತಪಾಸಣೆ ವರದಿ",
    report_header: "Drishti-AI ತಪಾಸಣೆ ವರದಿ",
    demo_report: "ಡೆಮೊ ವರದಿ — ಕ್ಲಿನಿಕಲ್ ದಾಖಲೆ ಅಲ್ಲ",
    patient_details: "ರೋಗಿ ವಿವರ",
    key_findings: "ಪ್ರಮುಖ ಸಂಶೋಧನೆ",
    grad_cam: "Grad-CAM ಗಮನ ನಕ್ಷೆ ಸಿದ್ಧ",
    sp_verified: "ತಜ್ಞರ ಪರಿಶೀಲನೆ ಆಗಿದೆ",
    verified_msg: "AI ಫಲಿತಾಂಶ ದೃಢೀಕರಿಸಲಾಗಿದೆ. ತಜ್ಞರ ಅನುಸರಣೆ ಶಿಫಾರಸ್ಸು.",
    recommended_action: "ಶಿಫಾರಸ್ಸು ಮಾಡಿದ ಕ್ರಮ",
    action_msg: "ರೋಗಿಯನ್ನು 4 ವಾರಗಳಲ್ಲಿ ಜಿಲ್ಲಾ ಕಣ್ಣು ಆಸ್ಪತ್ರೆಗೆ ರೆಫರ್ ಮಾಡಿ.",
    btn_download: "ವರದಿ ಡೌನ್‌ಲೋಡ್", btn_sms: "SMS ಕಳುಹಿಸಿ",
    btn_new_screening: "+ ಹೊಸ ತಪಾಸಣೆ ಆರಂಭಿಸಿ",
    btn_more: "ಇನ್ನಷ್ಟು ಆಯ್ಕೆ", btn_hide: "ಮರೆಮಾಡಿ",
    technical_export: "ತಾಂತ್ರಿಕ ರಫ್ತು",

    history_title: "ರೋಗಿ ಇತಿಹಾಸ", screening_history: "ತಪಾಸಣೆ ಇತಿಹಾಸ",

    offline_title: "ಆಫ್‌ಲೈನ್ ಕ್ಯೂ",
    offline_subtitle: "ಅಂತರ್ಜಾಲ ಇಲ್ಲದೆ ತೆಗೆದ ಚಿತ್ರಗಳು ಸುರಕ್ಷಿತವಾಗಿ ಸಂಗ್ರಹಿಸಲಾಗಿದೆ.",
    limited_connectivity: "ಸೀಮಿತ ಸಂಪರ್ಕ",
    cases_waiting: "ಪ್ರಕರಣ ಸಿಂಕ್ ನಿರೀಕ್ಷಣೆ",
    btn_sync: "ಈಗ ಸಿಂಕ್ ಮಾಡಿ", syncing: "ಸಿಂಕ್ ಆಗುತ್ತಿದೆ…",
    sync_complete: "ಸಿಂಕ್ ಪೂರ್ಣ",
    sync1: "ಚಿತ್ರಗಳು ಅಪ್‌ಲೋಡ್ ಆಗಿವೆ",
    sync2: "ಎಲ್ಲ ಪ್ರಕರಣಗಳಿಗೆ AI ವಿಶ್ಲೇಷಣೆ ಪೂರ್ಣ",
    sync3: "ತಜ್ಞರ ಪರಿಶೀಲನೆಗೆ ಪ್ರಕರಣ ಸಿದ್ಧ",
    encrypt_note: "ಎಲ್ಲ ಚಿತ್ರಗಳು ಸಂಗ್ರಹಿಸುವ ಮೊದಲು ಎನ್‌ಕ್ರಿಪ್ಟ್ ಆಗುತ್ತದೆ.",
    waiting_lbl: "ನಿರೀಕ್ಷಣೆ",

    help_title: "ಸಹಾಯ", help_subtitle: "Drishti-AI ಬಳಸುವ ಆರೋಗ್ಯ ಕಾರ್ಯಕರ್ತರಿಗೆ ಮಾರ್ಗದರ್ಶನ.",
    help_q1: "ಉತ್ತಮ ಫಂಡಸ್ ಚಿತ್ರ ಹೇಗೆ ತೆಗೆಯಬೇಕು",
    help_q2: "AI ಫಲಿತಾಂಶ ಏನನ್ನು ಅರ್ಥೈಸುತ್ತದೆ?",
    help_q3: "ರೋಗಿಯನ್ನು ಯಾವಾಗ ರೆಫರ್ ಮಾಡಬೇಕು?",
    help_q4: "ಅಂತರ್ಜಾಲ ಇಲ್ಲದಿದ್ದರೆ ಏನಾಗುತ್ತದೆ?",
    need_help: "ಇನ್ನಷ್ಟು ಸಹಾಯ ಬೇಕೇ?",
    need_help_msg: "ನಿಮ್ಮ PHC ಸಮನ್ವಯಕ ಅಥವಾ Drishti-AI ಬೆಂಬಲ ತಂಡವನ್ನು ಸಂಪರ್ಕಿಸಿ.",

    wf_patient: "ರೋಗಿ", wf_image: "ಚಿತ್ರ", wf_ai: "AI",
    wf_specialist: "ತಜ್ಞರು", wf_report: "ವರದಿ",
  },

  hi: {
    nav_dashboard: "डैशबोर्ड", nav_history: "रोगी इतिहास",
    nav_offline: "ऑफ़लाइन कतार", nav_help: "सहायता",
    online: "ऑनलाइन", offline: "ऑफ़लाइन",
    demo_data: "डेमो डेटा — वास्तविक रिकॉर्ड नहीं",

    dash_title: "PHC डैशबोर्ड",
    dash_subtitle: "Drishti-AI · ग्रामीण मधुमेह रेटिनोपैथी जाँच",
    start_screening: "+ नई जाँच शुरू करें",
    todays_screenings: "आज की जाँचें", awaiting_ai: "AI प्रतीक्षा",
    awaiting_specialist: "विशेषज्ञ प्रतीक्षा", urgent_referrals: "तत्काल रेफरल",
    case_waiting: "मामला सिंक के लिए प्रतीक्षा",
    captured_offline: "ऑफ़लाइन लिया गया। कनेक्शन मिलने पर सिंक होगा।",
    view_arrow: "देखें →", recent_screenings: "हालिया जाँचें",
    col_patient: "रोगी", col_date: "तिथि",
    col_ai_result: "AI परिणाम", col_status: "स्थिति",

    badge_awaiting_ai: "AI प्रतीक्षा", badge_ai_complete: "AI पूर्ण",
    badge_awaiting_specialist: "विशेषज्ञ प्रतीक्षा", badge_verified: "सत्यापित",
    badge_referral: "रेफरल आवश्यक", badge_offline: "सिंक प्रतीक्षा",

    reg_title: "रोगी पंजीकरण",
    reg_subtitle: "जाँच शुरू करने के लिए रोगी का विवरण दर्ज करें।",
    basic_info: "बुनियादी जानकारी", medical_history: "चिकित्सा इतिहास",
    optional: "(वैकल्पिक)",
    patient_name: "रोगी का नाम", patient_id: "रोगी ID",
    age: "आयु", gender: "लिंग", phone: "फ़ोन नंबर",
    village: "गाँव / PHC", diabetes_duration: "मधुमेह अवधि",
    prev_eye: "पिछली आँख की बीमारी",
    gender_f: "महिला", gender_m: "पुरुष", gender_o: "अन्य",
    continue_btn: "आँख की जाँच के लिए जारी रखें →",
    privacy_note: "रोगी की जानकारी केवल जाँच और रेफरल के लिए उपयोग की जाती है।",

    capture_title: "फंडस छवि कैप्चर",
    select_eye: "आँख चुनें",
    right_eye: "दाईं आँख (OD)", left_eye: "बाईं आँख (OS)",
    viewfinder_msg: "व्यूफाइंडर में रोगी की आँख रखें",
    viewfinder_sub: "रेटिना को वृत्त के साथ संरेखित करें",
    btn_capture: "📷 छवि कैप्चर करें", btn_upload: "⬆️ छवि अपलोड करें",
    btn_proceed_ai: "AI जाँच के लिए आगे बढ़ें →", btn_retake: "फिर से लें",
    captured_label: "✓ लिया गया",

    quality_title: "छवि गुणवत्ता जाँच",
    retina_visible: "रेटिना दिखाई दे रहा है", focus_ok: "फोकस ठीक है",
    brightness_ok: "चमक ठीक है",
    quality_label: "छवि गुणवत्ता:", quality_good: "अच्छी",
    quality_fail: "छवि गुणवत्ता पर्याप्त नहीं है। कृपया फिर से लें।",

    ai_title: "AI जाँच",
    ai_subtitle: "मधुमेह रेटिनोपैथी के संकेतों के लिए रेटिनल छवि विश्लेषण",
    analyzing: "विश्लेषण हो रहा है…",
    step_quality: "छवि गुणवत्ता जाँच", step_retina: "रेटिना पहचान",
    step_lesion: "लीज़न विश्लेषण", step_severity: "DR गंभीरता मूल्यांकन",
    step_explain: "व्याख्यात्मकता",
    ai_disclaimer: "AI जाँच विशेषज्ञ निर्णय का समर्थन करती है, विशेषज्ञ निदान को प्रतिस्थापित नहीं करती।",
    btn_view_result: "AI परिणाम देखें →",

    ai_result_title: "AI जाँच परिणाम",
    awaiting_verif: "विशेषज्ञ सत्यापन प्रतीक्षा",
    ai_detected: "AI द्वारा पाया गया",
    confidence: "विश्वास", severity_scale: "गंभीरता स्तर",
    risk_level: "जोखिम स्तर:", risk_moderate: "मध्यम",
    ai_findings: "AI निष्कर्ष",
    finding_ma: "माइक्रोएन्यूरिज्म पाया गया", finding_hm: "रक्तस्राव पाया गया",
    finding_ex: "एक्स्यूडेट पाया गया", finding_iq: "छवि गुणवत्ता: अच्छी",
    xai_label: "व्याख्यात्मक AI — AI ध्यान मानचित्र",
    original_fundus: "मूल फंडस छवि", ai_attn: "AI ध्यान मानचित्र",
    heatmap_caption: "चिह्नित क्षेत्र AI भविष्यवाणी को प्रभावित करते हैं।",
    ai_note_label: "नोट:", ai_note_text: "AI जाँच निर्णय समर्थन है, विशेषज्ञ निदान नहीं।",
    btn_proceed_specialist: "विशेषज्ञ समीक्षा के लिए आगे बढ़ें →",

    sev_no_dr: "DR नहीं", sev_mild: "हल्का", sev_moderate: "मध्यम",
    sev_severe: "गंभीर", sev_pdr: "PDR",
    sev_mild_npdr: "हल्का NPDR", sev_moderate_npdr: "मध्यम NPDR",
    sev_severe_npdr: "गंभीर NPDR",

    specialist_title: "विशेषज्ञ समीक्षा",
    ai_result_card: "AI जाँच परिणाम",
    fundus_images: "फंडस छवियाँ",
    why_result: "यह परिणाम क्यों?",
    why_result_text: "AI ने मधुमेह रेटिनोपैथी से संबंधित रेटिनल लक्षण पाए — माइक्रोएन्यूरिज्म, रक्तस्राव और एक्स्यूडेट।",
    decision_label: "विशेषज्ञ निर्णय",
    confirm_lbl: "AI परिणाम की पुष्टि करें", confirm_sub: "AI मूल्यांकन से सहमत",
    change_lbl: "गंभीरता बदलें", change_sub: "AI मूल्यांकन को संशोधित करें",
    reexamine_lbl: "पुनः जाँच", reexamine_sub: "छवि अस्पष्ट या अनिर्णायक",
    select_severity: "सुधरी हुई गंभीरता चुनें",
    reason_lbl: "पुनः जाँच का कारण",
    reason_ph: "उदा. छवि अस्पष्ट है",
    notes_lbl: "विशेषज्ञ नोट",
    notes_ph: "नैदानिक टिप्पणियाँ या स्वास्थ्य कार्यकर्ता के लिए निर्देश जोड़ें…",
    btn_verify: "सत्यापित करें और जमा करें →",

    referral_title: "रेफरल",
    referral_required: "रेफरल आवश्यक",
    sev_label: "गंभीरता", urgency_label: "तात्कालिकता",
    referral_msg: "4 सप्ताह में विशेषज्ञ अनुवर्ती की सिफारिश।",
    recommended_specialist: "अनुशंसित विशेषज्ञ",
    btn_send_referral: "रेफरल भेजें", btn_send_sms: "रोगी को SMS भेजें",
    btn_continue_report: "अंतिम रिपोर्ट के लिए जारी रखें →",

    report_title: "जाँच रिपोर्ट",
    report_header: "Drishti-AI जाँच रिपोर्ट",
    demo_report: "डेमो रिपोर्ट — नैदानिक दस्तावेज़ नहीं",
    patient_details: "रोगी विवरण",
    key_findings: "मुख्य निष्कर्ष",
    grad_cam: "Grad-CAM ध्यान मानचित्र तैयार",
    sp_verified: "विशेषज्ञ सत्यापित",
    verified_msg: "AI परिणाम की पुष्टि। विशेषज्ञ अनुवर्ती की सिफारिश।",
    recommended_action: "अनुशंसित कार्रवाई",
    action_msg: "4 सप्ताह में रोगी को जिला नेत्र केंद्र भेजें।",
    btn_download: "रिपोर्ट डाउनलोड", btn_sms: "SMS भेजें",
    btn_new_screening: "+ नई जाँच शुरू करें",
    btn_more: "अधिक विकल्प", btn_hide: "छिपाएँ",
    technical_export: "तकनीकी निर्यात",

    history_title: "रोगी इतिहास", screening_history: "जाँच इतिहास",

    offline_title: "ऑफ़लाइन कतार",
    offline_subtitle: "इंटरनेट के बिना ली गई छवियाँ सुरक्षित रूप से सहेजी जाती हैं।",
    limited_connectivity: "सीमित कनेक्टिविटी",
    cases_waiting: "मामले सिंक के लिए प्रतीक्षा",
    btn_sync: "अभी सिंक करें", syncing: "सिंक हो रहा है…",
    sync_complete: "सिंक पूर्ण",
    sync1: "छवियाँ अपलोड हो गई",
    sync2: "सभी मामलों का AI विश्लेषण पूर्ण",
    sync3: "विशेषज्ञ समीक्षा के लिए मामले उपलब्ध",
    encrypt_note: "सभी छवियाँ संग्रहीत होने से पहले एन्क्रिप्ट की जाती हैं।",
    waiting_lbl: "प्रतीक्षा",

    help_title: "सहायता", help_subtitle: "Drishti-AI उपयोग करने वाले स्वास्थ्य कार्यकर्ताओं के लिए मार्गदर्शन।",
    help_q1: "अच्छी फंडस छवि कैसे लें",
    help_q2: "AI परिणाम का क्या अर्थ है?",
    help_q3: "रोगी को कब रेफर करें?",
    help_q4: "इंटरनेट नहीं होने पर क्या होता है?",
    need_help: "अधिक सहायता चाहिए?",
    need_help_msg: "अपने PHC समन्वयक या Drishti-AI सहायता टीम से संपर्क करें।",

    wf_patient: "रोगी", wf_image: "छवि", wf_ai: "AI",
    wf_specialist: "विशेषज्ञ", wf_report: "रिपोर्ट",
  },

  te: {
    nav_dashboard: "డాష్‌బోర్డ్", nav_history: "రోగి చరిత్ర",
    nav_offline: "ఆఫ్‌లైన్ క్యూ", nav_help: "సహాయం",
    online: "ఆన్‌లైన్", offline: "ఆఫ్‌లైన్",
    demo_data: "డెమో డేటా — నిజమైన రికార్డులు కాదు",

    dash_title: "PHC డాష్‌బోర్డ్",
    dash_subtitle: "Drishti-AI · గ్రామీణ మధుమేహ రెటినోపతి స్క్రీనింగ్",
    start_screening: "+ కొత్త స్క్రీనింగ్ ప్రారంభించండి",
    todays_screenings: "నేటి స్క్రీనింగ్లు", awaiting_ai: "AI వేచి",
    awaiting_specialist: "నిపుణుల వేచి", urgent_referrals: "అత్యవసర రెఫరల్",
    case_waiting: "కేసు సమకాలీకరణకు వేచి",
    captured_offline: "ఆఫ్‌లైన్‌లో తీయబడింది. కనెక్షన్ వచ్చినప్పుడు సమకాలీకరించబడుతుంది.",
    view_arrow: "చూడండి →", recent_screenings: "ఇటీవలి స్క్రీనింగ్లు",
    col_patient: "రోగి", col_date: "తేదీ",
    col_ai_result: "AI ఫలితం", col_status: "స్థితి",

    badge_awaiting_ai: "AI వేచి", badge_ai_complete: "AI పూర్తి",
    badge_awaiting_specialist: "నిపుణుల వేచి", badge_verified: "ధృవీకరించబడింది",
    badge_referral: "రెఫరల్ అవసరం", badge_offline: "సమకాలీకరణ వేచి",

    reg_title: "రోగి నమోదు",
    reg_subtitle: "స్క్రీనింగ్ ప్రారంభించడానికి రోగి వివరాలు నమోదు చేయండి.",
    basic_info: "ప్రాథమిక సమాచారం", medical_history: "వైద్య చరిత్ర",
    optional: "(ఐచ్ఛికం)",
    patient_name: "రోగి పేరు", patient_id: "రోగి ID",
    age: "వయసు", gender: "లింగం", phone: "ఫోన్ నంబర్",
    village: "గ్రామం / PHC", diabetes_duration: "మధుమేహ వ్యవధి",
    prev_eye: "గత కంటి వ్యాధి",
    gender_f: "స్త్రీ", gender_m: "పురుషుడు", gender_o: "ఇతర",
    continue_btn: "కంటి స్క్రీనింగ్‌కు కొనసాగండి →",
    privacy_note: "రోగి సమాచారం స్క్రీనింగ్ మరియు రెఫరల్‌కు మాత్రమే ఉపయోగించబడుతుంది.",

    capture_title: "ఫండస్ చిత్రం తీయండి",
    select_eye: "కన్ను ఎంచుకోండి",
    right_eye: "కుడి కన్ను (OD)", left_eye: "ఎడమ కన్ను (OS)",
    viewfinder_msg: "వ్యూఫైండర్‌లో రోగి కన్నును ఉంచండి",
    viewfinder_sub: "రెటినాను వృత్తంతో సమలేఖనం చేయండి",
    btn_capture: "📷 చిత్రం తీయండి", btn_upload: "⬆️ చిత్రం అప్‌లోడ్ చేయండి",
    btn_proceed_ai: "AI స్క్రీనింగ్‌కు కొనసాగండి →", btn_retake: "మళ్ళీ తీయండి",
    captured_label: "✓ తీయబడింది",

    quality_title: "చిత్రం నాణ్యత తనిఖీ",
    retina_visible: "రెటినా కనిపిస్తోంది", focus_ok: "ఫోకస్ సరే",
    brightness_ok: "ప్రకాశం సరే",
    quality_label: "చిత్రం నాణ్యత:", quality_good: "మంచిది",
    quality_fail: "చిత్రం నాణ్యత సరిపోదు. దయచేసి మళ్ళీ తీయండి.",

    ai_title: "AI స్క్రీనింగ్",
    ai_subtitle: "మధుమేహ రెటినోపతి సంకేతాల కోసం రెటినల్ చిత్రం విశ్లేషణ",
    analyzing: "విశ్లేషిస్తోంది…",
    step_quality: "చిత్రం నాణ్యత తనిఖీ", step_retina: "రెటినా గుర్తింపు",
    step_lesion: "లెసియన్ విశ్లేషణ", step_severity: "DR తీవ్రత మూల్యాంకనం",
    step_explain: "వివరణాత్మకత",
    ai_disclaimer: "AI స్క్రీనింగ్ నిపుణుల నిర్ణయాన్ని మద్దతు చేస్తుంది, నిపుణుల నిర్ధారణను భర్తీ చేయదు.",
    btn_view_result: "AI ఫలితం చూడండి →",

    ai_result_title: "AI స్క్రీనింగ్ ఫలితం",
    awaiting_verif: "నిపుణుల ధృవీకరణ వేచి",
    ai_detected: "AI గుర్తించింది",
    confidence: "విశ్వాసం", severity_scale: "తీవ్రత స్థాయి",
    risk_level: "ప్రమాద స్థాయి:", risk_moderate: "మధ్యస్థం",
    ai_findings: "AI ఆధారిత నిర్ధారణలు",
    finding_ma: "మైక్రోఆన్యూరిజమ్లు గుర్తించబడ్డాయి", finding_hm: "రక్తస్రావం గుర్తించబడింది",
    finding_ex: "ఎక్స్‌యుడేట్లు గుర్తించబడ్డాయి", finding_iq: "చిత్రం నాణ్యత: మంచిది",
    xai_label: "వివరణాత్మక AI — AI శ్రద్ధా మానచిత్రం",
    original_fundus: "అసలు ఫండస్ చిత్రం", ai_attn: "AI శ్రద్ధా మానచిత్రం",
    heatmap_caption: "గుర్తించిన ప్రాంతాలు AI అంచనాను ప్రభావితం చేశాయి.",
    ai_note_label: "గమనిక:", ai_note_text: "AI స్క్రీనింగ్ నిర్ణయ మద్దతు, నిపుణుల నిర్ధారణ కాదు.",
    btn_proceed_specialist: "నిపుణుల సమీక్షకు కొనసాగండి →",

    sev_no_dr: "DR లేదు", sev_mild: "తేలికపాటి", sev_moderate: "మధ్యస్థం",
    sev_severe: "తీవ్రమైన", sev_pdr: "PDR",
    sev_mild_npdr: "తేలికపాటి NPDR", sev_moderate_npdr: "మధ్యస్థ NPDR",
    sev_severe_npdr: "తీవ్రమైన NPDR",

    specialist_title: "నిపుణుల సమీక్ష",
    ai_result_card: "AI స్క్రీనింగ్ ఫలితం",
    fundus_images: "ఫండస్ చిత్రాలు",
    why_result: "ఈ ఫలితం ఎందుకు?",
    why_result_text: "AI మధుమేహ రెటినోపతికి సంబంధించిన రెటినల్ లక్షణాలను గుర్తించింది.",
    decision_label: "నిపుణుల నిర్ణయం",
    confirm_lbl: "AI ఫలితాన్ని నిర్ధారించండి", confirm_sub: "AI మూల్యాంకనంతో అంగీకరించండి",
    change_lbl: "తీవ్రత మార్చండి", change_sub: "AI మూల్యాంకనాన్ని సవరించండి",
    reexamine_lbl: "పునఃపరీక్ష", reexamine_sub: "చిత్రం అస్పష్టంగా ఉంది",
    select_severity: "సరిదిద్దిన తీవ్రత ఎంచుకోండి",
    reason_lbl: "పునఃపరీక్ష కారణం",
    reason_ph: "ఉదా. చిత్రం అస్పష్టంగా ఉంది",
    notes_lbl: "నిపుణుల గమనికలు",
    notes_ph: "క్లినికల్ పరిశీలనలు లేదా ఆరోగ్య కార్యకర్తకు సూచనలు జోడించండి…",
    btn_verify: "ధృవీకరించి సమర్పించండి →",

    referral_title: "రెఫరల్",
    referral_required: "రెఫరల్ అవసరం",
    sev_label: "తీవ్రత", urgency_label: "అత్యవసరత",
    referral_msg: "4 వారాలలో నిపుణుల అనుసరణ సిఫారసు.",
    recommended_specialist: "సిఫారసు చేసిన నిపుణుడు",
    btn_send_referral: "రెఫరల్ పంపండి", btn_send_sms: "రోగికి SMS పంపండి",
    btn_continue_report: "తుది నివేదికకు కొనసాగండి →",

    report_title: "స్క్రీనింగ్ నివేదిక",
    report_header: "Drishti-AI స్క్రీనింగ్ నివేదిక",
    demo_report: "డెమో నివేదిక — క్లినికల్ పత్రం కాదు",
    patient_details: "రోగి వివరాలు",
    key_findings: "ముఖ్య నిర్ధారణలు",
    grad_cam: "Grad-CAM శ్రద్ధా మానచిత్రం సిద్ధం",
    sp_verified: "నిపుణుల ధృవీకరణ",
    verified_msg: "AI ఫలితం నిర్ధారించబడింది. నిపుణుల అనుసరణ సిఫారసు.",
    recommended_action: "సిఫారసు చేసిన చర్య",
    action_msg: "4 వారాలలో రోగిని జిల్లా కంటి కేంద్రానికి పంపండి.",
    btn_download: "నివేదిక డౌన్‌లోడ్", btn_sms: "SMS పంపండి",
    btn_new_screening: "+ కొత్త స్క్రీనింగ్ ప్రారంభించండి",
    btn_more: "మరిన్ని ఎంపికలు", btn_hide: "దాచండి",
    technical_export: "సాంకేతిక ఎగుమతి",

    history_title: "రోగి చరిత్ర", screening_history: "స్క్రీనింగ్ చరిత్ర",

    offline_title: "ఆఫ్‌లైన్ క్యూ",
    offline_subtitle: "ఇంటర్నెట్ లేకుండా తీసిన చిత్రాలు సురక్షితంగా నిల్వ చేయబడతాయి.",
    limited_connectivity: "పరిమిత కనెక్టివిటీ",
    cases_waiting: "కేసులు సమకాలీకరణకు వేచి",
    btn_sync: "ఇప్పుడు సమకాలీకరించు", syncing: "సమకాలీకరిస్తోంది…",
    sync_complete: "సమకాలీకరణ పూర్తి",
    sync1: "చిత్రాలు అప్‌లోడ్ అయ్యాయి",
    sync2: "అన్ని కేసులకు AI విశ్లేషణ పూర్తి",
    sync3: "నిపుణుల సమీక్షకు కేసులు అందుబాటులో",
    encrypt_note: "అన్ని చిత్రాలు నిల్వ చేయడానికి ముందు గుప్తీకరించబడతాయి.",
    waiting_lbl: "వేచి",

    help_title: "సహాయం", help_subtitle: "Drishti-AI ఉపయోగించే ఆరోగ్య కార్యకర్తలకు మార్గదర్శకత.",
    help_q1: "మంచి ఫండస్ చిత్రం ఎలా తీయాలి",
    help_q2: "AI ఫలితం అంటే ఏమిటి?",
    help_q3: "రోగిని ఎప్పుడు రెఫర్ చేయాలి?",
    help_q4: "ఇంటర్నెట్ లేకుండా ఏమి జరుగుతుంది?",
    need_help: "మరింత సహాయం కావాలా?",
    need_help_msg: "మీ PHC సమన్వయకర్త లేదా Drishti-AI మద్దతు బృందాన్ని సంప్రదించండి.",

    wf_patient: "రోగి", wf_image: "చిత్రం", wf_ai: "AI",
    wf_specialist: "నిపుణుడు", wf_report: "నివేదిక",
  },

  ta: {
    nav_dashboard: "டாஷ்போர்டு", nav_history: "நோயாளி வரலாறு",
    nav_offline: "ஆஃப்லைன் வரிசை", nav_help: "உதவி",
    online: "ஆன்லைன்", offline: "ஆஃப்லைன்",
    demo_data: "டெமோ தரவு — உண்மையான பதிவுகள் அல்ல",

    dash_title: "PHC டாஷ்போர்டு",
    dash_subtitle: "Drishti-AI · கிராமப்புற நீரிழிவு விழித்திரை நோய் பரிசோதனை",
    start_screening: "+ புதிய பரிசோதனை தொடங்கு",
    todays_screenings: "இன்றைய பரிசோதனைகள்", awaiting_ai: "AI காத்திருப்பு",
    awaiting_specialist: "நிபுணர் காத்திருப்பு", urgent_referrals: "அவசர பரிந்துரை",
    case_waiting: "வழக்கு ஒத்திசைவுக்கு காத்திருக்கிறது",
    captured_offline: "ஆஃப்லைனில் எடுக்கப்பட்டது. இணைப்பு வரும்போது ஒத்திசைக்கும்.",
    view_arrow: "பார்க்க →", recent_screenings: "சமீபத்திய பரிசோதனைகள்",
    col_patient: "நோயாளி", col_date: "தேதி",
    col_ai_result: "AI முடிவு", col_status: "நிலை",

    badge_awaiting_ai: "AI காத்திருப்பு", badge_ai_complete: "AI முடிந்தது",
    badge_awaiting_specialist: "நிபுணர் காத்திருப்பு", badge_verified: "சரிபார்க்கப்பட்டது",
    badge_referral: "பரிந்துரை தேவை", badge_offline: "ஒத்திசைவு காத்திருப்பு",

    reg_title: "நோயாளி பதிவு",
    reg_subtitle: "பரிசோதனை தொடங்க நோயாளியின் விவரங்களை உள்ளிடுக.",
    basic_info: "அடிப்படை தகவல்", medical_history: "மருத்துவ வரலாறு",
    optional: "(விருப்பத்தேர்வு)",
    patient_name: "நோயாளி பெயர்", patient_id: "நோயாளி ID",
    age: "வயது", gender: "பாலினம்", phone: "தொலைபேசி எண்",
    village: "கிராமம் / PHC", diabetes_duration: "நீரிழிவு காலம்",
    prev_eye: "முந்தைய கண் நோய்",
    gender_f: "பெண்", gender_m: "ஆண்", gender_o: "மற்றவை",
    continue_btn: "கண் பரிசோதனைக்கு தொடரவும் →",
    privacy_note: "நோயாளி தகவல் பரிசோதனை மற்றும் பரிந்துரைக்கு மட்டுமே பயன்படுத்தப்படும்.",

    capture_title: "ஃபண்டஸ் படம் எடுக்கவும்",
    select_eye: "கண்ணை தேர்ந்தெடுக்கவும்",
    right_eye: "வலது கண் (OD)", left_eye: "இடது கண் (OS)",
    viewfinder_msg: "வியூஃபைண்டரில் நோயாளியின் கண்ணை வைக்கவும்",
    viewfinder_sub: "விழித்திரையை வட்டத்துடன் சீரமைக்கவும்",
    btn_capture: "📷 படம் எடு", btn_upload: "⬆️ படம் பதிவேற்று",
    btn_proceed_ai: "AI பரிசோதனைக்கு தொடரவும் →", btn_retake: "மீண்டும் எடு",
    captured_label: "✓ எடுக்கப்பட்டது",

    quality_title: "படம் தரம் சரிபார்ப்பு",
    retina_visible: "விழித்திரை தெரிகிறது", focus_ok: "ஃபோகஸ் சரியாக உள்ளது",
    brightness_ok: "ஒளி சரியாக உள்ளது",
    quality_label: "படம் தரம்:", quality_good: "நல்லது",
    quality_fail: "படம் தரம் போதுமானதாக இல்லை. மீண்டும் எடுக்கவும்.",

    ai_title: "AI பரிசோதனை",
    ai_subtitle: "நீரிழிவு விழித்திரை நோய் அறிகுறிகளுக்கு விழித்திரை படம் பகுப்பாய்வு",
    analyzing: "பகுப்பாய்வு செய்கிறது…",
    step_quality: "படம் தரம் சரிபார்ப்பு", step_retina: "விழித்திரை கண்டறிதல்",
    step_lesion: "புண் பகுப்பாய்வு", step_severity: "DR தீவிரம் மதிப்பீடு",
    step_explain: "விளக்கத்தன்மை",
    ai_disclaimer: "AI பரிசோதனை நிபுணர் முடிவெடுப்பதை ஆதரிக்கிறது, நிபுணர் நோய் கண்டறிதலை மாற்றாது.",
    btn_view_result: "AI முடிவை பார்க்கவும் →",

    ai_result_title: "AI பரிசோதனை முடிவு",
    awaiting_verif: "நிபுணர் சரிபார்ப்பு காத்திருப்பு",
    ai_detected: "AI கண்டறிந்தது",
    confidence: "நம்பகத்தன்மை", severity_scale: "தீவிரம் அளவு",
    risk_level: "ஆபத்து நிலை:", risk_moderate: "மிதமான",
    ai_findings: "AI கண்டுபிடிப்புகள்",
    finding_ma: "மைக்ரோஆனியூரிஸங்கள் கண்டறியப்பட்டன", finding_hm: "இரத்தக்கசிவு கண்டறியப்பட்டது",
    finding_ex: "எக்ஸுடேட்கள் கண்டறியப்பட்டன", finding_iq: "படம் தரம்: நல்லது",
    xai_label: "விளக்கக்கூடிய AI — AI கவன வரைபடம்",
    original_fundus: "அசல் ஃபண்டஸ் படம்", ai_attn: "AI கவன வரைபடம்",
    heatmap_caption: "குறிப்பிடப்பட்ட பகுதிகள் AI கணிப்பை பாதித்தன.",
    ai_note_label: "குறிப்பு:", ai_note_text: "AI பரிசோதனை முடிவு ஆதரவு, நிபுணர் நோய் கண்டறிதல் அல்ல.",
    btn_proceed_specialist: "நிபுணர் மதிப்பாய்வுக்கு தொடரவும் →",

    sev_no_dr: "DR இல்லை", sev_mild: "லேசான", sev_moderate: "மிதமான",
    sev_severe: "கடுமையான", sev_pdr: "PDR",
    sev_mild_npdr: "லேசான NPDR", sev_moderate_npdr: "மிதமான NPDR",
    sev_severe_npdr: "கடுமையான NPDR",

    specialist_title: "நிபுணர் மதிப்பாய்வு",
    ai_result_card: "AI பரிசோதனை முடிவு",
    fundus_images: "ஃபண்டஸ் படங்கள்",
    why_result: "இந்த முடிவு ஏன்?",
    why_result_text: "AI நீரிழிவு விழித்திரை நோயுடன் தொடர்புடைய விழித்திரை அம்சங்களை கண்டறிந்தது.",
    decision_label: "நிபுணர் முடிவு",
    confirm_lbl: "AI முடிவை உறுதிப்படுத்து", confirm_sub: "AI மதிப்பீட்டை ஒப்புக்கொள்",
    change_lbl: "தீவிரம் மாற்று", change_sub: "AI மதிப்பீட்டை மீறு",
    reexamine_lbl: "மறு பரிசோதனை", reexamine_sub: "படம் தெளிவற்றது அல்லது முடிவற்றது",
    select_severity: "திருத்தப்பட்ட தீவிரத்தை தேர்ந்தெடு",
    reason_lbl: "மறு பரிசோதனை காரணம்",
    reason_ph: "எ.கா. படம் தெளிவற்றது",
    notes_lbl: "நிபுணர் குறிப்புகள்",
    notes_ph: "மருத்துவ கவனிப்புகள் அல்லது சுகாதார பணியாளருக்கு வழிமுறைகள் சேர்க்கவும்…",
    btn_verify: "சரிபார்த்து சமர்ப்பி →",

    referral_title: "பரிந்துரை",
    referral_required: "பரிந்துரை தேவை",
    sev_label: "தீவிரம்", urgency_label: "அவசரம்",
    referral_msg: "4 வாரங்களில் நிபுணர் பின்தொடர்வு பரிந்துரைக்கப்படுகிறது.",
    recommended_specialist: "பரிந்துரைக்கப்பட்ட நிபுணர்",
    btn_send_referral: "பரிந்துரை அனுப்பு", btn_send_sms: "நோயாளிக்கு SMS அனுப்பு",
    btn_continue_report: "இறுதி அறிக்கைக்கு தொடரவும் →",

    report_title: "பரிசோதனை அறிக்கை",
    report_header: "Drishti-AI பரிசோதனை அறிக்கை",
    demo_report: "டெமோ அறிக்கை — மருத்துவ ஆவணம் அல்ல",
    patient_details: "நோயாளி விவரங்கள்",
    key_findings: "முக்கிய கண்டுபிடிப்புகள்",
    grad_cam: "Grad-CAM கவன வரைபடம் தயார்",
    sp_verified: "நிபுணர் சரிபார்க்கப்பட்டது",
    verified_msg: "AI முடிவு உறுதிப்படுத்தப்பட்டது. நிபுணர் பின்தொடர்வு பரிந்துரை.",
    recommended_action: "பரிந்துரைக்கப்பட்ட நடவடிக்கை",
    action_msg: "நோயாளியை 4 வாரங்களில் மாவட்ட கண் மையத்திற்கு அனுப்புக.",
    btn_download: "அறிக்கை பதிவிறக்கு", btn_sms: "SMS அனுப்பு",
    btn_new_screening: "+ புதிய பரிசோதனை தொடங்கு",
    btn_more: "மேலும் விருப்பங்கள்", btn_hide: "மறை",
    technical_export: "தொழில்நுட்ப ஏற்றுமதி",

    history_title: "நோயாளி வரலாறு", screening_history: "பரிசோதனை வரலாறு",

    offline_title: "ஆஃப்லைன் வரிசை",
    offline_subtitle: "இணையம் இல்லாமல் எடுக்கப்பட்ட படங்கள் பாதுகாப்பாக சேமிக்கப்படுகின்றன.",
    limited_connectivity: "குறைந்த இணைப்பு",
    cases_waiting: "வழக்குகள் ஒத்திசைவுக்கு காத்திருக்கின்றன",
    btn_sync: "இப்போது ஒத்திசை", syncing: "ஒத்திசைக்கிறது…",
    sync_complete: "ஒத்திசைவு முடிந்தது",
    sync1: "படங்கள் பதிவேற்றப்பட்டன",
    sync2: "அனைத்து வழக்குகளுக்கும் AI பகுப்பாய்வு முடிந்தது",
    sync3: "நிபுணர் மதிப்பாய்வுக்கு வழக்குகள் கிடைக்கின்றன",
    encrypt_note: "அனைத்து படங்களும் சேமிக்கப்படுவதற்கு முன் குறியாக்கம் செய்யப்படுகின்றன.",
    waiting_lbl: "காத்திருப்பு",

    help_title: "உதவி", help_subtitle: "Drishti-AI பயன்படுத்தும் சுகாதார பணியாளர்களுக்கு வழிகாட்டுதல்.",
    help_q1: "நல்ல ஃபண்டஸ் படம் எப்படி எடுப்பது",
    help_q2: "AI முடிவு என்னவென்று அர்த்தம்?",
    help_q3: "நோயாளியை எப்போது பரிந்துரைக்க வேண்டும்?",
    help_q4: "இணையம் இல்லாமல் என்ன நடக்கும்?",
    need_help: "மேலும் உதவி தேவையா?",
    need_help_msg: "உங்கள் PHC ஒருங்கிணைப்பாளர் அல்லது Drishti-AI ஆதரவு குழுவை தொடர்பு கொள்ளுங்கள்.",

    wf_patient: "நோயாளி", wf_image: "படம்", wf_ai: "AI",
    wf_specialist: "நிபுணர்", wf_report: "அறிக்கை",
  },
};

type TKey = keyof typeof T.en;

// ─── Language Context ─────────────────────────────────────────────────────────

const LangCtx = createContext<{ lang: Lang; t: (k: TKey) => string }>({
  lang: "en",
  t: (k) => T.en[k],
});

function useT() {
  return useContext(LangCtx).t;
}

// ─── Demo Data ────────────────────────────────────────────────────────────────

const RECENT_SCREENINGS = [
  { id: "PHC-2026-1024", name: "Meena Devi", date: "11 Sep 2026", aiResult: "Moderate NPDR", status: "specialist-verified" as StatusBadgeType },
  { id: "PHC-2026-1023", name: "Rajan Kumar", date: "11 Sep 2026", aiResult: "Severe NPDR", status: "referral-required" as StatusBadgeType },
  { id: "PHC-2026-1022", name: "Sunita Bai", date: "10 Sep 2026", aiResult: "Mild NPDR", status: "awaiting-specialist" as StatusBadgeType },
  { id: "PHC-2026-1021", name: "Ashok Singh", date: "10 Sep 2026", aiResult: "No DR", status: "specialist-verified" as StatusBadgeType },
  { id: "PHC-2026-1020", name: "Kamla Yadav", date: "09 Sep 2026", aiResult: "Pending", status: "offline" as StatusBadgeType },
];

const HISTORY_SCREENINGS = [
  { date: "September 2026", result: "Moderate NPDR", status: "Specialist Verified", severity: "moderate" },
  { date: "June 2026", result: "Mild NPDR", status: "Specialist Verified", severity: "mild" },
  { date: "March 2026", result: "No DR", status: "Specialist Verified", severity: "none" },
];

const LANG_NAMES: Record<Lang, string> = {
  en: "English", kn: "ಕನ್ನಡ", hi: "हिन्दी", te: "తెలుగు", ta: "தமிழ்",
};

const NAV_ITEMS: [Screen, TKey, string][] = [
  ["dashboard", "nav_dashboard", "🏠"],
  ["history", "nav_history", "📋"],
  ["offline-queue", "nav_offline", "📡"],
  ["help", "nav_help", "❓"],
];

// ─── Shared UI Components ─────────────────────────────────────────────────────

function StatusBadge({ type }: { type: StatusBadgeType }) {
  const t = useT();
  const configs: Record<StatusBadgeType, { key: TKey; cls: string }> = {
    "awaiting-ai":        { key: "badge_awaiting_ai",       cls: "bg-amber-50 text-amber-700 border-amber-200" },
    "ai-complete":        { key: "badge_ai_complete",        cls: "bg-blue-50 text-blue-700 border-blue-200" },
    "awaiting-specialist":{ key: "badge_awaiting_specialist",cls: "bg-purple-50 text-purple-700 border-purple-200" },
    "specialist-verified":{ key: "badge_verified",           cls: "bg-green-50 text-green-700 border-green-200" },
    "referral-required":  { key: "badge_referral",           cls: "bg-red-50 text-red-700 border-red-200" },
    "offline":            { key: "badge_offline",            cls: "bg-slate-100 text-slate-600 border-slate-200" },
  };
  const c = configs[type];
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-600 border ${c.cls}`}>
      {t(c.key)}
    </span>
  );
}

function WorkflowBar({ step }: { step: number }) {
  const t = useT();
  const steps: TKey[] = ["wf_patient", "wf_image", "wf_ai", "wf_specialist", "wf_report"];
  return (
    <div className="flex items-center overflow-x-auto no-scrollbar">
      {steps.map((key, i) => {
        const idx = i + 1;
        const done = idx < step;
        const active = idx === step;
        return (
          <div key={key} className="flex items-center flex-shrink-0">
            <div className="flex flex-col items-center gap-0.5">
              <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-700 ${done ? "bg-green-500 text-white" : active ? "bg-cyan-600 text-white" : "bg-slate-100 text-slate-400"}`}>
                {done ? "✓" : idx}
              </div>
              <span className={`text-[10px] md:text-xs font-600 whitespace-nowrap ${active ? "text-cyan-700" : done ? "text-green-600" : "text-slate-400"}`}>
                {t(key)}
              </span>
            </div>
            {i < steps.length - 1 && (
              <div className={`w-5 md:w-10 h-0.5 mb-4 flex-shrink-0 ${done ? "bg-green-400" : "bg-slate-200"}`} />
            )}
          </div>
        );
      })}
    </div>
  );
}

// ─── Retinal SVG ──────────────────────────────────────────────────────────────

function RetinalImage({ className = "", heatmap = false, alt = "Retinal fundus photograph" }: { className?: string; heatmap?: boolean; alt?: string }) {
  return (
    <div className={`relative rounded-xl overflow-hidden bg-black ${className}`}>
      <svg viewBox="0 0 480 480" className="w-full h-full" aria-label={alt}>
        <ellipse cx="240" cy="240" rx="230" ry="230" fill="#0a0404" />
        <radialGradient id="fundus-bg" cx="50%" cy="50%" r="48%">
          <stop offset="0%" stopColor="#c0622a" /><stop offset="60%" stopColor="#8b3a18" /><stop offset="100%" stopColor="#4a1a08" />
        </radialGradient>
        <ellipse cx="240" cy="240" rx="210" ry="210" fill="url(#fundus-bg)" />
        <radialGradient id="disc-grad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#fde8c0" /><stop offset="60%" stopColor="#f5c97a" /><stop offset="100%" stopColor="#d4914a" />
        </radialGradient>
        <ellipse cx="310" cy="210" rx="28" ry="32" fill="url(#disc-grad)" />
        <ellipse cx="310" cy="210" rx="12" ry="14" fill="#fdf6e3" opacity="0.6" />
        <path d="M310 210 Q260 240 200 280 Q170 300 140 340" stroke="#5c1f08" strokeWidth="5" fill="none" opacity="0.85" />
        <path d="M310 210 Q280 250 250 290 Q220 320 200 360" stroke="#5c1f08" strokeWidth="4" fill="none" opacity="0.8" />
        <path d="M310 210 Q330 190 340 170 Q350 150 360 130" stroke="#5c1f08" strokeWidth="4.5" fill="none" opacity="0.85" />
        <path d="M310 210 Q350 220 380 240 Q400 260 410 290" stroke="#5c1f08" strokeWidth="4" fill="none" opacity="0.8" />
        <path d="M310 210 Q290 180 270 150 Q255 130 240 110" stroke="#7a2e12" strokeWidth="3.5" fill="none" opacity="0.75" />
        <path d="M310 210 Q270 220 230 240 Q200 255 175 270" stroke="#7a2e12" strokeWidth="3.5" fill="none" opacity="0.75" />
        <path d="M200 280 Q180 300 160 330 Q145 350 135 370" stroke="#6b2410" strokeWidth="2.5" fill="none" opacity="0.65" />
        <path d="M380 240 Q395 260 400 290 Q405 310 395 340" stroke="#6b2410" strokeWidth="2.5" fill="none" opacity="0.65" />
        <path d="M175 270 Q155 285 135 305 Q115 320 100 345" stroke="#6b2410" strokeWidth="2" fill="none" opacity="0.6" />
        <radialGradient id="macula-grad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#2a0a02" stopOpacity="0.9" /><stop offset="70%" stopColor="#6b2010" stopOpacity="0.5" /><stop offset="100%" stopColor="#8b3a18" stopOpacity="0" />
        </radialGradient>
        <ellipse cx="185" cy="250" rx="40" ry="35" fill="url(#macula-grad)" />
        <ellipse cx="185" cy="250" rx="8" ry="7" fill="#1a0604" opacity="0.8" />
        <circle cx="220" cy="245" r="3" fill="#cc3311" opacity="0.9" />
        <circle cx="235" cy="270" r="2.5" fill="#cc3311" opacity="0.85" />
        <circle cx="210" cy="290" r="2" fill="#cc3311" opacity="0.8" />
        <circle cx="255" cy="255" r="2" fill="#cc3311" opacity="0.75" />
        <circle cx="245" cy="310" r="2.5" fill="#cc3311" opacity="0.8" />
        <circle cx="270" cy="285" r="2" fill="#cc3311" opacity="0.75" />
        <circle cx="300" cy="260" r="2" fill="#aa2200" opacity="0.7" />
        <circle cx="165" cy="310" r="2" fill="#cc3311" opacity="0.7" />
        <ellipse cx="225" cy="300" rx="6" ry="4" fill="#881100" opacity="0.75" />
        <ellipse cx="260" cy="325" rx="5" ry="3.5" fill="#881100" opacity="0.7" />
        <ellipse cx="200" cy="325" rx="4" ry="3" fill="#881100" opacity="0.65" />
        <ellipse cx="215" cy="265" rx="5" ry="3.5" fill="#f5e070" opacity="0.85" />
        <ellipse cx="230" cy="280" rx="4" ry="3" fill="#f5e070" opacity="0.8" />
        <ellipse cx="248" cy="270" rx="3" ry="2" fill="#f0d860" opacity="0.75" />
        <ellipse cx="260" cy="290" rx="4.5" ry="3" fill="#f5e070" opacity="0.8" />
        <ellipse cx="275" cy="275" rx="3.5" ry="2.5" fill="#f0d860" opacity="0.7" />
        <radialGradient id="vignette" cx="50%" cy="50%" r="48%">
          <stop offset="70%" stopColor="transparent" /><stop offset="100%" stopColor="#050101" stopOpacity="0.7" />
        </radialGradient>
        <ellipse cx="240" cy="240" rx="230" ry="230" fill="url(#vignette)" />
        {heatmap && (
          <g>
            <radialGradient id="heat1" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#ff0000" stopOpacity="0.75" /><stop offset="50%" stopColor="#ff6600" stopOpacity="0.45" /><stop offset="100%" stopColor="#ffff00" stopOpacity="0" />
            </radialGradient>
            <radialGradient id="heat2" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#ff4400" stopOpacity="0.6" /><stop offset="60%" stopColor="#ff8800" stopOpacity="0.3" /><stop offset="100%" stopColor="transparent" />
            </radialGradient>
            <radialGradient id="heat3" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#ffcc00" stopOpacity="0.55" /><stop offset="60%" stopColor="#ff8800" stopOpacity="0.25" /><stop offset="100%" stopColor="transparent" />
            </radialGradient>
            <ellipse cx="225" cy="285" rx="55" ry="50" fill="url(#heat1)" />
            <ellipse cx="260" cy="310" rx="40" ry="35" fill="url(#heat2)" />
            <ellipse cx="210" cy="265" rx="35" ry="28" fill="url(#heat3)" />
            <radialGradient id="heat4" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#00aaff" stopOpacity="0.35" /><stop offset="100%" stopColor="transparent" />
            </radialGradient>
            <ellipse cx="310" cy="210" rx="30" ry="30" fill="url(#heat4)" />
          </g>
        )}
      </svg>
    </div>
  );
}

// ─── Icons ────────────────────────────────────────────────────────────────────

function EyeIcon({ className = "w-5 h-5" }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
    </svg>
  );
}

function CheckIcon({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
    </svg>
  );
}

function HamburgerIcon({ className = "w-5 h-5" }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  );
}

function CloseIcon({ className = "w-5 h-5" }: { className?: string }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
    </svg>
  );
}

// ─── Language Selector ────────────────────────────────────────────────────────

function LangSelector({ lang, setLang }: { lang: Lang; setLang: (l: Lang) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 text-sm font-600 text-slate-700 transition-colors min-h-[36px]"
      >
        <span className="text-xs">{LANG_NAMES[lang]}</span>
        <svg className={`w-3.5 h-3.5 text-slate-400 transition-transform ${open ? "rotate-180" : ""}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 top-10 z-50 bg-white border border-slate-200 rounded-xl shadow-lg py-1.5 min-w-[140px]">
            {(Object.entries(LANG_NAMES) as [Lang, string][]).map(([l, name]) => (
              <button
                key={l}
                onClick={() => { setLang(l); setOpen(false); }}
                className={`w-full text-left px-4 py-2 text-sm font-600 transition-colors hover:bg-slate-50 ${lang === l ? "text-cyan-700 bg-cyan-50" : "text-slate-700"}`}
              >
                {name}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

// ─── Sidebar (laptop) ─────────────────────────────────────────────────────────

function Sidebar({ screen, onNav, isOffline }: { screen: Screen; onNav: (s: Screen) => void; isOffline: boolean }) {
  const t = useT();
  return (
    <aside className="hidden md:flex flex-col w-56 min-h-0 bg-white border-r border-slate-200 flex-shrink-0">
      <div className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {NAV_ITEMS.map(([s, key, icon]) => (
          <button
            key={s}
            onClick={() => onNav(s)}
            className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-600 transition-colors text-left ${screen === s ? "bg-cyan-50 text-cyan-700" : "text-slate-600 hover:bg-slate-50"}`}
          >
            <span className="text-base">{icon}</span>
            {t(key)}
          </button>
        ))}
      </div>
      <div className="px-4 py-4 border-t border-slate-100">
        <div className={`flex items-center gap-2 text-xs font-600 ${isOffline ? "text-slate-500" : "text-green-600"}`}>
          <span className={`w-2 h-2 rounded-full ${isOffline ? "bg-slate-400" : "bg-green-500"}`} />
          {isOffline ? t("offline") : t("online")}
        </div>
        <p className="text-[10px] text-slate-400 mt-2 leading-tight">
          Demo Prototype · Not for clinical use
        </p>
      </div>
    </aside>
  );
}

// ─── Mobile Drawer ────────────────────────────────────────────────────────────

function MobileDrawer({ open, onClose, screen, onNav, isOffline }: { open: boolean; onClose: () => void; screen: Screen; onNav: (s: Screen) => void; isOffline: boolean }) {
  const t = useT();
  if (!open) return null;
  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/40 md:hidden" onClick={onClose} />
      <div className="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-xl flex flex-col md:hidden">
        <div className="flex items-center justify-between px-4 h-14 border-b border-slate-100">
          <div className="flex items-center gap-2 text-cyan-700 font-800 text-base">
            <EyeIcon className="w-5 h-5" /> Drishti-AI
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg text-slate-500 hover:bg-slate-100">
            <CloseIcon className="w-5 h-5" />
          </button>
        </div>
        <div className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
          {NAV_ITEMS.map(([s, key, icon]) => (
            <button
              key={s}
              onClick={() => { onNav(s); onClose(); }}
              className={`w-full flex items-center gap-3 px-3 py-3 rounded-xl text-sm font-600 transition-colors text-left ${screen === s ? "bg-cyan-50 text-cyan-700" : "text-slate-600 hover:bg-slate-50"}`}
            >
              <span className="text-lg">{icon}</span>
              {t(key)}
            </button>
          ))}
        </div>
        <div className="px-4 py-4 border-t border-slate-100">
          <div className={`flex items-center gap-2 text-xs font-600 ${isOffline ? "text-slate-500" : "text-green-600"}`}>
            <span className={`w-2.5 h-2.5 rounded-full ${isOffline ? "bg-slate-400" : "bg-green-500"}`} />
            {isOffline ? t("offline") : t("online")}
          </div>
        </div>
      </div>
    </>
  );
}

// ─── Top Header ───────────────────────────────────────────────────────────────

function TopHeader({ screen, onNav, isOffline, lang, setLang, onHamburger }: {
  screen: Screen; onNav: (s: Screen) => void; isOffline: boolean;
  lang: Lang; setLang: (l: Lang) => void; onHamburger: () => void;
}) {
  return (
    <header className="bg-white border-b border-slate-200 sticky top-0 z-30 flex-shrink-0">
      <div className="flex items-center justify-between h-14 px-4 md:px-6">
        <div className="flex items-center gap-3">
          {/* Hamburger — mobile only */}
          <button onClick={onHamburger} className="md:hidden p-1.5 rounded-lg text-slate-500 hover:bg-slate-100 min-h-[40px] min-w-[40px] flex items-center justify-center">
            <HamburgerIcon className="w-5 h-5" />
          </button>
          {/* Logo */}
          <button onClick={() => onNav("dashboard")} className="flex items-center gap-2 text-cyan-700 font-800 text-lg tracking-tight">
            <EyeIcon className="w-6 h-6" />
            <span>Drishti-AI</span>
          </button>
        </div>
        <div className="flex items-center gap-2 md:gap-3">
          {/* Connectivity — desktop shows text, mobile shows dot only */}
          <span className={`hidden md:flex items-center gap-1.5 text-xs font-600 ${isOffline ? "text-slate-500" : "text-green-600"}`}>
            <span className={`w-2 h-2 rounded-full ${isOffline ? "bg-slate-400" : "bg-green-500"}`} />
            {isOffline ? "Offline" : "Online"}
          </span>
          <span className={`md:hidden w-2.5 h-2.5 rounded-full ${isOffline ? "bg-slate-400" : "bg-green-500"}`} />
          <LangSelector lang={lang} setLang={setLang} />
        </div>
      </div>
    </header>
  );
}

// ─── Screen: Dashboard ────────────────────────────────────────────────────────

function DashboardScreen({ onStart, onNav }: { onStart: () => void; onNav: (s: Screen) => void }) {
  const t = useT();
  return (
    <div className="max-w-4xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-xl md:text-2xl font-800 text-slate-900">{t("dash_title")}</h1>
          <p className="text-slate-500 text-sm mt-0.5">{t("dash_subtitle")}</p>
          <p className="text-xs text-slate-400 mt-0.5">{t("demo_data")}</p>
        </div>
        <button onClick={onStart} className="flex items-center justify-center gap-2 bg-cyan-600 hover:bg-cyan-700 active:bg-cyan-800 text-white font-700 px-5 py-3.5 rounded-xl shadow-sm transition-colors text-sm md:text-base w-full md:w-auto min-h-[48px]">
          {t("start_screening")}
        </button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {([
          ["todays_screenings", "8", "text-cyan-700", "bg-cyan-50", "border-cyan-200"],
          ["awaiting_ai",       "2", "text-amber-700","bg-amber-50","border-amber-200"],
          ["awaiting_specialist","3","text-purple-700","bg-purple-50","border-purple-200"],
          ["urgent_referrals",  "1", "text-red-700",  "bg-red-50",  "border-red-200"],
        ] as [TKey, string, string, string, string][]).map(([key, val, col, bg, border]) => (
          <div key={key} className={`${bg} border ${border} rounded-xl p-3 md:p-4`}>
            <span className={`text-2xl md:text-3xl font-800 ${col}`}>{val}</span>
            <p className="text-xs md:text-sm font-600 text-slate-600 leading-tight mt-0.5">{t(key)}</p>
          </div>
        ))}
      </div>

      <div className="bg-slate-50 border border-slate-200 rounded-xl p-3.5 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          <span className="text-xl flex-shrink-0">📡</span>
          <div className="min-w-0">
            <p className="font-700 text-slate-800 text-sm">1 {t("case_waiting")}</p>
            <p className="text-xs text-slate-500 truncate">{t("captured_offline")}</p>
          </div>
        </div>
        <button onClick={() => onNav("offline-queue")} className="text-sm font-700 text-cyan-700 hover:text-cyan-800 whitespace-nowrap flex-shrink-0 min-h-[44px] flex items-center">
          {t("view_arrow")}
        </button>
      </div>

      <div>
        <h2 className="text-base font-700 text-slate-800 mb-3">{t("recent_screenings")}</h2>

        {/* Phone: card list */}
        <div className="md:hidden space-y-2">
          {RECENT_SCREENINGS.map((s) => (
            <button key={s.id} onClick={() => onNav("history")} className="w-full bg-white rounded-xl border border-slate-200 px-4 py-3 flex items-center justify-between gap-3 text-left active:bg-slate-50">
              <div className="min-w-0">
                <p className="font-700 text-slate-800 text-sm">{s.name}</p>
                <p className="text-xs text-slate-400 font-mono">{s.id}</p>
                <p className="text-xs text-slate-500 mt-0.5">{s.aiResult} · {s.date}</p>
              </div>
              <div className="flex-shrink-0"><StatusBadge type={s.status} /></div>
            </button>
          ))}
        </div>

        {/* Laptop: table */}
        <div className="hidden md:block bg-white rounded-xl border border-slate-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50">
                {(["col_patient","col_date","col_ai_result","col_status"] as TKey[]).map(k => (
                  <th key={k} className="text-left px-4 py-3 font-700 text-slate-600">{t(k)}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {RECENT_SCREENINGS.map((s) => (
                <tr key={s.id} onClick={() => onNav("history")} className="border-b border-slate-50 last:border-0 hover:bg-slate-50 cursor-pointer">
                  <td className="px-4 py-3"><p className="font-700 text-slate-800">{s.name}</p><p className="text-xs text-slate-400">{s.id}</p></td>
                  <td className="px-4 py-3 text-slate-600">{s.date}</td>
                  <td className="px-4 py-3 text-slate-700">{s.aiResult}</td>
                  <td className="px-4 py-3"><StatusBadge type={s.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

// ─── Screen: Patient Registration ─────────────────────────────────────────────

function RegisterScreen({ onNext }: { onNext: () => void }) {
  const t = useT();
  const [form, setForm] = useState({ name: "Meena Devi", id: "PHC-2026-1025", age: "54", gender: "Female", phone: "98765 43210", village: "Rampur, Sitapur PHC", diabetesDuration: "8 years", eyeHistory: "" });
  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setForm(f => ({ ...f, [k]: e.target.value }));

  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={1} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("reg_title")}</h1><p className="text-slate-500 text-sm mt-0.5">{t("reg_subtitle")}</p></div>

      <div className="bg-white rounded-xl border border-slate-200 p-4 md:p-6 space-y-4">
        <h2 className="font-700 text-slate-700 text-xs uppercase tracking-wide border-b border-slate-100 pb-2">{t("basic_info")}</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("patient_name")} <span className="text-red-500">*</span></label>
            <input value={form.name} onChange={set("name")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 focus:ring-2 focus:ring-cyan-100 outline-none text-slate-800 font-600 text-base" />
          </div>
          <div>
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("patient_id")} <span className="text-red-500">*</span></label>
            <input value={form.id} onChange={set("id")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 focus:ring-2 focus:ring-cyan-100 outline-none text-slate-800 font-600 font-mono text-sm" />
          </div>
          <div>
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("age")} <span className="text-red-500">*</span></label>
            <input value={form.age} onChange={set("age")} type="number" inputMode="numeric" className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 focus:ring-2 focus:ring-cyan-100 outline-none text-slate-800 font-600" />
          </div>
          <div>
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("gender")} <span className="text-red-500">*</span></label>
            <select value={form.gender} onChange={set("gender")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 focus:ring-2 focus:ring-cyan-100 outline-none text-slate-800 font-600 bg-white">
              <option>{t("gender_f")}</option><option>{t("gender_m")}</option><option>{t("gender_o")}</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("phone")}</label>
            <input value={form.phone} onChange={set("phone")} type="tel" inputMode="tel" className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 focus:ring-2 focus:ring-cyan-100 outline-none text-slate-800 font-600" />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("village")} <span className="text-red-500">*</span></label>
            <input value={form.village} onChange={set("village")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 focus:ring-2 focus:ring-cyan-100 outline-none text-slate-800 font-600" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 p-4 md:p-6 space-y-4">
        <h2 className="font-700 text-slate-700 text-xs uppercase tracking-wide border-b border-slate-100 pb-2">{t("medical_history")} <span className="text-slate-400 font-500 normal-case tracking-normal ml-1">{t("optional")}</span></h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("diabetes_duration")}</label>
            <input value={form.diabetesDuration} onChange={set("diabetesDuration")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 outline-none text-slate-800 font-600" />
          </div>
          <div>
            <label className="block text-sm font-700 text-slate-700 mb-1.5">{t("prev_eye")}</label>
            <input value={form.eyeHistory} onChange={set("eyeHistory")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 outline-none text-slate-800 font-600" />
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <button onClick={onNext} className="w-full bg-cyan-600 hover:bg-cyan-700 active:bg-cyan-800 text-white font-700 py-4 rounded-xl transition-colors text-base shadow-sm min-h-[52px]">{t("continue_btn")}</button>
        <p className="text-center text-xs text-slate-400">{t("privacy_note")}</p>
      </div>
    </div>
  );
}

// ─── Screen: Image Capture ────────────────────────────────────────────────────

function CaptureScreen({ onNext }: { onNext: () => void }) {
  const t = useT();
  const [eye, setEye] = useState<"right" | "left">("right");
  const [captured, setCaptured] = useState(false);

  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={2} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("capture_title")}</h1>
        <div className="flex gap-2 items-center mt-1"><span className="text-slate-500 text-sm font-600">Meena Devi</span><span className="text-slate-300">·</span><span className="text-slate-400 text-xs font-mono">PHC-2026-1025</span></div>
      </div>

      <div>
        <p className="text-sm font-700 text-slate-600 mb-2">{t("select_eye")}</p>
        <div className="flex gap-2">
          {(["right","left"] as const).map(e => (
            <button key={e} onClick={() => setEye(e)} className={`flex-1 py-3 rounded-xl font-700 text-sm border-2 transition-all min-h-[48px] ${eye===e ? "border-cyan-500 bg-cyan-50 text-cyan-700" : "border-slate-200 text-slate-500"}`}>
              {e === "right" ? t("right_eye") : t("left_eye")}
            </button>
          ))}
        </div>
      </div>

      <div className="max-w-sm mx-auto w-full md:max-w-none">
        <div className="aspect-square rounded-2xl overflow-hidden bg-black border-2 border-slate-700 relative">
          {captured ? (
            <RetinalImage className="w-full h-full" alt="Captured retinal fundus image" />
          ) : (
            <div className="w-full h-full flex flex-col items-center justify-center bg-slate-900">
              <div className="w-24 h-24 md:w-32 md:h-32 rounded-full border-2 border-dashed border-slate-600 flex items-center justify-center mb-4">
                <EyeIcon className="w-8 h-8 md:w-10 md:h-10 text-slate-600" />
              </div>
              <p className="text-sm font-600 text-slate-500 text-center px-6">{t("viewfinder_msg")}</p>
              <p className="text-xs text-slate-600 mt-1">{t("viewfinder_sub")}</p>
            </div>
          )}
          {captured && <div className="absolute top-3 left-3 bg-green-500 text-white text-xs font-700 px-2 py-1 rounded-lg">{t("captured_label")}</div>}
          <div className="absolute top-3 right-3 bg-black/50 text-white text-xs font-700 px-2 py-1 rounded-lg">{eye==="right" ? t("right_eye") : t("left_eye")}</div>
        </div>
      </div>

      {captured && (
        <div className="bg-green-50 border border-green-200 rounded-xl p-4">
          <p className="font-700 text-green-800 mb-3">{t("quality_title")}</p>
          <div className="space-y-2">
            {(["retina_visible","focus_ok","brightness_ok"] as TKey[]).map(k => (
              <div key={k} className="flex items-center gap-2 text-green-700">
                <span className="w-5 h-5 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0"><CheckIcon className="w-3 h-3 text-white" /></span>
                <span className="text-sm font-600">{t(k)}</span>
              </div>
            ))}
          </div>
          <div className="mt-3 pt-3 border-t border-green-200 flex items-center gap-2">
            <span className="text-sm font-700 text-green-800">{t("quality_label")}</span>
            <span className="bg-green-500 text-white text-xs font-700 px-2.5 py-0.5 rounded-full">{t("quality_good")}</span>
          </div>
        </div>
      )}

      <div className="flex flex-col gap-3">
        {!captured ? (
          <>
            <button onClick={() => setCaptured(true)} className="w-full bg-cyan-600 hover:bg-cyan-700 active:bg-cyan-800 text-white font-700 py-4 rounded-xl transition-colors text-base shadow-sm min-h-[52px] flex items-center justify-center gap-2">{t("btn_capture")}</button>
            <button className="w-full border-2 border-slate-200 text-slate-700 font-700 py-3.5 rounded-xl min-h-[48px]">{t("btn_upload")}</button>
          </>
        ) : (
          <>
            <button onClick={onNext} className="w-full bg-cyan-600 hover:bg-cyan-700 text-white font-700 py-4 rounded-xl transition-colors text-base shadow-sm min-h-[52px]">{t("btn_proceed_ai")}</button>
            <button onClick={() => setCaptured(false)} className="w-full border-2 border-slate-200 text-slate-700 font-700 py-3.5 rounded-xl min-h-[48px]">{t("btn_retake")}</button>
          </>
        )}
      </div>
    </div>
  );
}

// ─── Screen: AI Analysis ──────────────────────────────────────────────────────

function AIAnalysisScreen({ onNext }: { onNext: () => void }) {
  const t = useT();
  const [progress, setProgress] = useState(0);
  const stepKeys: TKey[] = ["step_quality","step_retina","step_lesion","step_severity","step_explain"];
  useState(() => {
    const iv = setInterval(() => setProgress(p => { if (p >= stepKeys.length) { clearInterval(iv); return p; } return p+1; }), 900);
    return () => clearInterval(iv);
  });
  const done = progress >= stepKeys.length;
  return (
    <div className="max-w-xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={3} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("ai_title")}</h1><p className="text-slate-500 text-sm mt-0.5">{t("ai_subtitle")}</p></div>
      <div className="max-w-xs mx-auto w-full md:max-w-sm relative">
        <RetinalImage className="w-full aspect-square" alt="Retinal image under AI analysis" />
        {!done && <div className="absolute inset-0 flex items-center justify-center rounded-xl"><div className="bg-black/50 text-white text-sm font-700 px-4 py-2 rounded-xl">{t("analyzing")}</div></div>}
      </div>
      <div className="bg-white rounded-xl border border-slate-200 p-4 md:p-5 space-y-3">
        {stepKeys.map((key, i) => {
          const isDone = i < progress; const isActive = i === progress;
          return (
            <div key={key} className="flex items-center gap-3">
              <div className={`w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 ${isDone ? "bg-green-500" : isActive ? "bg-cyan-400 animate-pulse" : "bg-slate-200"}`}>
                {isDone && <CheckIcon className="w-3 h-3 text-white" />}
              </div>
              <span className={`text-sm font-600 ${isDone ? "text-green-700" : isActive ? "text-cyan-700" : "text-slate-400"}`}>{t(key)}</span>
            </div>
          );
        })}
      </div>
      <p className="text-xs text-center text-slate-400 px-4">{t("ai_disclaimer")}</p>
      {done && <button onClick={onNext} className="w-full bg-cyan-600 hover:bg-cyan-700 text-white font-700 py-4 rounded-xl transition-colors text-base shadow-sm min-h-[52px]">{t("btn_view_result")}</button>}
    </div>
  );
}

// ─── Screen: AI Result ────────────────────────────────────────────────────────

function AIResultScreen({ onNext }: { onNext: () => void }) {
  const t = useT();
  const sevKeys: TKey[] = ["sev_no_dr","sev_mild","sev_moderate","sev_severe","sev_pdr"];
  const currentIdx = 2;
  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={3} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("ai_result_title")}</h1>
        <p className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg px-3 py-1.5 inline-block mt-2">{t("awaiting_verif")}</p>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
        <div className="bg-amber-50 border-b border-amber-100 p-4 md:p-6">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-700 text-amber-700 uppercase tracking-wide">{t("ai_detected")}</p>
              <h2 className="text-2xl md:text-3xl font-800 text-amber-800 mt-0.5">{t("sev_moderate_npdr")}</h2>
            </div>
            <div className="text-right flex-shrink-0">
              <p className="text-xs font-700 text-slate-500">{t("confidence")}</p>
              <p className="text-2xl md:text-3xl font-800 text-slate-800">87%</p>
            </div>
          </div>
          <div className="mt-4">
            <p className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">{t("severity_scale")}</p>
            <div className="flex gap-1">
              {sevKeys.map((k, i) => (
                <div key={k} className="flex-1 text-center">
                  <div className={`h-2 rounded-full mb-1 ${i<currentIdx ? "bg-amber-300" : i===currentIdx ? "bg-amber-500" : "bg-slate-200"}`} />
                  <span className={`text-[9px] md:text-xs font-600 ${i===currentIdx ? "text-amber-700" : "text-slate-400"}`}>{t(k)}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="p-4 md:p-6 space-y-4">
          <div className="flex items-center gap-2">
            <span className="text-sm font-700 text-slate-600">{t("risk_level")}</span>
            <span className="bg-amber-100 text-amber-800 font-700 text-sm px-3 py-0.5 rounded-full">{t("risk_moderate")}</span>
          </div>
          <div>
            <p className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">{t("ai_findings")}</p>
            <div className="space-y-2">
              {(["finding_ma","finding_hm","finding_ex","finding_iq"] as TKey[]).map(k => (
                <div key={k} className="flex items-center gap-2">
                  <span className="w-4 h-4 bg-cyan-100 rounded-full flex items-center justify-center flex-shrink-0"><CheckIcon className="w-2.5 h-2.5 text-cyan-600" /></span>
                  <span className="text-sm text-slate-700 font-500">{t(k)}</span>
                </div>
              ))}
            </div>
          </div>
          <div>
            <p className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">{t("xai_label")}</p>
            <div className="grid grid-cols-2 gap-2 md:gap-3">
              <div><p className="text-[10px] md:text-xs text-center font-700 text-slate-500 mb-1.5">{t("original_fundus")}</p><RetinalImage className="w-full aspect-square" alt="Original retinal fundus photograph" /></div>
              <div><p className="text-[10px] md:text-xs text-center font-700 text-slate-500 mb-1.5">{t("ai_attn")}</p><RetinalImage className="w-full aspect-square" heatmap alt="AI heatmap overlay" /></div>
            </div>
            <p className="text-xs text-slate-400 mt-2 text-center">{t("heatmap_caption")}</p>
          </div>
        </div>
      </div>

      <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
        <p className="text-sm text-blue-800 font-500"><span className="font-700">{t("ai_note_label")}</span> {t("ai_note_text")}</p>
      </div>
      <button onClick={onNext} className="w-full bg-cyan-600 hover:bg-cyan-700 text-white font-700 py-4 rounded-xl transition-colors text-base shadow-sm min-h-[52px]">{t("btn_proceed_specialist")}</button>
    </div>
  );
}

// ─── Screen: Specialist Review ────────────────────────────────────────────────

function SpecialistScreen({ onNext }: { onNext: () => void }) {
  const t = useT();
  const [decision, setDecision] = useState<"confirm"|"change"|"reexamine"|null>(null);
  const [correctedSeverity, setCorrectedSeverity] = useState("Moderate NPDR");
  const [reason, setReason] = useState("");
  const [notes, setNotes] = useState("");
  const [showExplain, setShowExplain] = useState(false);

  const sevOptions: TKey[] = ["sev_no_dr","sev_mild_npdr","sev_moderate_npdr","sev_severe_npdr","sev_pdr"];

  const opts = [
    { key:"confirm" as const, lbl:"confirm_lbl" as TKey, sub:"confirm_sub" as TKey, icon:"✓", active:"border-green-500 bg-green-50", iconBg:"bg-green-100 text-green-700" },
    { key:"change"  as const, lbl:"change_lbl"  as TKey, sub:"change_sub"  as TKey, icon:"✏️",active:"border-amber-500 bg-amber-50", iconBg:"bg-amber-100 text-amber-700" },
    { key:"reexamine" as const,lbl:"reexamine_lbl" as TKey,sub:"reexamine_sub" as TKey,icon:"🔄",active:"border-slate-400 bg-slate-50",iconBg:"bg-slate-100 text-slate-600" },
  ];

  return (
    <div className="max-w-3xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={4} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("specialist_title")}</h1></div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div className="bg-white rounded-xl border border-slate-200 p-4 space-y-1.5">
          <p className="text-xs font-700 text-slate-400 uppercase tracking-wide">{t("col_patient")}</p>
          <p className="font-800 text-slate-800 text-lg">Meena Devi</p>
          <p className="text-xs text-slate-400 font-mono">PHC-2026-1025</p>
          <p className="text-sm text-slate-600 font-600">Female, 54 yrs · {t("right_eye")}</p>
        </div>
        <div className="bg-amber-50 rounded-xl border border-amber-200 p-4 space-y-1.5">
          <p className="text-xs font-700 text-amber-700 uppercase tracking-wide">{t("ai_result_card")}</p>
          <p className="font-800 text-amber-800 text-xl">{t("sev_moderate_npdr")}</p>
          <div className="flex gap-3 text-sm flex-wrap">
            <span className="text-slate-600 font-600">{t("confidence")}: <span className="text-slate-800 font-700">87%</span></span>
            <span className="text-slate-600 font-600">{t("risk_level")} <span className="text-amber-700 font-700">{t("risk_moderate")}</span></span>
          </div>
        </div>
      </div>

      <div>
        <p className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">{t("fundus_images")}</p>
        <div className="grid grid-cols-2 gap-2 md:gap-4">
          <div><p className="text-[10px] md:text-xs text-center font-700 text-slate-500 mb-1.5">{t("original_fundus")}</p><RetinalImage className="w-full aspect-square" alt="Original retinal fundus photograph" /></div>
          <div><p className="text-[10px] md:text-xs text-center font-700 text-slate-500 mb-1.5">{t("ai_attn")}</p><RetinalImage className="w-full aspect-square" heatmap alt="AI heatmap overlay" /></div>
        </div>
        <p className="text-xs text-slate-400 mt-2 text-center">{t("heatmap_caption")}</p>
        <button onClick={() => setShowExplain(!showExplain)} className="mt-2 text-sm font-700 text-cyan-700 underline underline-offset-2">{t("why_result")}</button>
        {showExplain && <div className="mt-2 bg-slate-50 rounded-xl border border-slate-200 p-4"><p className="text-sm text-slate-700 font-500">{t("why_result_text")}</p></div>}
      </div>

      <div>
        <p className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">{t("decision_label")}</p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-2 md:gap-3">
          {opts.map(opt => (
            <button key={opt.key} onClick={() => setDecision(opt.key)} className={`p-4 rounded-xl border-2 text-left transition-all min-h-[72px] flex items-center gap-3 md:flex-col md:items-start md:gap-0 ${decision===opt.key ? opt.active : "border-slate-200 bg-white"}`}>
              <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 md:mb-2 ${decision===opt.key ? opt.iconBg : "bg-slate-100"}`}><span className="text-base">{opt.icon}</span></div>
              <div><p className="font-700 text-slate-800 text-sm">{t(opt.lbl)}</p><p className="text-xs text-slate-500 mt-0.5">{t(opt.sub)}</p></div>
            </button>
          ))}
        </div>
        {decision==="change" && (
          <div className="mt-3 bg-white border border-slate-200 rounded-xl p-4">
            <p className="text-sm font-700 text-slate-700 mb-2">{t("select_severity")}</p>
            <div className="flex flex-wrap gap-2">
              {sevOptions.map(k => (
                <button key={k} onClick={() => setCorrectedSeverity(t(k))} className={`px-3 py-2 rounded-lg text-sm font-600 border-2 transition-all min-h-[40px] ${correctedSeverity===t(k) ? "border-cyan-500 bg-cyan-50 text-cyan-700" : "border-slate-200 text-slate-600"}`}>{t(k)}</button>
              ))}
            </div>
          </div>
        )}
        {decision==="reexamine" && (
          <div className="mt-3 bg-white border border-slate-200 rounded-xl p-4">
            <p className="text-sm font-700 text-slate-700 mb-2">{t("reason_lbl")}</p>
            <input value={reason} onChange={e => setReason(e.target.value)} placeholder={t("reason_ph")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 outline-none text-slate-800 font-600 text-sm" />
          </div>
        )}
      </div>

      <div className="bg-white rounded-xl border border-slate-200 p-4 md:p-5">
        <p className="text-sm font-700 text-slate-700 mb-2">{t("notes_lbl")}</p>
        <textarea value={notes} onChange={e => setNotes(e.target.value)} rows={3} placeholder={t("notes_ph")} className="w-full px-3.5 py-3 rounded-lg border border-slate-300 focus:border-cyan-500 outline-none text-slate-800 font-600 text-sm resize-none" />
      </div>

      <button onClick={onNext} disabled={!decision} className={`w-full font-700 py-4 rounded-xl transition-colors text-base shadow-sm min-h-[52px] ${decision ? "bg-cyan-600 hover:bg-cyan-700 text-white" : "bg-slate-100 text-slate-400 cursor-not-allowed"}`}>{t("btn_verify")}</button>
    </div>
  );
}

// ─── Screen: Referral ─────────────────────────────────────────────────────────

function ReferralScreen({ onNext }: { onNext: () => void }) {
  const t = useT();
  return (
    <div className="max-w-xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={4} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("referral_title")}</h1></div>

      <div className="bg-red-50 border-2 border-red-200 rounded-2xl p-5 text-center">
        <div className="text-4xl mb-2">🏥</div>
        <h2 className="text-xl md:text-2xl font-800 text-red-800">{t("referral_required")}</h2>
        <div className="flex justify-center gap-6 mt-3">
          <div><p className="text-xs text-red-600 font-700 uppercase">{t("sev_label")}</p><p className="font-800 text-red-800">{t("sev_moderate_npdr")}</p></div>
          <div className="border-l border-red-200" />
          <div><p className="text-xs text-red-600 font-700 uppercase">{t("urgency_label")}</p><p className="font-800 text-red-800">{t("risk_moderate")}</p></div>
        </div>
        <p className="text-sm text-red-700 mt-3 font-600">{t("referral_msg")}</p>
      </div>

      <div className="bg-white rounded-xl border border-slate-200 p-4 md:p-5 space-y-2.5">
        <p className="font-700 text-slate-700 text-xs uppercase tracking-wide">{t("recommended_specialist")}</p>
        {[["Hospital","District Eye Care Centre [DEMO]"],["Department","Retina & Vitreous Clinic"],["Contact","+91 XXXXX XXXXX [Demo]"],["Location","District HQ, ~22 km"],["Availability","Mon, Wed, Fri — 9 AM to 1 PM"]].map(([l,v]) => (
          <div key={l} className="flex gap-3"><span className="text-sm font-700 text-slate-500 w-24 flex-shrink-0">{l}</span><span className="text-sm text-slate-800 font-600">{v}</span></div>
        ))}
      </div>

      <div className="flex flex-col gap-3">
        <button className="w-full bg-cyan-600 hover:bg-cyan-700 text-white font-700 py-4 rounded-xl min-h-[52px]">{t("btn_send_referral")}</button>
        <button className="w-full border-2 border-slate-200 text-slate-700 font-700 py-3.5 rounded-xl min-h-[48px]">{t("btn_send_sms")}</button>
        <button onClick={onNext} className="text-center text-sm font-700 text-cyan-700 py-2 min-h-[44px] flex items-center justify-center">{t("btn_continue_report")}</button>
      </div>
    </div>
  );
}

// ─── Screen: Final Report ─────────────────────────────────────────────────────

function ReportScreen({ onRestart }: { onRestart: () => void }) {
  const t = useT();
  const [showMore, setShowMore] = useState(false);
  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><WorkflowBar step={5} /><h1 className="text-xl md:text-2xl font-800 text-slate-900 mt-4">{t("report_title")}</h1><p className="text-xs text-slate-400 font-mono mt-0.5">PHC-2026-1025 · 11 Sep 2026</p></div>

      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
        <div className="border-b border-slate-100 px-4 md:px-6 py-4 flex items-center gap-3">
          <EyeIcon className="w-5 h-5 text-cyan-600 flex-shrink-0" />
          <div className="min-w-0"><p className="font-800 text-slate-800 text-sm md:text-base">{t("report_header")}</p><p className="text-xs text-slate-400">{t("demo_report")}</p></div>
          <div className="ml-auto flex-shrink-0"><span className="bg-green-100 text-green-700 text-xs font-700 px-2.5 py-1 rounded-full">✓ {t("sp_verified")}</span></div>
        </div>

        <div className="p-4 md:p-6 space-y-4">
          <div>
            <p className="text-xs font-700 text-slate-400 uppercase tracking-wide mb-2">{t("patient_details")}</p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-1.5 text-sm">
              {[["Name","Meena Devi"],["Patient ID","PHC-2026-1025"],["Age / Gender","54 years, Female"],["Village / PHC","Rampur, Sitapur PHC"],["Eye Screened","Right Eye (OD)"],["Date","11 September 2026"]].map(([k,v]) => (
                <div key={k}><span className="text-slate-500 font-600">{k}: </span><span className="text-slate-800 font-700">{v}</span></div>
              ))}
            </div>
          </div>

          <div className="border-t border-slate-100" />

          <div>
            <p className="text-xs font-700 text-slate-400 uppercase tracking-wide mb-2">{t("ai_result_title")}</p>
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
              <div className="flex items-start justify-between gap-3">
                <div><p className="font-800 text-amber-800 text-lg md:text-xl">{t("sev_moderate_npdr")}</p><p className="text-sm text-amber-700 mt-0.5">{t("confidence")}: <span className="font-700">87%</span> · {t("risk_level")} <span className="font-700">{t("risk_moderate")}</span></p></div>
                <span className="text-xs bg-amber-200 text-amber-800 font-700 px-2 py-0.5 rounded-full flex-shrink-0">AI</span>
              </div>
            </div>
          </div>

          <div>
            <p className="text-xs font-700 text-slate-400 uppercase tracking-wide mb-2">{t("key_findings")}</p>
            <div className="space-y-1.5">
              {(["finding_ma","finding_hm","finding_ex","grad_cam"] as TKey[]).map(k => (
                <div key={k} className="flex items-center gap-2 text-slate-700"><CheckIcon className="w-4 h-4 text-cyan-500 flex-shrink-0" /><span className="text-sm font-600">{t(k)}</span></div>
              ))}
            </div>
          </div>

          <div className="border-t border-slate-100" />

          <div className="bg-green-50 border border-green-200 rounded-xl p-4 space-y-1">
            <div className="flex items-center gap-2"><span className="w-5 h-5 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0"><CheckIcon className="w-3 h-3 text-white" /></span><span className="font-700 text-green-800">{t("sp_verified")}</span></div>
            <p className="text-sm text-green-700 ml-7">{t("verified_msg")}</p>
          </div>

          <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
            <p className="text-sm font-700 text-blue-800">{t("recommended_action")}</p>
            <p className="text-sm text-blue-700 mt-0.5">{t("action_msg")}</p>
          </div>

          {showMore && (
            <div className="border-t border-slate-100 pt-4">
              <p className="text-xs font-700 text-slate-400 uppercase tracking-wide mb-2">{t("technical_export")}</p>
              <div className="flex gap-2 flex-wrap">
                {["FHIR Export","HL7 Export","API Reference"].map(o => <button key={o} className="text-xs border border-slate-200 text-slate-500 px-3 py-2 rounded-lg hover:bg-slate-50 min-h-[36px]">{o}</button>)}
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <div className="grid grid-cols-2 gap-3">
          <button className="bg-cyan-600 hover:bg-cyan-700 text-white font-700 py-3.5 rounded-xl min-h-[48px] text-sm">{t("btn_download")}</button>
          <button className="border-2 border-slate-200 text-slate-700 font-700 py-3.5 rounded-xl min-h-[48px] text-sm">{t("btn_sms")}</button>
        </div>
        <button onClick={onRestart} className="w-full bg-slate-800 hover:bg-slate-900 text-white font-700 py-4 rounded-xl min-h-[52px] text-base">{t("btn_new_screening")}</button>
        <button onClick={() => setShowMore(!showMore)} className="text-xs text-slate-400 hover:text-slate-500 font-600 py-2 min-h-[40px]">{showMore ? t("btn_hide") : t("btn_more")}</button>
      </div>
    </div>
  );
}

// ─── Screen: Patient History ──────────────────────────────────────────────────

function HistoryScreen() {
  const t = useT();
  const sevClr: Record<string, string> = {
    moderate: "bg-amber-50 border-amber-200 text-amber-800",
    mild:     "bg-yellow-50 border-yellow-200 text-yellow-800",
    none:     "bg-green-50 border-green-200 text-green-800",
  };
  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <h1 className="text-xl md:text-2xl font-800 text-slate-900">{t("history_title")}</h1>
      <div className="bg-white rounded-xl border border-slate-200 p-4 md:p-5">
        <div className="flex items-start justify-between gap-3">
          <div><p className="font-800 text-slate-800 text-lg md:text-xl">Meena Devi</p><p className="text-xs md:text-sm font-mono text-slate-400 mt-0.5">PHC-2026-1025</p></div>
          <div className="text-right text-sm flex-shrink-0"><p className="text-slate-500">Age: <span className="font-700 text-slate-700">54</span></p><p className="text-slate-500">Female</p></div>
        </div>
        <div className="mt-3 pt-3 border-t border-slate-100 flex flex-col md:flex-row md:gap-4 gap-1 text-sm">
          <p className="text-slate-500">Village: <span className="font-600 text-slate-700">Rampur, Sitapur PHC</span></p>
          <p className="text-slate-500">Diabetes: <span className="font-600 text-slate-700">8 years</span></p>
        </div>
      </div>
      <div>
        <h2 className="text-base md:text-lg font-700 text-slate-800 mb-4">{t("screening_history")}</h2>
        <div className="space-y-4">
          {HISTORY_SCREENINGS.map((s, i) => (
            <div key={i} className="flex gap-3 md:gap-4">
              <div className="flex flex-col items-center">
                <div className="w-3 h-3 bg-cyan-500 rounded-full mt-1.5 flex-shrink-0" />
                {i < HISTORY_SCREENINGS.length - 1 && <div className="w-0.5 bg-slate-200 flex-1 mt-1" />}
              </div>
              <div className="flex-1 pb-4">
                <p className="text-xs font-700 text-slate-400 mb-1.5">{s.date}</p>
                <div className="bg-white rounded-xl border border-slate-200 p-3 md:p-4 flex items-center justify-between gap-3">
                  <div className="flex gap-3 items-center min-w-0">
                    <RetinalImage className="w-12 h-12 md:w-14 md:h-14 flex-shrink-0" heatmap={i===0} alt="Historical retinal fundus image" />
                    <div className="min-w-0">
                      <span className={`text-xs md:text-sm font-700 px-2 py-0.5 rounded-full border ${sevClr[s.severity]}`}>{s.result}</span>
                      <p className="text-xs text-slate-500 mt-1 font-600">{s.status}</p>
                    </div>
                  </div>
                  <button className="text-xs text-cyan-700 font-700 flex-shrink-0 min-h-[44px] flex items-center">View →</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Screen: Offline Queue ────────────────────────────────────────────────────

function OfflineQueueScreen() {
  const t = useT();
  const [syncing, setSyncing] = useState(false);
  const [synced, setSynced] = useState(false);
  const cases = [
    { id:"PHC-2026-1020", name:"Kamla Yadav",  eye:"Right Eye (OD)", time:"10:42 AM" },
    { id:"PHC-2026-1019", name:"Vinod Gupta",  eye:"Left Eye (OS)",  time:"09:15 AM" },
    { id:"PHC-2026-1018", name:"Parvati Devi", eye:"Right Eye (OD)", time:"Yesterday" },
  ];
  const handleSync = () => { setSyncing(true); setTimeout(() => { setSyncing(false); setSynced(true); }, 2500); };
  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-5">
      <div><div className="flex items-center gap-2 mb-1"><span className="text-2xl">📡</span><h1 className="text-xl md:text-2xl font-800 text-slate-900">{t("offline_title")}</h1></div><p className="text-slate-500 text-sm">{t("offline_subtitle")}</p></div>
      <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex items-center gap-3">
        <span className="w-3 h-3 bg-amber-400 rounded-full flex-shrink-0" />
        <div><p className="font-700 text-slate-800 text-sm md:text-base">{t("limited_connectivity")}</p><p className="text-xs md:text-sm text-slate-500">3 {t("cases_waiting")}</p></div>
      </div>
      {!synced ? (
        <>
          <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
            {cases.map((c, i) => (
              <div key={c.id} className={`px-4 py-4 flex items-center justify-between gap-3 ${i<cases.length-1?"border-b border-slate-100":""}`}>
                <div className="min-w-0"><p className="font-700 text-slate-800 text-sm">{c.name}</p><p className="text-xs font-mono text-slate-400">{c.id}</p><p className="text-xs text-slate-500 mt-0.5 md:hidden">{c.eye}</p></div>
                <div className="hidden md:block text-sm text-slate-600 font-600 text-center">{c.eye}</div>
                <div className="text-right flex-shrink-0"><p className="text-xs text-slate-500 font-600">{c.time}</p><span className="text-xs bg-slate-100 text-slate-500 font-700 px-2 py-0.5 rounded-full">{t("waiting_lbl")}</span></div>
              </div>
            ))}
          </div>
          <button onClick={handleSync} disabled={syncing} className={`w-full font-700 py-4 rounded-xl min-h-[52px] text-base ${syncing?"bg-slate-200 text-slate-500":"bg-cyan-600 hover:bg-cyan-700 text-white shadow-sm"}`}>{syncing ? t("syncing") : t("btn_sync")}</button>
        </>
      ) : (
        <div className="bg-green-50 border border-green-200 rounded-xl p-5 md:p-6 space-y-3">
          <h2 className="font-800 text-green-800 text-lg md:text-xl">{t("sync_complete")}</h2>
          {(["sync1","sync2","sync3"] as TKey[]).map(k => (
            <div key={k} className="flex items-center gap-2 text-green-700">
              <span className="w-5 h-5 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0"><CheckIcon className="w-3 h-3 text-white" /></span>
              <span className="text-sm font-600">{t(k)}</span>
            </div>
          ))}
        </div>
      )}
      <p className="text-center text-xs text-slate-400">{t("encrypt_note")}</p>
    </div>
  );
}

// ─── Screen: Help ─────────────────────────────────────────────────────────────

function HelpScreen() {
  const t = useT();
  const [open, setOpen] = useState<number|null>(0);
  const faqs: [TKey, React.ReactNode][] = [
    ["help_q1", (
      <ol className="list-decimal list-inside space-y-1.5 text-sm text-slate-700 ml-1">
        <li>Position the patient in front of the fundus camera.</li>
        <li>Ask the patient to keep their eye wide open and look at the fixation light.</li>
        <li>Adjust the camera focus until the retina appears clear.</li>
        <li>Capture when the optic disc and macula are both visible.</li>
        <li>If quality check fails, retake the image.</li>
      </ol>
    )],
    ["help_q2", (
      <div className="space-y-2 text-sm text-slate-700">
        <p>The AI analyses the retinal image and estimates DR severity.</p>
        <div className="space-y-1.5 mt-2">
          {[["No DR","No signs detected."],["Mild NPDR","Early signs — microaneurysms."],["Moderate NPDR","More changes — specialist review."],["Severe NPDR","Many changes — referral needed."],["PDR","Advanced — urgent referral."]].map(([l,d]) => (
            <div key={l} className="flex gap-2"><span className="font-700 text-cyan-700 w-28 flex-shrink-0 text-xs md:text-sm">{l}:</span><span className="text-xs md:text-sm">{d}</span></div>
          ))}
        </div>
        <p className="text-xs text-slate-400 mt-3 font-600">{t("ai_disclaimer")}</p>
      </div>
    )],
    ["help_q3", (
      <ul className="list-disc list-inside space-y-1.5 text-sm text-slate-700 ml-1">
        <li>Moderate NPDR or higher severity</li>
        <li>Any vision-threatening changes detected</li>
        <li>No specialist review in 12 months</li>
        <li>Specialist requests re-examination</li>
      </ul>
    )],
    ["help_q4", (
      <ul className="list-disc list-inside space-y-1.5 text-sm text-slate-700 ml-1">
        <li>Images are securely saved on the device.</li>
        <li>Cases appear in the Offline Queue.</li>
        <li>When connectivity returns, press <strong>Sync Now</strong>.</li>
        <li>AI analysis and specialist review proceed automatically.</li>
      </ul>
    )],
  ];
  return (
    <div className="max-w-2xl mx-auto px-4 md:px-6 py-6 space-y-4">
      <div><h1 className="text-xl md:text-2xl font-800 text-slate-900">{t("help_title")}</h1><p className="text-slate-500 text-sm mt-0.5">{t("help_subtitle")}</p></div>
      <div className="space-y-2">
        {faqs.map(([key, body], i) => (
          <div key={i} className="bg-white rounded-xl border border-slate-200 overflow-hidden">
            <button onClick={() => setOpen(open===i?null:i)} className="w-full px-4 md:px-5 py-4 flex items-center justify-between gap-3 text-left hover:bg-slate-50 active:bg-slate-100 min-h-[56px]">
              <span className="font-700 text-slate-800 text-sm md:text-base">{t(key)}</span>
              <span className={`text-slate-400 text-lg flex-shrink-0 transition-transform duration-200 ${open===i?"rotate-180":""}`}>⌄</span>
            </button>
            {open===i && <div className="px-4 md:px-5 pb-5 border-t border-slate-100 pt-4">{body}</div>}
          </div>
        ))}
      </div>
      <div className="bg-cyan-50 border border-cyan-200 rounded-xl p-4 md:p-5">
        <p className="font-700 text-cyan-800 mb-0.5">{t("need_help")}</p>
        <p className="text-sm text-cyan-700">{t("need_help_msg")}</p>
      </div>
    </div>
  );
}

// ─── App Shell ────────────────────────────────────────────────────────────────

export default function App() {
  const [screen, setScreen] = useState<Screen>("dashboard");
  const [lang, setLang] = useState<Lang>("en");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [isOffline] = useState(false);

  const t = (k: TKey): string => (T[lang] as typeof T.en)[k] ?? T.en[k];
  const nav = (s: Screen) => { setScreen(s); setDrawerOpen(false); };
  const next = (s: Screen) => () => setScreen(s);

  return (
    <LangCtx.Provider value={{ lang, t }}>
      <div className="flex flex-col h-full bg-slate-50" style={{ fontFamily: "'Nunito', sans-serif" }}>
        <TopHeader screen={screen} onNav={nav} isOffline={isOffline} lang={lang} setLang={setLang} onHamburger={() => setDrawerOpen(true)} />

        <MobileDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} screen={screen} onNav={nav} isOffline={isOffline} />

        <div className="flex flex-1 min-h-0">
          <Sidebar screen={screen} onNav={nav} isOffline={isOffline} />

          <main className="flex-1 overflow-y-auto">
            {screen === "dashboard"    && <DashboardScreen onStart={next("register")} onNav={nav} />}
            {screen === "register"     && <RegisterScreen onNext={next("capture")} />}
            {screen === "capture"      && <CaptureScreen onNext={next("ai-analysis")} />}
            {screen === "ai-analysis"  && <AIAnalysisScreen onNext={next("ai-result")} />}
            {screen === "ai-result"    && <AIResultScreen onNext={next("specialist")} />}
            {screen === "specialist"   && <SpecialistScreen onNext={next("referral")} />}
            {screen === "referral"     && <ReferralScreen onNext={next("report")} />}
            {screen === "report"       && <ReportScreen onRestart={next("dashboard")} />}
            {screen === "history"      && <HistoryScreen />}
            {screen === "offline-queue"&& <OfflineQueueScreen />}
            {screen === "help"         && <HelpScreen />}

            <footer className="hidden md:block border-t border-slate-200 bg-white mt-8 py-4 px-6">
              <p className="text-center text-xs text-slate-400">Drishti-AI · Diabetic Retinopathy Screening · Demo Prototype · Not for clinical use</p>
            </footer>
          </main>
        </div>
      </div>
    </LangCtx.Provider>
  );
}
