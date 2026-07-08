% Integration / regression tests for the ODRL evaluator.
%
% Each test loads a predefined policy file and its matching world file from
% disk, runs the full evaluate_policy/5 pipeline (JSON parsing + structural
% matching + constraint satisfaction), and asserts the expected outcome.
%
% The expected results correspond one-to-one with the functional validation
% table in the thesis (Table 4.1). Running this suite therefore doubles as a
% regression guard: any change that alters a documented outcome fails here.
%
% Run with:  swipl -q -g "consult('test/integration_tests.plt'), run_tests, halt" from the prolog/ directory.

:- use_module(library(plunit)).

:- dynamic base_dir/1.

% Resolve the prolog/ directory from this test file's location and load the
% evaluator, so the suite is runnable from any working directory.
:- prolog_load_context(directory, TestDir),
   file_directory_name(TestDir, PrologDir),
   retractall(base_dir(_)),
   assertz(base_dir(PrologDir)),
   atom_concat(PrologDir, '/evaluator.pl', EvalFile),
   consult(EvalFile).

policy_file(CaseNumber, Path) :-
    base_dir(Base),
    format(atom(Path), '~w/policies/policy_case_~w.json', [Base, CaseNumber]).

world_file(CaseNumber, Path) :-
    base_dir(Base),
    format(atom(Path), '~w/world/world_case_~w.json', [Base, CaseNumber]).

% Expected outcome for each predefined case (mirrors thesis Table 4.1).
expected(1,  permitted).   % Temporal: access within valid date range
expected(2,  denied).      % Temporal: access after expiration date
expected(3,  denied).      % Temporal: access before activation date
expected(4,  permitted).   % Role: cybersecurity expert accessing report
expected(5,  denied).      % Role: junior analyst modifying financial data
expected(6,  permitted).   % Role: HR manager accessing HR records
expected(7,  permitted).   % Geographic: access from an allowed country
expected(8,  permitted).   % Geographic + organizational: TechInnovate in DE
expected(9,  denied).      % Geographic + organizational: requirements unmet
expected(10, permitted).   % Research ethics + approved processing method

evaluate_case(CaseNumber, Result) :-
    policy_file(CaseNumber, PolicyFile),
    world_file(CaseNumber, WorldFile),
    get_test_case_info(CaseNumber, Action, Target),
    evaluate_policy(PolicyFile, WorldFile, Action, Target, Result).

:- begin_tests(predefined_cases).

test(all_cases_match_expected, [forall(expected(Case, Expected))]) :-
    evaluate_case(Case, Result),
    assertion(Result == Expected).

:- end_tests(predefined_cases).

% A couple of explicit end-to-end checks with custom (in-memory) inputs,
% documenting how changing a single world attribute flips the decision.
:- begin_tests(custom_inputs).

test(research_case_flips_to_denied_on_bad_method) :-
    policy_file(10, PolicyFile),
    parse_json_ld(PolicyFile, Policy),
    World = _{world: _{currentResearchContext:
                       _{researchEthicsApproval: true,
                         dataProcessingMethod: "deep-learning"}}},
    ( has_permission(Policy, "use", "http://example.com/scientific-data/7890", World)
    ->  Result = permitted
    ;   Result = denied
    ),
    assertion(Result == denied).

test(mismatched_target_is_denied) :-
    policy_file(1, PolicyFile),
    parse_json_ld(PolicyFile, Policy),
    World = _{world: _{currentTime: _{dateTime: "2025-03-25T10:30:00Z"}}},
    \+ has_permission(Policy, "access", "http://example.com/does-not-exist", World).

:- end_tests(custom_inputs).