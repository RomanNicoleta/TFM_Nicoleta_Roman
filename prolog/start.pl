% start.pl - Simple script to start the Prolog web server

:- consult('server.pl').

% Start the server and keep it running
run :-
    start_server(8080),
    format('~n=== ODRL Policy Evaluator Server ===~n'),
    format('Server running on: http://localhost:8080'),
    format('Press Ctrl+C to stop the server~n~n'),
    % Keep the server running
    repeat,
    sleep(1),
    fail.

% Initialize and run
:- initialization(run).