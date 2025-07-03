:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_files)).

% Load the evaluator
:- consult('evaluator.pl').

% HTTP handlers
:- http_handler(root(.), serve_files, [prefix]).
:- http_handler('/api/evaluate', handle_evaluate, [method(post)]).
:- http_handler('/api/health', handle_health, [method(get)]).

% Serve static files
serve_files(Request) :-
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
    get_dict(action, Permission, Action),
    get_dict(target, Permission, Target),
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

% Helper predicates for dictionary access
get_current_datetime_dict(World, DateTime) :-
    get_dict(currentTime, World, TimeDict),
    get_dict(dateTime, TimeDict, DateTime).

extract_datetime_value_dict(Dict, DateTime) :-
    (   get_dict('@value', Dict, DateTime) ->
        true
    ;   DateTime = Dict
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