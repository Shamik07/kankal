"""Versioned HTTP request and response contracts."""

from pydantic import BaseModel, ConfigDict, Field


class InputModel(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False)


class ErrorOutput(BaseModel):
    detail: str


class TextInput(InputModel):
    text: str = Field(min_length=1, max_length=2000)


class SearchInput(InputModel):
    query: str = Field(min_length=1, max_length=500)
    limit: int = Field(default=3, ge=1, le=5)


class Passage(BaseModel):
    document_id: str
    text: str
    score: float


class SearchOutput(BaseModel):
    matches: list[Passage]


class TagOutput(BaseModel):
    label: str
    score: float


class LimitedTextInput(TextInput):
    limit: int = Field(default=5, ge=1, le=10)


class Phrase(BaseModel):
    phrase: str
    score: float


class PhraseOutput(BaseModel):
    phrases: list[Phrase]


class TopicOutput(BaseModel):
    group: int
    sample_topic: str


class Duplicate(BaseModel):
    ticket_id: str
    score: float


class DuplicateOutput(BaseModel):
    matches: list[Duplicate]


class RecommendationInput(InputModel):
    item_id: str = Field(min_length=1, max_length=50)
    limit: int = Field(default=3, ge=1, le=5)


class Recommendation(BaseModel):
    item_id: str
    score: float


class RecommendationOutput(BaseModel):
    items: list[Recommendation]


class AnomalyInput(InputModel):
    temperature: float = Field(ge=0, le=150, description="Synthetic Celsius value")
    vibration: float = Field(ge=0, le=200, description="Synthetic vibration unit")


class AnomalyOutput(BaseModel):
    anomaly: bool
    score: float


class RiskInput(InputModel):
    age: float = Field(ge=1, le=12, description="Synthetic machine age in years")
    temperature: float = Field(ge=20, le=85, description="Synthetic Celsius value")


class RiskOutput(BaseModel):
    risk: float
    flagged: bool


class PriceInput(InputModel):
    quantity: float = Field(ge=1, le=4, description="Synthetic item quantity")
    grade: float = Field(ge=1, le=2, description="Synthetic quality grade")


class PriceOutput(BaseModel):
    estimated_value: float


class ForecastInput(InputModel):
    series_id: str = Field(min_length=1, max_length=50)
    horizon: int = Field(default=3, ge=1, le=7)


class ForecastOutput(BaseModel):
    values: list[float]
