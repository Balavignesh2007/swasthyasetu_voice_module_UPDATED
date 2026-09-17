"""SwasthyaSetu Clinical API Routers."""

from src.api.healthcare_routes import router as healthcare_router
from src.api.appointment_routes import router as appointment_router

__all__ = ["healthcare_router", "appointment_router"]
