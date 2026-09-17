"""Clinical care pathways mapping triage urgency to actionable clinical care pathways."""
from typing import List
from dataclasses import dataclass

CARE_PATHWAY_MAP = {
    "EMERGENCY": "EMERGENCY_REFERRAL",
    "HIGH_RISK": "URGENT_CONSULTATION",
    "LOW_RISK": "ROUTINE_CONSULTATION",
    "URGENT": "URGENT_CONSULTATION",
    "ROUTINE": "ROUTINE_CONSULTATION"
}

@dataclass
class CarePathwayPlan:
    triage_level: str
    care_pathway: str
    recommendation: str
    urgency_description: str
    action_instructions: List[str]
    booking_allowed: bool

def determine_care_pathway(triage_level: str, reason_codes: List[str] = None) -> CarePathwayPlan:
    """Determines the appropriate clinical care pathway and patient guidance."""
    level = triage_level.upper()

    if level == "EMERGENCY":
        return CarePathwayPlan(
            triage_level="EMERGENCY",
            care_pathway="EMERGENCY_REFERRAL",
            recommendation="Seek immediate emergency medical care or call 108/112 ambulance.",
            urgency_description="Life-threatening clinical danger sign detected requiring immediate resuscitation/stabilization.",
            action_instructions=[
                "Immediately contact nearest hospital emergency department or dial 108/112.",
                "Do not drive yourself; have an ambulance or caregiver transport you immediately.",
                "Rest in a comfortable sitting position; do not exert yourself.",
                "Community health worker (ASHA) has been alerted for field response."
            ],
            booking_allowed=False  # Safety check: routine booking blocked in emergency
        )

    elif level == "HIGH_RISK":
        return CarePathwayPlan(
            triage_level="HIGH_RISK",
            care_pathway="URGENT_CONSULTATION",
            recommendation="Visit a clinic or hospital for urgent medical evaluation today.",
            urgency_description="Significant clinical symptoms that require timely medical assessment within 12-24 hours.",
            action_instructions=[
                "Schedule priority same-day or next-day consultation with a specialist.",
                "Monitor vitals and symptoms closely.",
                "If breathing difficulty or severe pain worsens, proceed immediately to the nearest Emergency Room."
            ],
            booking_allowed=True
        )

    else:  # LOW_RISK
        return CarePathwayPlan(
            triage_level="LOW_RISK",
            care_pathway="ROUTINE_CONSULTATION",
            recommendation="Schedule a routine OPD doctor consultation at your convenience.",
            urgency_description="Mild or stable symptoms manageable with outpatient consultation and guidance.",
            action_instructions=[
                "Book an appointment with a primary care physician or appropriate specialist.",
                "Maintain adequate hydration and rest.",
                "Contact healthcare helpline if new or severe symptoms develop."
            ],
            booking_allowed=True
        )
