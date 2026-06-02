from app.ml.rules.weight_trend import weight_trend_rule
from app.ml.rules.weight_plateau import weight_plateau_rule

DEFAULT_RULES = [
    weight_trend_rule,
    weight_plateau_rule,
]
