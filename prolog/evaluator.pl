:- use_module(library(http/json)).

% Parse JSON-LD file
parse_json_ld(File, Data) :-
    open(File, read, Stream),
    json_read_dict(Stream, Data),
    close(Stream).


% Check if the policy allows an action on a target within constraints
has_permission(Policy, Action, Target, Date) :-
    member(Permission, Policy.permission),
    Permission.action = Action,
    Permission.target = Target,
    check_constraints(Permission.constraint, Date).

% Validate constraints
check_constraints(Constraints, Date) :-
    member(Constraint, Constraints),
    Constraint.leftOperand = "dateTime",
    Constraint.operator = "lt",
    Constraint.rightOperand.'@value' = RightDate,
    compare_dates(Date, RightDate).

% Compare two date strings in 'YYYY-MM-DD' format
compare_dates(Date1, Date2) :-
    atom_date(Date1, date(Year1, Month1, Day1)),
    atom_date(Date2, date(Year2, Month2, Day2)),
    compare_terms(date(Year1, Month1, Day1), date(Year2, Month2, Day2)).

% Helper predicate to compare date terms
compare_terms(date(Y1, M1, D1), date(Y2, M2, D2)) :-
    (   Y1 < Y2
    ;   Y1 = Y2, M1 < M2
    ;   Y1 = Y2, M1 = M2, D1 < D2).

% Convert a date string to a term for comparison
atom_date(DateStr, date(Year, Month, Day)) :-
    atomic_list_concat([YearAtom, MonthAtom, DayAtom], '-', DateStr),
    atom_number(YearAtom, Year),
    atom_number(MonthAtom, Month),
    atom_number(DayAtom, Day).

