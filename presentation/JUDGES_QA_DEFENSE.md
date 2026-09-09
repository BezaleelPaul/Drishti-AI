# SIH 2026 Judges Q&A Defense Sheet
## Problem Statement SIH26038 (MathWorks) — Retinal Screening

---

### Q1: "Why can't you just use a normal smartphone camera or webcam instead of a fundus camera?"
**Respondent:** Madhu (Clinical / Biomedical Lead)
**Winning Answer:**
> *"Biologically and optically, the human pupil acts as an aperture, and the cornea/crystalline lens have a combined refractive power of ~+60 diopters. A standard phone camera or webcam placed in front of an eye will only image the anterior cornea, iris, and corneal reflections.
> To image the posterior retina (fundus), the optical path requires a specialized condensing lens (typically 20D to 28D) or an indirect ophthalmoscope attachment that matches the focal length of the human eye and separates the illumination path from the observation path to eliminate corneal glare.
> Our system is designed for low-cost, portable handheld fundus attachments (like Forus 3nethra, Remidio Fundus on Phone, or Volk iNview costing ~1/10th of a tabletop Zeiss fundus camera) which can easily be operated by ASHA or PHC workers."*

---

### Q2: "What prevents your image enhancement (CLAHE) from hallucinating lesions or altering clinical truth?"
**Respondent:** Bezaleel (Architecture / Pipeline Lead)
**Winning Answer:**
> *"That is precisely our core architectural innovation: Non-Destructive Retinal Handling. In our pipeline:
> 1. CLAHE and bilateral filtering in the LAB color space are applied solely to the L-channel for contrast normalization and structure segmentation.
> 2. The Model 2 DR classifier receives an illumination-normalized input where pixel clip limits are capped at 2.0 to prevent edge distortion or artifact generation.
> 3. Most importantly, if an image is fundamentally blurred or out-of-focus, we NEVER attempt to 'deblur' or 'sharpen' it into a fake diagnosis. We reject it at Model 1 and demand a recapture. The AI never guesses."*

---

### Q3: "Explainability using Grad-CAM often highlights random backgrounds. How do you guarantee clinical explainability?"
**Respondent:** Akshay (Deep Learning Lead)
**Winning Answer:**
> *"Grad-CAM computes the gradient of the predicted class score with respect to the feature map of the final convolutional layer (`top_activation` in EfficientNetB0). 
> Furthermore, in our pipeline:
> 1. We cross-verify Grad-CAM activations with our Requirement 2 Anatomical Structure Segmenter (Optic Disc, Fovea, and vessel mask).
> 2. We maintain honest clinical claim boundaries: we explicitly inform the clinician that Grad-CAM represents an activation focus map, NOT automated lesion boundary segmentation.
> 3. All Grad-CAM overlays are computed in 1.14 seconds, far beating the MathWorks requirement of <30 seconds."*

---

### Q4: "Why did you choose EfficientNetB0 over ResNet50 or Vision Transformers?"
**Respondent:** Akshay (Deep Learning Lead)
**Winning Answer:**
> *"In rural primary health centers, high-end NVIDIA GPUs with high power consumption are not feasible. EfficientNetB0 utilizes compound scaling (balancing depth, width, and resolution) with inverted residual mobile blocks (MBConv). 
> It provides 77.1% ImageNet top-1 accuracy with only 5.3 million parameters (compared to 25.6 million in ResNet-50 and 86 million in ViT-Base).
> This allows Drishti-AI to run full inference, Grad-CAM, and segmentation in ~1.2 seconds on an ordinary dual-core laptop CPU without requiring a GPU or cloud connectivity."*

---

### Q5: "How does your MATLAB/Simulink model reflect actual rural telemedicine constraints?"
**Respondent:** Akshay / Adithya (Simulink & Operations Lead)
**Winning Answer:**
> *"Our Simulink and MATLAB model implements a discrete-event M/M/c queuing network parameterized on real-world Indian health statistics:
> - 100,000 patients/year across 50 Primary Health Centres.
> - Poisson arrival rates during outpatient camp hours.
> - By deploying edge AI at the PHCs, 70% of healthy patients (Grade 0) receive clear reports instantly without network transfer.
> - Only flagged, uncertain, or referable cases are queued for tele-consultation, reducing uplink bandwidth from 250 GB to 3.4 GB (a 98.6% saving) and making the system 100% resilient to 2G/3G rural cellular connections."*

---

### Q6: "What if the AI makes an error on an early-stage DR patient?"
**Respondent:** Adithya (Safety & Operations Lead)
**Winning Answer:**
> *"We implement a multi-layered safety net:
> 1. Our binary referable threshold is set conservatively at Grade 2 (Moderate NPDR), where treatment/monitoring is required.
> 2. Any prediction with softmax confidence under 60% or a narrow difference (<0.15) between Grade 1 and Grade 2 is automatically flagged as 'CLINICAL_LEVEL: Low Confidence' and routed for human specialist over-read.
> 3. Patients who pass through our Stage 1 upstream diabetes risk engine with high HbA1c/symptoms are scheduled for periodic annual re-screening regardless of a single Grade 0 reading."*
