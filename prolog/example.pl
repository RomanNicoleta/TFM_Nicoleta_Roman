% enhanced_example.pl
% Example usage of the enhanced policy evaluator

% Load the enhanced evaluator
:- consult('enhanced_evaluator.pl').

% Example queries for different test cases

% Test Case 1: Document access with time constraints (should be permitted)
test_case_1 :-
    evaluate_policy('policy_case_1.json', 'world_case_1.json', 
                   "access", "http://example.com/document/5678", Result),
    format('Test Case 1 (Document Access): ~w~n', [Result]).

% Test Case 2: Data use before deadline (should be denied - past deadline)
test_case_2 :-
    evaluate_policy('policy_case_2.json', 'world_case_2.json', 
                   "use", "http://example.com/data/9012", Result),
    format('Test Case 2 (Data Use Before Date): ~w~n', [Result]).

% Test Case 4: Role-based access for cybersecurity expert (should be permitted)
test_case_4 :-
    evaluate_policy('policy_case_4.json', 'world_case_4.json', 
                   "access", "http://example.com/confidential-report/7890", Result),
    format('Test Case 4 (Role-based Access): ~w~n', [Result]).

% Test Case 5: Role-based modification for junior analyst (should be denied)
test_case_5 :-
    evaluate_policy('policy_case_5.json', 'world_case_5.json', 
                   "modify", "http://example.com/financial-data/2345", Result),
    format('Test Case 5 (Role-based Modification): ~w~n', [Result]).

% Test Case 7: Geographic access from US (should be permitted)
test_case_7 :-
    evaluate_policy('policy_case_7.json', 'world_case_7.json', 
                   "access", "http://example.com/research-data/1234", Result),
    format('Test Case 7 (Geographic Access): ~w~n', [Result]).

% Test Case 8: Dual constraints - organization and country (should be permitted)
test_case_8 :-
    evaluate_policy('policy_case_8.json', 'world_case_8.json', 
                   "view", "http://example.com/strategic-documents/5678", Result),
    format('Test Case 8 (Dual Constraints): ~w~n', [Result]).

% Test Case 10: Research ethics and data processing (should be permitted)
test_case_10 :-
    evaluate_policy('policy_case_10.json', 'world_case_10.json', 
                   "use", "http://example.com/scientific-data/7890", Result),
    format('Test Case 10 (Research Ethics): ~w~n', [Result]).

% Run individual test cases
run_selected_tests :-
    test_case_1,
    test_case_2,
    test_case_4,
    test_case_5,
    test_case_7,
    test_case_8,
    test_case_10.

% Interactive testing predicate
test_interactive(CaseNumber) :-
    format('Testing Case ~w...~n', [CaseNumber]),
    test_policy_case(CaseNumber, Result),
    (   Result = permitted ->
        format('✓ Access PERMITTED~n')
    ;   format('✗ Access DENIED~n')
    ).

% Helper predicate to test with custom parameters
test_custom_policy(PolicyFile, WorldFile, Action, Target) :-
    evaluate_policy(PolicyFile, WorldFile, Action, Target, Result),
    format('Policy: ~w~n', [PolicyFile]),
    format('World: ~w~n', [WorldFile]),
    format('Action: ~w on Target: ~w~n', [Action, Target]),
    format('Result: ~w~n~n', [Result]).

% Demonstration of all constraint types
demo_all_constraints :-
    format('=== Policy Evaluation Demo ===~n~n'),
    
    format('1. Time-based Constraints:~n'),
    test_interactive(1),
    test_interactive(2),
    test_interactive(3),
    nl,
    
    format('2. Role-based Constraints:~n'),
    test_interactive(4),
    test_interactive(5),
    test_interactive(6),
    nl,
    
    format('3. Geographic Constraints:~n'),
    test_interactive(7),
    test_interactive(8),
    test_interactive(9),
    nl,
    
    format('4. Research Ethics Constraints:~n'),
    test_interactive(10),
    nl,
    
    format('=== Demo Complete ===~n').

% Query examples:
% ?- test_case_1.
% ?- run_all_tests.
% ?- demo_all_constraints.
% ?- test_interactive(5).