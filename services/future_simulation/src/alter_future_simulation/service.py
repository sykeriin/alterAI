from __future__ import annotations

from .config import Settings, get_settings
from .engine import FutureSimulationEngine
from .schemas import FutureSimulationRequest, FutureSimulationResponse


class FutureSimulationService:
    def __init__(self, *, settings: Settings, engine: FutureSimulationEngine) -> None:
        self._settings = settings
        self._engine = engine

    def simulate(self, request: FutureSimulationRequest) -> FutureSimulationResponse:
        horizon_months = min(
            request.horizon_months or self._settings.default_horizon_months,
            self._settings.max_horizon_months,
        )
        currency = request.currency or self._settings.default_currency
        return self._engine.simulate(
            request,
            horizon_months=horizon_months,
            currency=currency,
        )


def create_future_simulation_service(
    *,
    settings: Settings | None = None,
    engine: FutureSimulationEngine | None = None,
) -> FutureSimulationService:
    return FutureSimulationService(
        settings=settings or get_settings(),
        engine=engine or FutureSimulationEngine(),
    )

