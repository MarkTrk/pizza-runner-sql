drop view if exists v_load_validation;
create view v_load_validation as 
with cte_load_validation as (
select
'customer_orders' as table_name ,14 as expected, count(*) as actual
from customer_orders 
union all  
select
'pizza_names', 2, count(*)
from pizza_names
union all  
select
'pizza_recipes', 2, count(*)
from pizza_recipes
union all  
select
'pizza_toppings', 12, count(*)
from pizza_toppings
union all  
select
'runner_orders', 10, count(*)
from runner_orders
union all  
select
'runners', 4, count(*)
from runners
)
select
`table_name`,
expected,
actual,
case 
	when expected = actual then 'OK'
    else  'WRONG'
end as `status`   
from cte_load_validation