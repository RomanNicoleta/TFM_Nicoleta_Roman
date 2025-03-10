from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from typing import List, Dict, Any
from report_ex import ODRLEvaluator  # Import only the evaluator

app = FastAPI(title="ODRL Policy Evaluator API")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PolicyEvaluationInput(BaseModel):
    policies: List[Dict[str, Any]]
    current_time: str
    action: str
    target: str

@app.post("/evaluate-policies/")
async def evaluate_policies(input_data: PolicyEvaluationInput):
    try:
        # Create evaluator with provided policies and time
        evaluator = ODRLEvaluator(input_data.policies, input_data.current_time)
        
        # Evaluate all policies with the requested action and target
        reports = evaluator.evaluate_all_policies(input_data.action, input_data.target)
        
        return {"reports": reports, "status": "success"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# Add health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy"}