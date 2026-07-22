from datetime import date
from enum import Enum
from typing import Self

from pydantic import BaseModel, ConfigDict, model_validator


class ExportFormat(str, Enum):
    PDF = "pdf"
    CSV = "csv"


class DataExportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    format: ExportFormat
    include_protocols: bool = True
    include_checkins: bool = True
    include_insights: bool = True
    start_date: date | None = None
    end_date: date | None = None

    @model_validator(mode="after")
    def valid_range(self) -> Self:
        if self.start_date and self.end_date and self.start_date > self.end_date:
            raise ValueError("start_date must not be after end_date")
        if self.start_date and self.start_date > date.today():
            raise ValueError("start_date must not be in the future")
        if self.end_date and self.end_date > date.today():
            raise ValueError("end_date must not be in the future")
        return self
