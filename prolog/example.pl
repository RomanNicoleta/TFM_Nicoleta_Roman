% example.pl

% Facts
parent(john, mary).
parent(mary, alice).
parent(alice, emma).

% Rule
grandparent(X, Y) :- parent(X, Z), parent(Z, Y).

% Print a human-readable sentence
print_grandparent(X, Y) :-
    grandparent(X, Y),
    format('~w is the grandparent of ~w.~n', [X, Y]).

% Query example
% ?- grandparent(mary, emma).
