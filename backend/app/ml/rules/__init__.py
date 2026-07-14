from app.ml.rules.adherence_consistency import adherence_consistency_rule
from app.ml.rules.symptom_after_dose import symptom_after_dose_rule
from app.ml.rules.weight_plateau import weight_plateau_rule
from app.ml.rules.weight_trend import weight_trend_rule

DEFAULT_RULES = [
    weight_trend_rule,
    weight_plateau_rule,
    symptom_after_dose_rule,
    adherence_consistency_rule,
]
