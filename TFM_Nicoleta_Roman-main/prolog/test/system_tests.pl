% End-to-end system test for the ODRL Policy Authorizer.
%
% This is a black-box test: it talks to a running server.pl instance over
% HTTP, exactly as the web frontend does. It exercises the deployed
% evaluate_policy_dict/5 code path through the RESTful API.
%
% Preconditions: a server started with `swipl server.pl` must be reachable
% on http://localhost:8080 (the run_tests.sh script starts/stops it for you).
%
% Run standalone with:
%   swipl -q -g "consult('test/system_tests.pl'), (system_test -> halt(0) ; halt(1))"

:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).

:- dynamic prolog_base_dir/1.

% Capture the prolog/ directory at load time (prolog_load_context/2 is only
% available during loading, not at runtime).
:- prolog_load_context(directory, TestDir),
   file_directory_name(TestDir, PrologDir),
   retractall(prolog_base_dir(_)),
   assertz(prolog_base_dir(PrologDir)).

base_url('http://localhost:8080').

% Wait until the /api/health endpoint responds, retrying for a few seconds
% to absorb server start-up time.
wait_for_server(0) :-
    !,
    format("SYSTEM: server did not become healthy in time~n"),
    fail.
wait_for_server(Retries) :-
    ( health_ok
    ->  true
    ;   sleep(0.3),
        Next is Retries - 1,
        wait_for_server(Next)
    ).

health_ok :-
    base_url(Base),
    atom_concat(Base, '/api/health', URL),
    catch(
        setup_call_cleanup(
            http_open(URL, Stream, [timeout(2)]),
            json_read_dict(Stream, Reply),
            close(Stream)),
        _Error,
        fail),
    Reply.status == "healthy".

read_json_file(Path, Dict) :-
    setup_call_cleanup(
        open(Path, read, Stream),
        json_read_dict(Stream, Dict),
        close(Stream)).

% Build an absolute path to a resource file relative to the prolog/ directory.
resource(Rel, Abs) :-
    prolog_base_dir(PrologDir),
    atomic_list_concat([PrologDir, '/', Rel], Abs).

post_evaluate(PolicyRel, WorldRel, Action, Target, Result) :-
    resource(PolicyRel, PolicyPath),
    resource(WorldRel, WorldPath),
    read_json_file(PolicyPath, Policy),
    read_json_file(WorldPath, World),
    Payload = _{policy: Policy, world: World, action: Action, target: Target},
    base_url(Base),
    atom_concat(Base, '/api/evaluate', URL),
    http_post(URL, json(Payload), Reply, [json_object(dict)]),
    Result = Reply.result.

expect(Label, Goal) :-
    ( catch(Goal, E, (format("SYSTEM: ~w raised ~w~n", [Label, E]), fail))
    ->  format("SYSTEM: PASS ~w~n", [Label])
    ;   format("SYSTEM: FAIL ~w~n", [Label]),
        throw(system_test_failed(Label))
    ).

system_test :-
    catch(run_system_checks, system_test_failed(_), fail).

run_system_checks :-
    expect(health_endpoint, wait_for_server(30)),
    expect(evaluate_permitted,
           ( post_evaluate('policies/policy_case_1.json', 'world/world_case_1.json',
                           "access", "http://example.com/document/5678", R1),
             R1 == "permitted" )),
    expect(evaluate_denied,
           ( post_evaluate('policies/policy_case_2.json', 'world/world_case_2.json',
                           "use", "http://example.com/data/9012", R2),
             R2 == "denied" )),
    format("SYSTEM: all end-to-end checks passed~n").


