drop view if exists v_clean_load_validation;
create view v_clean_load_validation as
with clean_load_validation as (
select
	'clean_customer_orders' as table_name,
    (select count(*) from customer_orders) as expected,
    count(*) as actual
from clean_customer_orders
union all
select
	'clean_pizza_names',
    (select count(*) from pizza_names),
    count(*) as actual
from clean_pizza_names
union all
select
'clean_pizza_recipes',
(select sum(char_length(toppings) - char_length(replace(toppings,',','')) +1)  from pizza_recipes),
count(*) 
from clean_pizza_recipes
union all
select 
'clean_pizza_toppings',
    (select count(*) from pizza_toppings),
    count(*)
from clean_pizza_toppings
union all
select 
'clean_runner_orders',
    (select count(*) from runner_orders),
    count(*)
from clean_runner_orders
union all
select 
'clean_runners',
    (select count(*) from runners),
    count(*)
from clean_runners
)
select
`table_name`,
expected,
actual,
case
	when expected = actual then 'ok' else 'wrong'
end as `status`
from clean_load_validation;


