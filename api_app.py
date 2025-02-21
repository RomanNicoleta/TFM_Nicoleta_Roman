from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any
from report_ex import ODRLEvaluator, policies  # import the evaluator and policies from report_ex.py

app = FastAPI()

# tried&failed: changed the PolicyEvaluationInput model to accept raw JSON-LD
class PolicyEvaluationInput(BaseModel):
    policies: List[Dict[str, Any]]  
    current_time: str
    action: str
    target: str

@app.post("/evaluate-policies/")
def evaluate_policies(input_data: PolicyEvaluationInput):
    try:
        evaluator = ODRLEvaluator(input_data.policies, input_data.current_time)
        reports = evaluator.evaluate_all_policies(input_data.action, input_data.target)
        return {"reports": reports}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
