# Metric math for Software POE. Explainable by construction: every result
# carries the comparator, expected/actual values and a human-readable summary.
# Mirrors app/uncertainty.py policy constants — keep in sync.

module Metrics

export GapResult, evaluate, uncertainty_score, is_stale

const STALE_AFTER_DAYS = 30
const BASE_UNCERTAINTY = 0.1
const MISSING_EXPECTATION_PENALTY = 0.9
const STALE_PENALTY = 0.3

struct GapResult
    gap_detected::Bool
    gap_value::Union{Float64,Nothing}
    summary::String
end

"""Compare actual vs expected under the expectation's comparator."""
function evaluate(metric::AbstractString, actual::Float64,
                  expected::Union{Float64,Nothing}, comparator::AbstractString)
    if expected === nothing
        return GapResult(false, nothing,
            "No expectation registered for metric '$metric'; cannot assess. Human review required.")
    end
    satisfied = comparator == ">=" ? actual >= expected :
                comparator == "<=" ? actual <= expected :
                comparator == "==" ? actual == expected :
                error("unknown comparator: $comparator")
    gap = actual - expected
    if satisfied
        return GapResult(false, gap,
            "Metric '$metric' within expectation: actual $(actual) $(comparator) expected $(expected).")
    end
    return GapResult(true, gap,
        "Gap detected on '$metric': actual $(actual) violates '$(comparator) $(expected)' (gap $(round(gap; digits=6))).")
end

is_stale(observed_at::Real, now::Real) = (now - observed_at) > STALE_AFTER_DAYS * 86400

function uncertainty_score(; has_expectation::Bool, stale::Bool)
    score = BASE_UNCERTAINTY
    has_expectation || (score += MISSING_EXPECTATION_PENALTY)
    stale && (score += STALE_PENALTY)
    return min(score, 1.0)
end

end # module
