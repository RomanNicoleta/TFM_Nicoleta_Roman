This work is focused on developing a a system that evaluates ODRL-based policies using contextual information, such as the time of request, geographical, role and organizational constraints. This authorizer takes as input policies and given the state of the world, the output is a short report stating the evaluation result (permitted or denied), the request, policy and state of the world. 
![sequence](https://github.com/user-attachments/assets/7d2d5503-c0d1-49f7-9306-512cffe01a0a)

The user interaction with the system is illustrated. For instance the user selects a policy and world context through the web interface, which accesses the resources (policy and world files) and loads them in JSON format. Another example can be the process of entering the action and target which is validated through the web interface as well. When clicking "Evaluate Policy" the POST request is sent from the web interface to the HTTP server containing policy, world, action, target and then to the policy evaluator using the evaluate_policy_dict(). Then, the evaluator checks the permission match and gives a JSON response through the HTTP server back to the web interface and ultimately the user is able to see it.


Prerequisites:
1. Install SWI-Prolog.
Download and install from https://www.swi-prolog.org/Download.html.
2. Clone this repository.

How to execute the program:

1. In the desired IDE's terminal use the command: swipl server.pl
2. Open the server at the local host available in the terminal.
