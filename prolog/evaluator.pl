% Fixed evaluator.pl
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
    get_dict(permission, Policy, Permissions),
    member(Permission, Permissions),
    get_dict(action, Permission, PolicyAction),
    get_dict(target, Permission, PolicyTarget),
    % Convert to atoms for comparison
    atom_string(ActionAtom, Action),
    atom_string(TargetAtom, Target),
    atom_string(PolicyActionAtom, PolicyAction),
    atom_string(PolicyTargetAtom, PolicyTarget),
    ActionAtom = PolicyActionAtom,
    TargetAtom = PolicyTargetAtom,
    % Check constraints if they exist
    (   get_dict(constraint, Permission, Constraints) ->
        check_all_constraints(Constraints, World)
    ;   true  % No constraints means always allowed
    ).

% Validate all constraints (all must be satisfied)
check_all_constraints(Constraints, World) :-
    forall(member(Constraint, Constraints),
           check_constraint(Constraint, World)).

% Check individual constraint types
check_constraint(Constraint, World) :-
    get_dict(leftOperand, Constraint, LeftOperand),
    get_dict(operator, Constraint, Operator),
    get_dict(rightOperand, Constraint, RightOperand),
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
    check_role_membership(CurrentRole, RightOperand).

% Country constraints
check_constraint_type("country", "in", RightOperand, World) :-
    get_current_user_country(World, CurrentCountry),
    check_country_membership(CurrentCountry, RightOperand).

check_constraint_type("country", "notIn", RightOperand, World) :-
    get_current_user_country(World, CurrentCountry),
    \+ check_country_membership(CurrentCountry, RightOperand).

% Organization constraints
check_constraint_type("organization", "eq", RightOperand, World) :-
    get_current_user_organization(World, CurrentOrg),
    normalize_value(CurrentOrg, NormCurrentOrg),
    normalize_value(RightOperand, NormRightOperand),
    NormCurrentOrg = NormRightOperand.

check_constraint_type("organization", "notEq", RightOperand, World) :-
    get_current_user_organization(World, CurrentOrg),
    normalize_value(CurrentOrg, NormCurrentOrg),
    normalize_value(RightOperand, NormRightOperand),
    NormCurrentOrg \= NormRightOperand.

% Research ethics approval constraints
check_constraint_type("researchEthicsApproval", "eq", RightOperand, World) :-
    get_research_ethics_approval(World, CurrentApproval),
    CurrentApproval = RightOperand.

% Data processing method constraints
check_constraint_type("dataProcessingMethod", "in", RightOperand, World) :-
    get_data_processing_method(World, CurrentMethod),
    check_method_membership(CurrentMethod, RightOperand).

% Helper predicates for role membership checking
check_role_membership(CurrentRole, RightOperand) :-
    normalize_value(CurrentRole, NormCurrentRole),
    (   is_list(RightOperand) ->
        (   member(Role, RightOperand),
            normalize_value(Role, NormRole),
            NormCurrentRole = NormRole
        )
    ;   (   normalize_value(RightOperand, NormRightOperand),
            NormCurrentRole = NormRightOperand
        )
    ).

% Helper predicates for country membership checking
check_country_membership(CurrentCountry, RightOperand) :-
    normalize_value(CurrentCountry, NormCurrentCountry),
    (   is_list(RightOperand) ->
        (   member(Country, RightOperand),
            normalize_value(Country, NormCountry),
            NormCurrentCountry = NormCountry
        )
    ;   (   normalize_value(RightOperand, NormRightOperand),
            NormCurrentCountry = NormRightOperand
        )
    ).

% Helper predicates for method membership checking
check_method_membership(CurrentMethod, RightOperand) :-
    normalize_value(CurrentMethod, NormCurrentMethod),
    (   is_list(RightOperand) ->
        (   member(Method, RightOperand),
            normalize_value(Method, NormMethod),
            NormCurrentMethod = NormMethod
        )
    ;   (   normalize_value(RightOperand, NormRightOperand),
            NormCurrentMethod = NormRightOperand
        )
    ).

% Normalize values by converting to atoms and handling URIs
normalize_value(Value, NormValue) :-
    (   atom(Value) ->
        NormValue = Value
    ;   string(Value) ->
        atom_string(NormValue, Value)
    ;   is_dict(Value) ->
        (   get_dict('@value', Value, InnerValue) ->
            normalize_value(InnerValue, NormValue)
        ;   get_dict(value, Value, InnerValue) ->
            normalize_value(InnerValue, NormValue)
        ;   NormValue = Value
        )
    ;   NormValue = Value
    ).

% Helper predicates to extract world state information
get_current_datetime(World, DateTime) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentTime, WorldDict, TimeDict),
        get_dict(dateTime, TimeDict, DateTime)
    ;   get_dict(currentTime, World, TimeDict),
        get_dict(dateTime, TimeDict, DateTime)
    ).

get_current_user_role(World, Role) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentUserRole, WorldDict, Role)
    ;   get_dict(currentUserRole, World, Role)
    ).

get_current_user_country(World, Country) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentUserLocation, WorldDict, LocationDict),
        get_dict(country, LocationDict, Country)
    ;   get_dict(currentUserLocation, World, LocationDict),
        get_dict(country, LocationDict, Country)
    ).

get_current_user_organization(World, Org) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentUserOrganization, WorldDict, Org)
    ;   get_dict(currentUserOrganization, World, Org)
    ).

get_research_ethics_approval(World, Approval) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentResearchContext, WorldDict, ResearchDict),
        get_dict(researchEthicsApproval, ResearchDict, Approval)
    ;   get_dict(currentResearchContext, World, ResearchDict),
        get_dict(researchEthicsApproval, ResearchDict, Approval)
    ).

get_data_processing_method(World, Method) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentResearchContext, WorldDict, ResearchDict),
        get_dict(dataProcessingMethod, ResearchDict, Method)
    ;   get_dict(currentResearchContext, World, ResearchDict),
        get_dict(dataProcessingMethod, ResearchDict, Method)
    ).

% Extract datetime value from different formats
extract_datetime_value(Dict, DateTime) :-
    (   is_dict(Dict) ->
        (   get_dict('@value', Dict, DateTime) ->
            true
        ;   get_dict(value, Dict, DateTime) ->
            true
        ;   DateTime = Dict
        )
    ;   DateTime = Dict
    ).

% Compare two datetime strings
compare_datetimes(DateTime1, DateTime2, Comparison) :-
    parse_datetime(DateTime1, Date1),
    parse_datetime(DateTime2, Date2),
    compare(Comparison, Date1, Date2).

% Parse datetime string to comparable format
parse_datetime(DateTimeStr, ParsedDate) :-
    % Convert to string if needed
    (   atom(DateTimeStr) ->
        atom_string(DateTimeStr, DateStr)
    ;   string(DateTimeStr) ->
        DateStr = DateTimeStr
    ;   DateStr = DateTimeStr
    ),
    % Extract just the date part if it's a full datetime
    (   sub_string(DateStr, 0, 10, _, DatePart) ->
        atom_string(DateAtom, DatePart)
    ;   atom_string(DateAtom, DateStr)
    ),
    atom_date(DateAtom, ParsedDate).

% Convert a date string to a comparable term
atom_date(DateAtom, date(Year, Month, Day)) :-
    atom_string(DateAtom, DateStr),
    split_string(DateStr, '-', '', [YearStr, MonthStr, DayStr]),
    number_string(Year, YearStr),
    number_string(Month, MonthStr),
    number_string(Day, DayStr).

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

% Run all test cases 
run_all_tests :-
    forall(between(1, 10, CaseNumber),
           test_policy_case(CaseNumber, _)).

% Debug helper to show what's being compared
debug_constraint(Constraint, World) :-
    get_dict(leftOperand, Constraint, LeftOperand),
    get_dict(operator, Constraint, Operator),
    get_dict(rightOperand, Constraint, RightOperand),
    format('Checking constraint: ~w ~w ~w~n', [LeftOperand, Operator, RightOperand]),
    (   check_constraint_type(LeftOperand, Operator, RightOperand, World) ->
        format('  -> SATISFIED~n')
    ;   format('  -> NOT SATISFIED~n')
    ).