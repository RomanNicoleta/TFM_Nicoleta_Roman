% Unit tests for the ODRL evaluator core predicates (evaluator.pl).
%
% These tests exercise individual predicates in isolation:
%   - value normalization
%   - datetime parsing and comparison
%   - role / country / method membership
%   - each supported constraint type
%   - world-state accessors (nested and flat forms)
%
% Run with:  swipl -q -g "consult('test/unit_tests.plt'), run_tests, halt" from the prolog/ directory.

:- use_module(library(plunit)).

% Load the predicate under test using a path relative to this test file,
% so the suite can be run from any working directory.
:- prolog_load_context(directory, TestDir),
   file_directory_name(TestDir, PrologDir),
   atom_concat(PrologDir, '/evaluator.pl', EvalFile),
   consult(EvalFile).

% ---------------------------------------------------------------------------
:- begin_tests(normalization).

test(string_to_atom) :-
    normalize_value("access", V),
    assertion(V == access).

test(atom_stays_atom) :-
    normalize_value(access, V),
    assertion(V == access).

test(jsonld_value_object) :-
    normalize_value(_{'@value': "machine-learning"}, V),
    assertion(V == 'machine-learning').

test(plain_value_object) :-
    normalize_value(_{value: "researcher"}, V),
    assertion(V == researcher).

:- end_tests(normalization).

% ---------------------------------------------------------------------------
:- begin_tests(datetime_parsing).

test(parse_full_iso8601) :-
    parse_datetime("2025-03-25T10:30:00Z", D),
    assertion(D == date(2025, 3, 25)).

test(parse_plain_date) :-
    parse_datetime("2026-01-01", D),
    assertion(D == date(2026, 1, 1)).

test(atom_date_splits_components) :-
    atom_date('2025-12-31', D),
    assertion(D == date(2025, 12, 31)).

test(compare_less_than) :-
    compare_datetimes("2025-03-25T10:30:00Z", "2025-12-31T23:59:59Z", O),
    assertion(O == (<)).

test(compare_greater_than) :-
    compare_datetimes("2025-03-25T10:30:00Z", "2025-01-01T00:00:00Z", O),
    assertion(O == (>)).

% Documents (and locks in) the current date-granularity behaviour:
% two instants on the same calendar day compare as equal.
test(compare_same_day_is_equal) :-
    compare_datetimes("2025-03-25T01:00:00Z", "2025-03-25T23:00:00Z", O),
    assertion(O == (=)).

test(extract_value_from_object) :-
    extract_datetime_value(_{'@value': "2025-01-01T00:00:00Z", '@type': "xsd:dateTime"}, DT),
    assertion(DT == "2025-01-01T00:00:00Z").

test(extract_value_from_plain_string) :-
    extract_datetime_value("2025-01-01", DT),
    assertion(DT == "2025-01-01").

:- end_tests(datetime_parsing).

% ---------------------------------------------------------------------------
:- begin_tests(membership).

test(role_single_match) :-
    check_role_membership("cybersecurity-expert", "cybersecurity-expert").

test(role_list_match) :-
    check_role_membership("hr-manager", ["hr-manager", "legal-counsel"]).

test(role_no_match, [fail]) :-
    check_role_membership("intern", ["hr-manager", "legal-counsel"]).

test(country_list_match) :-
    check_country_membership("https://schema.org/Country/US",
                             ["https://schema.org/Country/US",
                              "https://schema.org/Country/CA"]).

test(country_no_match, [fail]) :-
    check_country_membership("https://schema.org/Country/KR",
                             ["https://schema.org/Country/JP"]).

test(method_list_match) :-
    check_method_membership("machine-learning",
                            ["statistical-analysis", "machine-learning", "predictive-modeling"]).

test(method_no_match, [fail]) :-
    check_method_membership("deep-learning",
                            ["statistical-analysis", "machine-learning"]).

:- end_tests(membership).

% ---------------------------------------------------------------------------
:- begin_tests(constraint_types).

test(datetime_lt_satisfied) :-
    World = _{world: _{currentTime: _{dateTime: "2025-03-25T00:00:00Z"}}},
    check_constraint_type("dateTime", "lt", _{'@value': "2025-04-01T00:00:00Z"}, World).

test(datetime_gt_not_satisfied, [fail]) :-
    World = _{world: _{currentTime: _{dateTime: "2025-03-25T00:00:00Z"}}},
    check_constraint_type("dateTime", "gt", _{'@value': "2026-01-01T00:00:00Z"}, World).

test(role_ispartof_satisfied) :-
    World = _{world: _{currentUserRole: "cybersecurity-expert"}},
    check_constraint_type("role", "isPartOf", "cybersecurity-expert", World).

test(country_in_satisfied) :-
    World = _{world: _{currentUserLocation: _{country: "https://schema.org/Country/US"}}},
    check_constraint_type("country", "in",
                          ["https://schema.org/Country/US"], World).

test(country_notin_satisfied) :-
    World = _{world: _{currentUserLocation: _{country: "https://schema.org/Country/DE"}}},
    check_constraint_type("country", "notIn",
                          ["https://schema.org/Country/CN",
                           "https://schema.org/Country/RU"], World).

test(organization_eq_satisfied) :-
    World = _{world: _{currentUserOrganization: "http://example.com/company/TechInnovate"}},
    check_constraint_type("organization", "eq",
                          "http://example.com/company/TechInnovate", World).

test(organization_noteq_satisfied) :-
    World = _{world: _{currentUserOrganization: "http://example.com/company/TechNewYork"}},
    check_constraint_type("organization", "notEq",
                          "http://example.com/company/OtherCorp", World).

test(research_ethics_eq_satisfied) :-
    World = _{world: _{currentResearchContext: _{researchEthicsApproval: true}}},
    check_constraint_type("researchEthicsApproval", "eq", true, World).

test(data_processing_in_satisfied) :-
    World = _{world: _{currentResearchContext: _{dataProcessingMethod: "machine-learning"}}},
    check_constraint_type("dataProcessingMethod", "in",
                          ["statistical-analysis", "machine-learning"], World).

:- end_tests(constraint_types).

% ---------------------------------------------------------------------------
:- begin_tests(world_accessors).

test(datetime_nested_world) :-
    World = _{world: _{currentTime: _{dateTime: "2025-03-25T10:30:00Z"}}},
    get_current_datetime(World, DT),
    assertion(DT == "2025-03-25T10:30:00Z").

test(role_flat_world) :-
    World = _{currentUserRole: "researcher"},
    get_current_user_role(World, R),
    assertion(R == "researcher").

test(country_nested_world) :-
    World = _{world: _{currentUserLocation: _{country: "https://schema.org/Country/JP"}}},
    get_current_user_country(World, C),
    assertion(C == "https://schema.org/Country/JP").

test(organization_flat_world) :-
    World = _{currentUserOrganization: "http://example.com/company/TechInnovate"},
    get_current_user_organization(World, O),
    assertion(O == "http://example.com/company/TechInnovate").

:- end_tests(world_accessors).