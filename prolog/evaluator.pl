:- use_module(library(http/json)).

% Parse JSON-LD file
parse_json_ld(File, Data) :-
    open(File, read, Stream),
    json_read_dict(Stream, Data),
    close(Stream).

% Main evaluation predicate
evaluate_policy(PolicyFile, WorldFile, Action, Target, Result) :-
    parse_json_ld(PolicyFile, Policy),
    parse_json_ld(WorldFile, World),
    (   has_permission(Policy, Action, Target, World) ->
        Result = permitted
    ;   Result = denied
    ).

% Check if the policy allows an action on a target within constraints
has_permission(Policy, Action, Target, World) :-
    member(Permission, Policy.permission),
    Permission.action = Action,
    Permission.target = Target,
    check_all_constraints(Permission.constraint, World).

% Validate all constraints (all must be satisfied)
check_all_constraints(Constraints, World) :-
    forall(member(Constraint, Constraints),
           check_constraint(Constraint, World)).

% Check individual constraint types
check_constraint(Constraint, World) :-
    LeftOperand = Constraint.leftOperand,
    Operator = Constraint.operator,
    RightOperand = Constraint.rightOperand,
    check_constraint_type(LeftOperand, Operator, RightOperand, World).

% DateTime constraints
check_constraint_type("dateTime", "lt", RightOperand, World) :-
    get_current_datetime(World, CurrentTime),
    extract_datetime_value(RightOperand, RightDate),
    compare_datetimes(CurrentTime, RightDate, <).

check_constraint_type("dateTime", "lteq", RightOperand, World) :-
    get_current_datetime(World, CurrentTime),
    extract_datetime_value(RightOperand, RightDate),
    (compare_datetimes(CurrentTime, RightDate, <) ; 
     compare_datetimes(CurrentTime, RightDate, =)).

check_constraint_type("dateTime", "gt", RightOperand, World) :-
    get_current_datetime(World, CurrentTime),
    extract_datetime_value(RightOperand, RightDate),
    compare_datetimes(CurrentTime, RightDate, >).

check_constraint_type("dateTime", "gteq", RightOperand, World) :-
    get_current_datetime(World, CurrentTime),
    extract_datetime_value(RightOperand, RightDate),
    (compare_datetimes(CurrentTime, RightDate, >) ; 
     compare_datetimes(CurrentTime, RightDate, =)).

% Role constraints
check_constraint_type("role", "isPartOf", RightOperand, World) :-
    get_current_user_role(World, CurrentRole),
    (   is_list(RightOperand) ->
        member(CurrentRole, RightOperand)
    ;   RightOperand = CurrentRole
    ).

% Country constraints
check_constraint_type("country", "in", RightOperand, World) :-
    get_current_user_country(World, CurrentCountry),
    (   is_list(RightOperand) ->
        member(CurrentCountry, RightOperand)
    ;   RightOperand = CurrentCountry
    ).

check_constraint_type("country", "notIn", RightOperand, World) :-
    get_current_user_country(World, CurrentCountry),
    (   is_list(RightOperand) ->
        \+ member(CurrentCountry, RightOperand)
    ;   RightOperand \= CurrentCountry
    ).

% Organization constraints
check_constraint_type("organization", "eq", RightOperand, World) :-
    get_current_user_organization(World, CurrentOrg),
    CurrentOrg = RightOperand.

check_constraint_type("organization", "notEq", RightOperand, World) :-
    get_current_user_organization(World, CurrentOrg),
    CurrentOrg \= RightOperand.

% Research ethics approval constraints
check_constraint_type("researchEthicsApproval", "eq", RightOperand, World) :-
    get_research_ethics_approval(World, CurrentApproval),
    CurrentApproval = RightOperand.

% Data processing method constraints
check_constraint_type("dataProcessingMethod", "in", RightOperand, World) :-
    get_data_processing_method(World, CurrentMethod),
    (   is_list(RightOperand) ->
        member(CurrentMethod, RightOperand)
    ;   RightOperand = CurrentMethod
    ).

% Helper predicates to extract world state information
get_current_datetime(World, DateTime) :-
    (   get_dict(currentTime, World.world, TimeDict),
        get_dict(dateTime, TimeDict, DateTime)
    ;   get_dict(dateTime, World.world.currentTime, DateTime)
    ).

get_current_user_role(World, Role) :-
    get_dict(currentUserRole, World.world, Role).

get_current_user_country(World, Country) :-
    get_dict(currentUserLocation, World.world, LocationDict),
    get_dict(country, LocationDict, Country).

get_current_user_organization(World, Org) :-
    get_dict(currentUserOrganization, World.world, Org).

get_research_ethics_approval(World, Approval) :-
    get_dict(currentResearchContext, World.world, ResearchDict),
    get_dict(researchEthicsApproval, ResearchDict, Approval).

get_data_processing_method(World, Method) :-
    get_dict(currentResearchContext, World.world, ResearchDict),
    get_dict(dataProcessingMethod, ResearchDict, Method).

% Extract datetime value from different formats
extract_datetime_value(Dict, DateTime) :-
    (   get_dict('@value', Dict, DateTime) ->
        true
    ;   DateTime = Dict
    ).

% Compare two datetime strings
compare_datetimes(DateTime1, DateTime2, Comparison) :-
    parse_datetime(DateTime1, Date1),
    parse_datetime(DateTime2, Date2),
    compare(Comparison, Date1, Date2).

% Parse datetime string to comparable format
parse_datetime(DateTimeStr, ParsedDate) :-
    % Handle both date formats: YYYY-MM-DD and YYYY-MM-DDTHH:MM:SSZ
    (   atom_string(DateTimeStr, DateStr) ->
        true
    ;   DateStr = DateTimeStr
    ),
    % Extract just the date part if it's a full datetime
    (   sub_string(DateStr, 0, 10, _, DatePart) ->
        atom_string(DateAtom, DatePart)
    ;   DateAtom = DateStr
    ),
    atom_date(DateAtom, ParsedDate).

% Convert a date string to a comparable term
atom_date(DateStr, date(Year, Month, Day)) :-
    atomic_list_concat([YearAtom, MonthAtom, DayAtom], '-', DateStr),
    atom_number(YearAtom, Year),
    atom_number(MonthAtom, Month),
    atom_number(DayAtom, Day).

% Test predicate to evaluate a specific policy case
test_policy_case(CaseNumber, Result) :-
    format(string(PolicyFile), 'policy_case_~w.json', [CaseNumber]),
    format(string(WorldFile), 'world_case_~w.json', [CaseNumber]),
    get_test_case_info(CaseNumber, Action, Target),
    evaluate_policy(PolicyFile, WorldFile, Action, Target, Result),
    format('Case ~w: ~w~n', [CaseNumber, Result]).

% Test case information (action and target for each case)
get_test_case_info(1, "access", "http://example.com/document/5678").
get_test_case_info(2, "use", "http://example.com/data/9012").
get_test_case_info(3, "distribute", "http://example.com/resource/3456").
get_test_case_info(4, "access", "http://example.com/confidential-report/7890").
get_test_case_info(5, "modify", "http://example.com/financial-data/2345").
get_test_case_info(6, "view", "http://example.com/hr-records/6789").
get_test_case_info(7, "access", "http://example.com/research-data/1234").
get_test_case_info(8, "view", "http://example.com/strategic-documents/5678").
get_test_case_info(9, "access", "http://example.com/sensitive-data/9012").
get_test_case_info(10, "use", "http://example.com/scientific-data/7890").

% to run all test cases 
run_all_tests :-
    forall(between(1, 10, CaseNumber),
           test_policy_case(CaseNumber, _)).