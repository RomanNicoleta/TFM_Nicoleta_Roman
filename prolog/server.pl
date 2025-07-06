:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_server_files)).

% Load the evaluator
:- consult('evaluator.pl').

% HTTP handlers - order matters!
:- http_handler('/api/evaluate', handle_evaluate, [method(post)]).
:- http_handler('/api/health', handle_health, [method(get)]).
:- http_handler('/policies/', http_reply_from_files('policies', []), [prefix]).
:- http_handler('/world/', http_reply_from_files('world', []), [prefix]).
:- http_handler('/', serve_index, []).
:- http_handler(root(.), http_reply_from_files('.', []), [prefix]).

% Serve index file
serve_index(Request) :-
    http_reply_file('app.html', [], Request).

% Handle policy evaluation requests
handle_evaluate(Request) :-
    cors_enable(Request, [methods([get,post])]),
    http_read_json_dict(Request, Data),
    
    % Extract parameters
    Policy = Data.get(policy),
    World = Data.get(world),
    Action = Data.get(action),
    Target = Data.get(target),
    
    % Evaluate policy
    (   evaluate_policy_dict(Policy, World, Action, Target, Result) ->
        Response = _{result: Result, success: true}
    ;   Response = _{result: "error", success: false, message: "Evaluation failed"}
    ),
    
    reply_json_dict(Response).

% Handle health check
handle_health(Request) :-
    cors_enable(Request, [methods([get,post])]),
    reply_json_dict(_{status: "healthy"}).

% Evaluate policy from dictionary objects
evaluate_policy_dict(Policy, World, Action, Target, Result) :-
    (   has_permission_dict(Policy, Action, Target, World) ->
        Result = permitted
    ;   Result = denied
    ).

% Check if the policy allows an action on a target within constraints
has_permission_dict(Policy, Action, Target, World) :-
    get_dict(permission, Policy, Permissions),
    member(Permission, Permissions),
    get_dict(action, Permission, PolicyAction),
    get_dict(target, Permission, PolicyTarget),
    % Convert to atoms for comparison
    normalize_value(Action, ActionAtom),
    normalize_value(Target, TargetAtom),
    normalize_value(PolicyAction, PolicyActionAtom),
    normalize_value(PolicyTarget, PolicyTargetAtom),
    ActionAtom = PolicyActionAtom,
    TargetAtom = PolicyTargetAtom,
    % Check constraints if they exist
    (   get_dict(constraint, Permission, Constraints) ->
        check_all_constraints_dict(Constraints, World)
    ;   true  % No constraints means always allowed
    ).

% Validate all constraints (all must be satisfied)
check_all_constraints_dict(Constraints, World) :-
    forall(member(Constraint, Constraints),
           check_constraint_dict(Constraint, World)).

% Check individual constraint from dictionary
check_constraint_dict(Constraint, World) :-
    get_dict(leftOperand, Constraint, LeftOperand),
    get_dict(operator, Constraint, Operator),
    get_dict(rightOperand, Constraint, RightOperand),
    check_constraint_type_dict(LeftOperand, Operator, RightOperand, World).

% DateTime constraints from dictionary
check_constraint_type_dict("dateTime", "lt", RightOperand, World) :-
    get_current_datetime_dict(World, CurrentTime),
    extract_datetime_value_dict(RightOperand, RightDate),
    compare_datetimes(CurrentTime, RightDate, <).

check_constraint_type_dict("dateTime", "lteq", RightOperand, World) :-
    get_current_datetime_dict(World, CurrentTime),
    extract_datetime_value_dict(RightOperand, RightDate),
    (compare_datetimes(CurrentTime, RightDate, <) ; 
     compare_datetimes(CurrentTime, RightDate, =)).

check_constraint_type_dict("dateTime", "gt", RightOperand, World) :-
    get_current_datetime_dict(World, CurrentTime),
    extract_datetime_value_dict(RightOperand, RightDate),
    compare_datetimes(CurrentTime, RightDate, >).

check_constraint_type_dict("dateTime", "gteq", RightOperand, World) :-
    get_current_datetime_dict(World, CurrentTime),
    extract_datetime_value_dict(RightOperand, RightDate),
    (compare_datetimes(CurrentTime, RightDate, >) ; 
     compare_datetimes(CurrentTime, RightDate, =)).

% Role constraints from dictionary
check_constraint_type_dict("role", "isPartOf", RightOperand, World) :-
    get_current_user_role_dict(World, CurrentRole),
    check_role_membership_dict(CurrentRole, RightOperand).

% Country constraints from dictionary
check_constraint_type_dict("country", "in", RightOperand, World) :-
    get_current_user_country_dict(World, CurrentCountry),
    check_country_membership_dict(CurrentCountry, RightOperand).

check_constraint_type_dict("country", "notIn", RightOperand, World) :-
    get_current_user_country_dict(World, CurrentCountry),
    \+ check_country_membership_dict(CurrentCountry, RightOperand).

% Organization constraints from dictionary
check_constraint_type_dict("organization", "eq", RightOperand, World) :-
    get_current_user_organization_dict(World, CurrentOrg),
    normalize_value(CurrentOrg, NormCurrentOrg),
    normalize_value(RightOperand, NormRightOperand),
    NormCurrentOrg = NormRightOperand.

check_constraint_type_dict("organization", "notEq", RightOperand, World) :-
    get_current_user_organization_dict(World, CurrentOrg),
    normalize_value(CurrentOrg, NormCurrentOrg),
    normalize_value(RightOperand, NormRightOperand),
    NormCurrentOrg \= NormRightOperand.

% Research ethics approval constraints from dictionary
check_constraint_type_dict("researchEthicsApproval", "eq", RightOperand, World) :-
    get_research_ethics_approval_dict(World, CurrentApproval),
    CurrentApproval = RightOperand.

% Data processing method constraints from dictionary
check_constraint_type_dict("dataProcessingMethod", "in", RightOperand, World) :-
    get_data_processing_method_dict(World, CurrentMethod),
    check_method_membership_dict(CurrentMethod, RightOperand).

% Helper predicates for dictionary-based role membership checking
check_role_membership_dict(CurrentRole, RightOperand) :-
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

% Helper predicates for dictionary-based country membership checking
check_country_membership_dict(CurrentCountry, RightOperand) :-
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

% Helper predicates for dictionary-based method membership checking
check_method_membership_dict(CurrentMethod, RightOperand) :-
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

% Helper predicates for dictionary access
get_current_datetime_dict(World, DateTime) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentTime, WorldDict, TimeDict),
        get_dict(dateTime, TimeDict, DateTime)
    ;   get_dict(currentTime, World, TimeDict),
        get_dict(dateTime, TimeDict, DateTime)
    ).

get_current_user_role_dict(World, Role) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentUserRole, WorldDict, Role)
    ;   get_dict(currentUserRole, World, Role)
    ).

get_current_user_country_dict(World, Country) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentUserLocation, WorldDict, LocationDict),
        get_dict(country, LocationDict, Country)
    ;   get_dict(currentUserLocation, World, LocationDict),
        get_dict(country, LocationDict, Country)
    ).

get_current_user_organization_dict(World, Org) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentUserOrganization, WorldDict, Org)
    ;   get_dict(currentUserOrganization, World, Org)
    ).

get_research_ethics_approval_dict(World, Approval) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentResearchContext, WorldDict, ResearchDict),
        get_dict(researchEthicsApproval, ResearchDict, Approval)
    ;   get_dict(currentResearchContext, World, ResearchDict),
        get_dict(researchEthicsApproval, ResearchDict, Approval)
    ).

get_data_processing_method_dict(World, Method) :-
    (   get_dict(world, World, WorldDict),
        get_dict(currentResearchContext, WorldDict, ResearchDict),
        get_dict(dataProcessingMethod, ResearchDict, Method)
    ;   get_dict(currentResearchContext, World, ResearchDict),
        get_dict(dataProcessingMethod, ResearchDict, Method)
    ).

extract_datetime_value_dict(Dict, DateTime) :-
    (   is_dict(Dict) ->
        (   get_dict('@value', Dict, DateTime) ->
            true
        ;   get_dict(value, Dict, DateTime) ->
            true
        ;   DateTime = Dict
        )
    ;   DateTime = Dict
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

% Start the server
start_server :-
    start_server(8080).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]),
    format('Server started on port ~w~n', [Port]),
    format('Visit http://localhost:~w to use the application~n', [Port]).

% Stop the server
stop_server :-
    http_stop_server(8080, []).

% Query to start the server
:- initialization(start_server).