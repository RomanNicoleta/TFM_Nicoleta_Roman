from datetime import datetime

class ODRLEvaluator:
    def __init__(self, policy, current_time):
        self.policy = policy
        self.current_time = datetime.strptime(current_time, "%Y-%m-%dT%H:%M:%S.%fZ")
    
    def evaluate_activation_state(self, permission):
        for constraint in permission.get("constraint", []):
            if constraint["leftOperand"] == "dateTime" and constraint["operator"] == "lt":
                constraint_time = datetime.strptime(constraint["rightOperand"]["@value"], "%Y-%m-%d")
                if self.current_time < constraint_time:
                    return "Active"
        return "Inactive"
    
    def evaluate_access(self, action, target):
        for permission in self.policy["permission"]:
            activation_state = self.evaluate_activation_state(permission)
            if activation_state == "Active" and permission["action"] == action and permission["target"] == target:
                return {
                    "@context": {
                        "report": "https://w3c/report",
                        "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
                    },
                    "report": "Yes, you can because the permission is active and the requested action is allowed.",
                    "permission": permission,
                    "activation_state": activation_state,
                    "access_control": "Permit",
                    "rdfs:comment": "The requested action was permitted based on the current time and constraints."
                }
        return {
            "@context": {
                "report": "https://w3c/report",
                "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
            },
            "report": "No, you cannot because the permission is inactive or the requested action is not allowed.",
            "permission": None,
            "activation_state": "Inactive",
            "access_control": "Deny",
            "rdfs:comment": "The requested action was denied because the permission is not active or does not match the requested action/target."
        }

# example policy and context from https://w3c.github.io/odrl/formal-semantics/ EX13-1
policy = {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "Set",
    "uid": "http://example.com/policy/13",
    "permission": [{
        "uid": "http://example.com/policy/13/permission/1",
        "target": "http://example.com/document/1234",
        "assigner": "http://example.com/party/16",
        "action": "distribute",
        "constraint": [{
            "@id": "http://example.com/constraint/1",
            "leftOperand": "dateTime",
            "operator": "lt",
            "rightOperand": { "@value": "2018-01-01", "@type": "xsd:date" }
        }]
    }]
}

current_time = "2017-12-31T23:59:59.999Z"
action = "distribute"
target = "http://example.com/document/1234"

# evaluation stage
evaluator = ODRLEvaluator(policy, current_time)
result = evaluator.evaluate_access(action, target)

# result
import json
print(json.dumps(result, indent=2))

