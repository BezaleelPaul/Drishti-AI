# ⚡ 05. Interactive Prototype Guide
## How to Wire the Figma Click-Flow for an Unbeatable Demo

Connecting your screens in Figma's **Prototype Mode** transforms static pictures into a living, breathing application that will stun the judges.

---

### 1. Prototype Connection Architecture

In Figma, click the **Prototype** tab on the top right. Link the frames as follows:

```
[Screen 1: Patient Intake]
       │
       ▼ (On Tap: "Proceed to Retinal Scan")
[Screen 2: Retinal Viewfinder]
       │
       ├──► (On Tap Shutter / Bad Scenario Button)
       │         │
       │         ▼
       │    [Screen 3A: Quality Rejection (Blurry)]
       │         │
       │         ▼ (On Tap: "Hindi Audio Guide")
       │    [Audio Bubble Overlay: "कृपया कैमरा 2 सेमी पास लाएं"]
       │         │
       │         ▼ (On Tap: "Retake Photo")
       │    [Returns to Screen 2]
       │
       └──► (On Tap Shutter / Good Scenario Button)
                 │
                 ▼
            [Screen 3B: Quality Verified (Pass)]
                 │
                 ▼ (On Tap: "Run AI Diagnostic Triage")
            [Screen 4: Diagnostic Verdict & Heatmap]
                 │
                 ▼ (On Tap: "Generate Referral Slip")
            [Screen 5: Referral Dispatch & SMS Hub]
                 │
                 ▼ (On Tap: "Send Free SMS")
            [Toast Banner: "SMS Sent to +91 98451 22340 ✅"]
```

---

### 2. Best Figma Transition Settings
* **Screen Transitions:**
  * Action: `Navigate to`
  * Animation: `Smart Animate`
  * Easing: `Ease Out`
  * Duration: `300ms`
* **Audio / Alignment Tips Overlay:**
  * Action: `Open Overlay`
  * Position: `Bottom Center`
  * Animation: `Move In` from `Bottom`
  * Duration: `250ms`

---

### 3. How to Record a 45-Second Demo Video for the Pitch
Judges are blown away when they see an actual mobile recording in the slide deck:
1. In Figma, hit the **Present** button (▶️ on top right).
2. Choose **Device Frame: Google Pixel 7 or iPad Mini**.
3. Use **OBS Studio**, **Xbox Game Bar (Win + G)**, or QuickTime to record your screen.
4. Walk through the scenario:
   - Tap "Scan ABHA" $\to$ Tap Shutter $\to$ Show Blurry Reject $\to$ Tap Hindi Audio $\to$ Tap Good Scan $\to$ Show Grad-CAM & 1-tap SMS.
5. Save as MP4 or convert to a GIF to drop into PowerPoint!
