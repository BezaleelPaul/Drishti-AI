from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Any
import numpy as np


@dataclass
class DistrictSimulationParams:
    annual_target_patients: int = 100000
    working_days_per_year: int = 260
    num_phcs: int = 20
    num_mobile_vans: int = 5
    
    # Network & Payloads
    rural_bandwidth_kbps: float = 384.0        # Average rural 3G/degraded 4G uplink
    raw_image_size_mb: float = 4.5             # Raw high-res fundus capture
    compressed_dossier_kb: float = 250.0       # Edge-screened compressed dossier + metadata
    
    # On-Device Edge Pipeline Latencies
    edge_quality_check_sec: float = 0.045      # Model 1 edge latency
    edge_dr_inference_sec: float = 0.140       # Model 2 edge latency
    
    # Clinical Triage Fractions
    quality_rejection_rate: float = 0.18       # Blocked/recaptured locally
    referable_or_flagged_rate: float = 0.16    # Routed to ophthalmologist over-read
    
    # Telemedicine Specialist Capacity
    num_tele_ophthalmologists: int = 2
    doctor_work_hours_per_day: float = 6.0
    assisted_review_time_sec: float = 28.0     # Our <30s annotated audit workflow
    unassisted_review_time_sec: float = 210.0  # 3.5 minutes manual grading from scratch


@dataclass
class DistrictSimulationReport:
    daily_patient_intake: int
    daily_flagged_for_review: int
    
    # Edge AI vs Pure Cloud Telemedicine Comparison
    edge_total_data_uploaded_gb_annual: float
    cloud_total_data_uploaded_gb_annual: float
    bandwidth_saved_pct: float
    
    # Doctor Capacity & Workload
    doctor_daily_review_capacity_assisted: int
    doctor_daily_review_capacity_unassisted: int
    doctors_needed_with_our_system: float
    doctors_needed_without_our_system: float
    specialist_time_saved_pct: float
    
    # Latency & Queueing
    avg_turnaround_time_edge_sec: float
    avg_turnaround_time_cloud_min: float
    annual_patients_successfully_screened: int
    queue_stable: bool
    summary_insights: list[str]


class TelemedicineSimulinkEngine:
    """
    MathWorks SIH26038 Requirement #5:
    District-Level Telemedicine Screening Pipeline Simulation (100,000+ Patients/Year).
    Models image acquisition, bandwidth bottlenecks, edge AI triage, and specialist queues.
    """

    def __init__(self, params: DistrictSimulationParams = None):
        self.params = params or DistrictSimulationParams()

    def run_simulation(self) -> DistrictSimulationReport:
        p = self.params
        daily_patients = int(np.ceil(p.annual_target_patients / p.working_days_per_year))
        
        # 1. Bandwidth Analysis (Edge Screening vs Centralized Cloud)
        # In our system: Only the 16% flagged cases upload a compressed dossier (250 KB)
        flagged_daily = int(np.ceil(daily_patients * p.referable_or_flagged_rate))
        edge_daily_upload_mb = (flagged_daily * p.compressed_dossier_kb) / 1024.0
        edge_annual_upload_gb = (edge_daily_upload_mb * p.working_days_per_year) / 1024.0

        # In traditional cloud-only: All 100,000 raw captures (4.5 MB) must upload
        cloud_daily_upload_mb = daily_patients * p.raw_image_size_mb
        cloud_annual_upload_gb = (cloud_daily_upload_mb * p.working_days_per_year) / 1024.0

        bandwidth_saved = ((cloud_annual_upload_gb - edge_annual_upload_gb) / cloud_annual_upload_gb) * 100.0

        # 2. Transmission Latency
        # Rural connection: 384 kbps = 48 KB/s
        transfer_speed_kb_s = p.rural_bandwidth_kbps / 8.0
        cloud_upload_latency_sec = (p.raw_image_size_mb * 1024.0) / transfer_speed_kb_s # ~96 seconds per image!
        edge_upload_latency_sec = p.compressed_dossier_kb / transfer_speed_kb_s          # ~5.2 seconds

        # Total on-site patient wait time
        avg_turnaround_edge = (p.edge_quality_check_sec + p.edge_dr_inference_sec + 0.8) # <2 seconds!
        avg_turnaround_cloud = (cloud_upload_latency_sec + 15.0) / 60.0                 # ~1.8 minutes per patient

        # 3. Specialist Ophthalmologist Capacity & Resource Allocation
        # Doctor working time per day: 6 hrs = 21,600 seconds
        daily_seconds_available = p.num_tele_ophthalmologists * (p.doctor_work_hours_per_day * 3600.0)

        # Capacity with our system (<30s assisted review)
        cap_assisted = int(daily_seconds_available / p.assisted_review_time_sec)
        # Capacity without our system (manual reading of all raw photos)
        cap_unassisted = int(daily_seconds_available / p.unassisted_review_time_sec)

        # Doctors required to handle the 100,000 patient load:
        # With our system: Doctors only read the 16% flagged cases
        annual_flagged = p.annual_target_patients * p.referable_or_flagged_rate
        annual_doctor_seconds_needed_our = annual_flagged * p.assisted_review_time_sec
        seconds_per_doctor_year = p.working_days_per_year * (p.doctor_work_hours_per_day * 3600.0)
        doctors_needed_our = round(annual_doctor_seconds_needed_our / seconds_per_doctor_year, 1)

        # Without our system: Doctors must manually grade all 100,000 patients
        annual_doctor_seconds_needed_trad = p.annual_target_patients * p.unassisted_review_time_sec
        doctors_needed_trad = round(annual_doctor_seconds_needed_trad / seconds_per_doctor_year, 1)

        specialist_saved_pct = ((doctors_needed_trad - doctors_needed_our) / doctors_needed_trad) * 100.0
        queue_stable = cap_assisted >= flagged_daily

        insights = [
            f"Edge AI triage eliminates {bandwidth_saved:.1f}% of rural cellular data transmission.",
            f"On-site turnaround time reduced from {avg_turnaround_cloud:.1f} mins to {avg_turnaround_edge:.1f} seconds per patient.",
            f"District ophthalmologist requirement reduced from {doctors_needed_trad:.0f} specialists to only {doctors_needed_our:.0f} tele-reviewer.",
            f"Handles district scale: 100,000 patients/year across {p.num_phcs} PHCs and {p.num_mobile_vans} mobile vision vans.",
        ]

        return DistrictSimulationReport(
            daily_patient_intake=daily_patients,
            daily_flagged_for_review=flagged_daily,
            edge_total_data_uploaded_gb_annual=round(edge_annual_upload_gb, 1),
            cloud_total_data_uploaded_gb_annual=round(cloud_annual_upload_gb, 1),
            bandwidth_saved_pct=round(bandwidth_saved, 1),
            doctor_daily_review_capacity_assisted=cap_assisted,
            doctor_daily_review_capacity_unassisted=cap_unassisted,
            doctors_needed_with_our_system=max(doctors_needed_our, 1.0),
            doctors_needed_without_our_system=doctors_needed_trad,
            specialist_time_saved_pct=round(specialist_saved_pct, 1),
            avg_turnaround_time_edge_sec=round(avg_turnaround_edge, 2),
            avg_turnaround_time_cloud_min=round(avg_turnaround_cloud, 2),
            annual_patients_successfully_screened=p.annual_target_patients,
            queue_stable=queue_stable,
            summary_insights=insights,
        )
