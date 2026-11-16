-- Четвёртый документ: запас в морозилке.
alter table public.planner_docs drop constraint planner_docs_key_check;
alter table public.planner_docs add constraint planner_docs_key_check check (key in ('dishes','plan','checks','stock'));
