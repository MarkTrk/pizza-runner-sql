-- -------- SECTION B----------- 
-- B1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

with recursive dim_date as(
select
	date('2021-01-01') as cohort_week,
    week(date('2021-01-01')) +1 as week_num
union all
select
	 date_add(cohort_week, interval 7 day) as increment, -- here i choose this method insted of  cohort_week + interval 7 day (witch is better it seems working both)
    week_num + 1
from dim_date
where  cohort_week < date('2021-12-31') and week_num < 53
)
select
/*cohort_week,
week_num*/
dd.week_num,
dd.cohort_week,
count(cr.runner_id) as amount_runner_registered
from dim_date dd 
left join clean_runners cr on cr.registration_date between dd.cohort_week and dd.cohort_week + interval 6 day
group by dd.week_num, dd.cohort_week
;


-- B2. What was the average time in minutes it took for each runner to arrive
--     at the Pizza Runner HQ to pickup the order?
--
-- Measured from order_time to pickup_time, cancelled orders excluded.
-- Assumption: runners travel to HQ for every order - HQ is Danny's house,
-- there is no standby crew waiting on site.
-- Limitation: this interval covers the pizza being prepared AND the runner
-- travelling. Pickup happens at whichever finishes later, so the data cannot
-- separate the two. B3 uses the same interval and calls it preparation time.
--
-- answer
-- Runner 1: 14.00 minutes, over 4 orders.
-- Runner 2: 19.67 minutes, over 3 orders.
-- Runner 3: 10.00 minutes, but only 1 order - a single measurement, not an average.
-- Runner 4: NULL - has not made any delivery yet.
-- All four runners have very few orders, so none of these figures is stable.
with cte_order_grain_cco as(
select
order_id, 
order_time
from clean_customer_orders
group by order_id, order_time
)
select
cr.runner_id,
round(avg(timestampdiff(minute, ogc.order_time,cro.pickup_time)),2)  as average_arrival_mins
from clean_runners cr
left join clean_runner_orders cro on cr.runner_id = cro.runner_id and cro.cancellation is null
left join cte_order_grain_cco ogc on cro.order_id = ogc.order_id
group by cr.runner_id;


-- B3. Is there any relationship between the number of pizzas and how long
--     the order takes to prepare?
--
-- Prep time is measured from order_time to pickup_time - the same interval as B2,
-- so it includes the runner travelling to HQ, not only the kitchen.
--
-- answer
-- Yes - preparation time grows with the number of pizzas in the order.
--   1 pizza : 5 orders, 12.00 minutes on average
--   2 pizzas: 2 orders, 18.00 minutes
--   3 pizzas: 1 order , 29.00 minutes
-- Roughly +6 minutes for the second pizza and +11 more for the third.
--
-- Two things stop this from being a measured rate:
--   - the 3-pizza figure comes from a single order, so it is one observation,
--     not an average.
--   - in the 1-pizza group 4 orders took exactly 10 minutes and one took 20.
--     The median is 10 - the mean of 12 is pulled up by that one order.
--
-- With 8 orders in total the direction is clear, the size of the effect is not.
with cte_main as (
select
cco.order_id,
count(cco.pizza_id) as pizza_counter,
cco.order_time,
cro.pickup_time,
timestampdiff(minute, cco.order_time, cro.pickup_time) as prep_time_mins
from clean_customer_orders cco join clean_runner_orders cro on cco.order_id = cro.order_id and cro.pickup_time is not null
group by cco.order_id, cco.order_time
)
select
pizza_counter as pizzas,
count(*) as orders,
round(avg(prep_time_mins), 2) as avg_prep_mins
from cte_main
group by pizza_counter
order by pizzas;

-- B4. What was the average distance travelled for each customer?
-- clean_customer_orders is on pizza grain, not order grain, so I had to reduce it to
-- one row per order first - otherwise an order with three pizzas would count its
-- distance three times. Customer 102 proved it: 16.73 km before the fix, 18.40 km after.
-- clean_runner_orders is already on order grain, so after the CTE the two sides match
-- and an inner join is safe.
-- Cancelled orders are excluded with a WHERE filter - they were never sent out, so they
-- have no distance. The filter sits in WHERE rather than ON because this is an inner
-- join, where both are equivalent.
-- total_orders and row_check are not decoration: if they match, no rows were duplicated
-- by the join. That check is what caught the error above.
-- Note: these averages cover delivered orders only. Customers 101 and 103 each had one
-- cancelled order that is not included here.
-- Answer: customer 104 is the nearest at an average of 10.00 km, followed by 102 at
-- 18.40 km, 101 at 20.00 km and 103 at 23.40 km. Customer 105 is the farthest at 25.00 km.
with cte_order_grain as (
select
customer_id,
order_id,
count(pizza_id) as pizza_amount_in_order
from clean_customer_orders
group by customer_id, order_id
order by customer_id
)
select
cog.customer_id,
count(cog.order_id) as total_orders,
sum(cog.pizza_amount_in_order) as total_pizza,
count(*) as row_check,
round(avg(cro.distance_km),2)  as average_distance_km
from cte_order_grain cog
inner join  clean_runner_orders cro on cog.order_id = cro.order_id
where cro.cancellation is null
group by cog.customer_id
order by average_distance_km;


 -- B5	What was the difference between the longest and shortest delivery times for all orders?
 -- asnwer 30
SELECT
max(duration_mins) - min(duration_mins) as difference_btw_longest_duration_and_shortest
FROM pizza_runner.clean_runner_orders
where cancellation is null;

 -- B6: What was the average speed for each runner for each delivery and do you notice any trend for these values?
 -- data amount is not enough for  giving  an  intel but
 -- runner id 1 when he delivered to the same address he was faster  on the second time by 7km/h which is 18,51% increase in speed (conclusion is  if driver knows the delivery address then  being much more confident for the second time )
 -- runner id 1 has delivered an order for customer 102 on 13.40km with a speed of  40.2 and runner 2 also delivered for 102 by 93km/h but the distance was 23.40 witch means delivery address could be different.
 -- runner id 1 and 3 has delivered for customer 104 for the same distance, Runner 1 was traveling 60km/h 3 was delivering 40km/h 
  
-- B6. What was the average speed for each runner for each delivery,
--     and do you notice any trend for these values?
-- Trend: both runners with more than one delivery got faster over time.
-- Runner 1 went from 37.50 to 60.00 km/h across four deliveries, runner 2 from
-- 35.10 to 93.60 km/h across three. Runner 3 has a single delivery, so nothing
-- can be said about them.
-- Two caveats before anyone acts on this:
-- 1. Eight deliveries across three runners is far too small to call a pattern.
-- 2. Runner 2's last delivery works out at 93.60 km/h - 23.4 km in 15 minutes.
--    That is not a plausible delivery speed, and the duration for that order was
--    one of the malformed source values ('15 minute'). Either the duration or the
--    distance for order 8 is wrong, and the apparent improvement for runner 2
--    rests on it. I would check that record before reporting the trend.

with cte_orders as (                      
    select distinct
           order_id,
           customer_id,
           order_time
    from clean_customer_orders
),
cte_main as (                           
    select co.order_id,
           co.customer_id,
           cro.runner_id,
           co.order_time,
           cro.pickup_time,
           timestampdiff(minute, co.order_time, cro.pickup_time) as runner_arrival_hq_mins,
           cro.duration_mins,
           cro.distance_km,
           adddate(cro.pickup_time, interval cro.duration_mins minute) as assumed_handover_time
    from cte_orders co
    inner join clean_runner_orders cro
            on co.order_id = cro.order_id
           and cro.cancellation is null
)
select runner_id,
       order_id,
       customer_id,
       order_time,
       pickup_time,
       runner_arrival_hq_mins,
       duration_mins,
       distance_km,
       assumed_handover_time,
       round((distance_km / duration_mins) * 60, 2) as speed_kmh
from cte_main
order by runner_id, order_time;

  -- B7. What is the successful delivery percentage for each runner?
  -- Answer:
  -- The amount of data at the moment is not enough to give a fair and exact intel ,because altogether two cancellations happened: one by the customer and the other cancellation by the restaurant
  -- None of these a fault by a runner. In case a customer made a cancellation because the delivery took too long, then yes it would be a fault by a runner but we can't be certain.
  -- In case Both of the canellation flags are because of a runner, then see the  percentage column. It would mean:
																													-- 1. Runner ID 1 has a 100% successful delivery rate.
																													-- 2. Only 75%.
																													-- 3. It's only 50%.
																													-- 4. Hasn't made any delivery just yet.
-- If If cancellation didn't happen because of the runners, then their success rate is 100% for each one of them, except number 4, who has not made any delivery yet. 
  with cte_main as (
    select
  cr.runner_id,
  cro.order_id,
  cro.cancellation
  from clean_runners cr
  left join clean_runner_orders cro on cr.runner_id = cro.runner_id
  ),
  cte_calculated_values as (
    select
	runner_id,
    count(order_id) as assigned_order,
	sum(case when cancellation is null and order_id is not null then 1 else 0 end) as delivered,
    sum(case when cancellation = 'Customer Cancellation' then 1 else 0 end ) as cancelled_by_customer,
	sum(case when cancellation = 'Restaurant Cancellation' then 1 else 0 end ) as cancelled_by_restaurant
  from cte_main
  group by runner_id
  ),
  cte_raw_percentage as (
  select
	runner_id,
    assigned_order,
	delivered,
    cancelled_by_customer,
    cancelled_by_restaurant,
	round((delivered / assigned_order) * 100,2) as percentage,
    	round(delivered
      / nullif(assigned_order - cancelled_by_customer - cancelled_by_restaurant, 0)
      * 100, 2) as success_rate_excl_cancellations_pct
from cte_calculated_values
  )
  select
	runner_id,
    assigned_order,
	delivered,
    cancelled_by_customer,
    cancelled_by_restaurant,
    percentage,
    success_rate_excl_cancellations_pct
  from cte_raw_percentage;

























