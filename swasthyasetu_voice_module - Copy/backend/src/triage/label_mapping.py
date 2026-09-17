"""Triage Label Mapping Specification.
Maps dataset acuity levels (e.g. Emergency Severity Index 1-5 or clinical risk tiers)
to project standard triage tiers: EMERGENCY, URGENT, ROUTINE.
Preserves original_acuity alongside project_triage_level.
"""

from typing import Dict, Any

# Standard Emergency Severity Index (ESI) clinically recognized mapping:
# ESI 1: Immediate resuscitation required -> EMERGENCY
# ESI 2: High risk / confusional state / severe pain / vital sign instability -> EMERGENCY or HIGH_RISK
# ESI 3: Urgent / multiple resources needed -> HIGH_RISK
# ESI 4: Semi-urgent / one resource needed -> LOW_RISK
# ESI 5: Non-urgent / no resources needed -> LOW_RISK
ESI_TO_PROJECT_TRIAGE: Dict[str, str] = {
    "1": "EMERGENCY",
    "1.0": "EMERGENCY",
    "2": "URGENT",
    "2.0": "URGENT",
    "3": "URGENT",
    "3.0": "URGENT",
    "4": "ROUTINE",
    "4.0": "ROUTINE",
    "5": "ROUTINE",
    "5.0": "ROUTINE",
    # String labels
    "emergency": "EMERGENCY",
    "immediate": "EMERGENCY",
    "critical": "EMERGENCY",
    "urgent": "URGENT",
    "high": "URGENT",
    "high_risk": "URGENT",
    "semi-urgent": "ROUTINE",
    "routine": "ROUTINE",
    "low": "ROUTINE",
    "low_risk": "ROUTINE",
    "non-urgent": "ROUTINE"
}

LABEL_MAPPING_VERSION = "1.0.0"
CLINICAL_VALIDATION_STATUS = "Rule-aligned clinical consensus mapping (Requires institutional IRB/CMO sign-off prior to unmonitored triage deployment)."

def map_acuity_to_project_triage(raw_acuity: Any) -> str:
    """Safely maps raw acuity target into EMERGENCY, HIGH_RISK, or LOW_RISK.
    Defaults to HIGH_RISK for uncertain/unmapped values to avoid hazardous under-triage.
    """
    if raw_acuity is None:
        return "URGENT"
    key = str(raw_acuity).strip().lower()
    return ESI_TO_PROJECT_TRIAGE.get(key, "HIGH_RISK")
