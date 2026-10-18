-- DATA QUALITY: runner_orders
--
-- "Missing" is written three different ways in this table, and the form
-- differs by column:
--   pickup_time, distance, duration : the string 'null' only (rows 6 and 9)
--   cancellation                    : empty string '' (rows 1-2),
--                                     a real NULL (rows 3-5),
--                                     and the string 'null' (rows 7, 8, 10)
--
-- Any cleaning rule has to cover all three forms. A WHERE ... IS NULL test
-- alone silently misses the rows holding the string 'null'.
--
-- FINDING: pickup_time, distance and duration are empty exactly when the
-- order was cancelled. Verified with conditional counts:
--   2 cancelled + 8 delivered = 10 rows, so no row falls outside both groups.
--
-- These NULLs are therefore not missing data. A cancelled order has no pickup
-- time, no distance and no duration because the delivery never happened.
-- They stay NULL in the clean layer - there is nothing to recover.
-- Key check: can (pizza_id, topping_id) be the primary key?
-- Result: 14 rows / 14 distinct pairs, no NULLs.
-- Neither column is unique alone (2 and 12 distinct) -> composite PK.

select
count(*) all_orders,
count(order_id) as non_null_ids,
count(distinct order_id) as distinct_order_ids,

sum(
case 
	when (pickup_time = 'null' and distance = 'null' and duration  = 'null') and (cancellation <> '' and cancellation <> 'null') then 1  else 0
	end
)as cancelled_orders,
sum(
case
	when (pickup_time <> 'null' and distance <> 'null' and duration<> 'null') and (cancellation = '' or cancellation is null or cancellation ='null') then 1 else 0
    end
) as delivered_orders
from runner_orders;

select
distance,
count(*) as appear
from runner_orders
group by distance 
order by appear desc;

select
duration,
count(*) as appear
from runner_orders
group by duration 
order by appear desc;
