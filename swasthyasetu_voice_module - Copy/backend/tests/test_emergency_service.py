"""
Tests for the emergency red-flag safety layer. This is the single most
safety-critical piece of the pipeline, so it gets dedicated, explicit tests
rather than being covered only incidentally through integration tests.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.emergency_service import emergency_safety_service


def test_chest_pain_triggers_emergency():
    result = emergency_safety_service.screen(["Chest Pain"])
    assert result.is_emergency is True
    assert result.red_flag_type == "Severe Chest Pain"


def test_difficulty_breathing_triggers_emergency():
    result = emergency_safety_service.screen(["Difficulty Breathing"])
    assert result.is_emergency is True


def test_loss_of_consciousness_triggers_emergency():
    result = emergency_safety_service.screen(["Loss of Consciousness"])
    assert result.is_emergency is True


def test_combination_flag_fires():
    result = emergency_safety_service.screen(["Chest Pain", "Difficulty Breathing"])
    assert result.is_emergency is True
    assert result.red_flag_type == "Severe Chest Pain with Breathing Difficulty"


def test_mild_symptoms_do_not_trigger_emergency():
    result = emergency_safety_service.screen(["Fever", "Cough"])
    assert result.is_emergency is False
    assert result.red_flag_type is None


def test_empty_symptom_list_is_not_emergency():
    result = emergency_safety_service.screen([])
    assert result.is_emergency is False


def test_unrecognized_symptom_strings_are_ignored_safely():
    result = emergency_safety_service.screen(["Some Unmapped Symptom"])
    assert result.is_emergency is False
