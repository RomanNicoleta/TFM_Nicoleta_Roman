from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Any
from report_ex import ODRLEvaluator, policies  # Import the evaluator and policies

app = FastAPI()

class PolicyEvaluationInput(BaseModel):
    policies: List[Any]  # Accepts policies dynamically via the API
    current_time: str
    action: str
    target: str

@app.post("/evaluate-policies/")
def evaluate_policies(input_data: PolicyEvaluationInput):
    try:
        # Create the evaluator and pass the received data
        evaluator = ODRLEvaluator(input_data.policies, input_data.current_time)
        reports = evaluator.evaluate_all_policies(input_data.action, input_data.target)
        
        # Return the evaluation reports as a response
        return {"reports": reports}
    except Exception as e:
        # If something goes wrong, return an error response
        raise HTTPException(status_code=400, detail=str(e))
