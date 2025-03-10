from datetime import datetime
import json

class ODRLEvaluator:
    def __init__(self, policies, current_time):
        self.policies = policies
        try:
            self.current_time = datetime.strptime(current_time, "%Y-%m-%dT%H:%M:%S.%fZ")
        except ValueError:
            # Handle ISO format without milliseconds
            self.current_time = datetime.strptime(current_time, "%Y-%m-%dT%H:%M:%SZ")
    
    def evaluate_activation_state(self, permission):
        """Evaluate if a permission is active based on time constraints"""
        # Check for constraints directly in permission
        for constraint in permission.get("constraint", []):
            if isinstance(constraint, dict) and constraint.get("leftOperand") == "dateTime" and constraint.get("operator") == "lt":
                constraint_time = datetime.strptime(constraint["rightOperand"]["@value"], "%Y-%m-%d")
                if self.current_time < constraint_time:
                    return "Active"
                else:
                    return "Inactive"
        
        # Check for constraints in action refinements
        action = permission.get("action", "")
        if isinstance(action, list):
            for act in action:
                if isinstance(act, dict) and "refinement" in act:
                    refinements = act["refinement"]
                    if isinstance(refinements, list):
                        for refinement in refinements:
                            if refinement.get("leftOperand") == "dateTime" and refinement.get("operator") == "lt":
                                constraint_time = datetime.strptime(refinement["rightOperand"]["@value"], "%Y-%m-%d")
                                if self.current_time < constraint_time:
                                    return "Active"
                                else:
                                    return "Inactive"
        
        # Default to active if no time constraints found
        return "Active"
    
    def get_action_value(self, action_field):
        """Extract the action value from different action formats"""
        if isinstance(action_field, str):
            return action_field
        elif isinstance(action_field, list):
            for act in action_field:
                if isinstance(act, dict) and "rdf:value" in act:
                    value = act["rdf:value"]
                    if isinstance(value, dict) and "@id" in value:
                        # Handle format like: "rdf:value": { "@id": "odrl:print" }
                        return value["@id"].replace("odrl:", "")
        return None
    
    def matches_action_and_target(self, permission, requested_action, requested_target):
        """Check if permission matches the requested action and target"""
        # Extract action value
        permission_action = self.get_action_value(permission.get("action", ""))
        
        # Extract target
        permission_target = permission.get("target", "")
        
        # Simple action and target matching
        action_match = (permission_action == requested_action or 
                       f"odrl:{requested_action}" == permission_action)
        
        target_match = (permission_target == requested_target)
        
        return action_match and target_match
    
    def evaluate_access(self, policy, action, target):
        """Evaluate if a policy permits access for the requested action and target"""
        reports = []
        
        # Handle permissions
        for permission in policy.get("permission", []):
            activation_state = self.evaluate_activation_state(permission)
            
            if activation_state == "Active" and self.matches_action_and_target(permission, action, target):
                reports.append({
                    "@context": {
                        "report": "https://w3c/report",
                        "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                    },
                    "report": "Yes, you can because the permission is active and the requested action is allowed.",
                    "permission": permission,
                    "activation_state": activation_state,
                    "access_control": "Permit",
                    "rdfs:comment": "The requested action was permitted based on the current time and constraints.",
                    "policy_uid": policy.get("uid", "unknown")
                })
            else:
                reports.append({
                    "@context": {
                        "report": "https://w3c/report",
                        "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                    },
                    "report": "No, you cannot because the permission is inactive or the requested action is not allowed.",
                    "permission": permission,
                    "activation_state": activation_state,
                    "access_control": "Deny",
                    "rdfs:comment": "The requested action was denied because the permission is not active or does not match the requested action/target.",
                    "policy_uid": policy.get("uid", "unknown")
                })
        
        return reports
    
    def evaluate_all_policies(self, action, target):
        """Evaluate all policies for the given action and target"""
        all_reports = []
        
        # Filter out constraint objects (only process policy objects)
        policy_objects = [p for p in self.policies if p.get("@type") in ["Set", "Offer", "Agreement"]]
        
        for policy in policy_objects:
            policy_reports = self.evaluate_access(policy, action, target)
            all_reports.extend(policy_reports)
        
        return all_reports

# If run standalone, provide example evaluation
if __name__ == "__main__":
    # Example policy for testing
    test_policy = {
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Set",
        "uid": "http://example.com/policy/test",
        "permission": [{
            "target": "http://example.com/document/1234",
            "action": "distribute",
            "constraint": [{
                "leftOperand": "dateTime",
                "operator": "lt",
                "rightOperand": { "@value": "2099-01-01", "@type": "xsd:date" }
            }]
        }]
    }
    
    evaluator = ODRLEvaluator([test_policy], "2023-01-01T00:00:00.000Z")
    reports = evaluator.evaluate_all_policies("distribute", "http://example.com/document/1234")
    
    for report in reports:
        print(json.dumps(report, indent=2))