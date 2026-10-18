 -- A szekció: Pizza Metrics
 -- A1. How many pizzas were ordered?
 -- In clean customer orders table every row is representing one pizza. I have  counted all pizza id appears in pizza id column  using count(*) function wich returns the total amount pizza have been ordered .
 -- the answer is 14
 select count(pizza_id) as pizzas_ordered from clean_customer_orders;
 
-- A2. How many unique customer orders were made?
-- Answer: 10

-- One row in clean_customer_orders is one pizza, not one order. An order with
-- three pizzas appears as three rows sharing the same order_id, so counting
-- rows would overstate the number of orders.
-- COUNT(DISTINCT order_id) counts each order once, regardless of how many
-- pizzas it contained.
  
SELECT 
    COUNT(DISTINCT order_id) AS total_unique_orders
FROM
    clean_customer_orders;

-- A3. How many successful orders were delivered by each runner?
-- ANSWER
-- 1 --> 4
-- 2 --> 3
-- 3 --> 1
-- 4 --> 0
 -- For answering how many successful orders were delivered by each runner, I had to use a left join, `count`,The left table only showed me the runner ID. 
 -- The right table showed me the run orders table. 
 -- I had to filter the right table in the ON statement with an AND where `cro.cancellation` is NULL, which means the order hasn't been canceled. 
 -- And count order ID gave me the result. How much Order has been delivered by each runner. 
 -- Left join was necessary because we have four runners in total but one of them hasn't made any deliveries. If I didn't use left join in the report, we wouldn't know what Runner 4 has done. 
SELECT 
    cr.runner_id,
    COUNT(cro.order_id) AS total_order_delivered_by_runner
FROM
    clean_runners cr
        LEFT JOIN
    clean_runner_orders cro ON cr.runner_id = cro.runner_id
        AND cancellation IS NULL
GROUP BY cr.runner_id
ORDER BY total_order_delivered_by_runner DESC;



-- A4. How many of each type of pizza was delivered?
-- Answer: Meatlovers 9, Vegetarian 3
--
-- Three tables: clean_customer_orders holds one row per pizza,
-- clean_runner_orders tells whether the order was delivered,
-- clean_pizza_names gives the name instead of the id.
--
-- The cancelled pizzas were ordered but never delivered, so those rows must be
-- removed from the result - that is why the filter is in WHERE and not in ON.
-- (In A3 the opposite was true: there the filter belonged in ON, because the
-- runner with no deliveries had to stay in the report.)
--
-- Ordered: Meatlovers 10, Vegetarian 4. One of each was cancelled.

SELECT 
    cpn.pizza_name, COUNT(*) AS total_delivered
FROM
    clean_customer_orders cco
        INNER JOIN
    clean_runner_orders cro ON cco.order_id = cro.order_id
        INNER JOIN
    clean_pizza_names cpn ON cco.pizza_id = cpn.pizza_id
WHERE
    cro.cancellation IS NULL
GROUP BY cpn.pizza_name;

-- A5. How many Vegetarian and Meatlovers were ordered by each customer?
-- Answer:
--   customer | meatlovers | vegetarian
--   ---------+------------+-----------
--      101   |     2      |     1
--      102   |     2      |     1
--      103   |     3      |     1
--      104   |     3      |     0
--      105   |     0      |     1
--   Totals: 10 Meatlovers, 4 Vegetarian = 14 pizzas, which matches A1.
--
-- "Ordered", not "delivered" - cancelled orders are included here, so
-- clean_runner_orders is not needed. (A4 asked the opposite.)
--
-- Conditional aggregation: SUM(CASE WHEN ... THEN 1 ELSE 0 END) keeps one row
-- per customer and turns the pizza type into a column. The zeros appear by
-- themselves - customer 104 never ordered Vegetarian and 105 never ordered
-- Meatlovers, and both still show up in the report.
-- Grouping by customer_id and pizza_name instead would have dropped those two
-- rows entirely rather than showing them as zero.
SELECT 
    cco.customer_id,
    SUM(CASE
        WHEN cpn.pizza_name = 'Meatlovers' THEN 1
        ELSE 0
    END) AS total_meatlovers_ordered,
    SUM(CASE
        WHEN cpn.pizza_name = 'Vegetarian' THEN 1
        ELSE 0
    END) AS total_vegetarian_ordered
FROM
    clean_customer_orders cco
        INNER JOIN
    clean_pizza_names cpn ON cco.pizza_id = cpn.pizza_id
GROUP BY cco.customer_id;


-- A6. What was the maximum number of pizzas delivered in a single order?
-- Answer: order 4, with 3 pizzas.
--
-- MAX(COUNT(*)) is not valid SQL, so the per-order count is built in a CTE
-- and the second step ranks it.
--
-- RANK() instead of ORDER BY ... LIMIT 1: LIMIT 1 would silently hide a tie,
-- and returning the order_id makes the number checkable against the source.
-- LIMIT 1 is cheaper on large tables; the extra cost is accepted here.

with cte_pizza_in_single_order as(
select 
	cco.order_id,
   count(*) as pizza_ordered_in_single_order
from clean_customer_orders cco
inner join clean_runner_orders cro on cco.order_id = cro.order_id
where cro.cancellation is null
group by cco.order_id
),
cte_ranked as (
select
order_id,
pizza_ordered_in_single_order,
rank() over(order by pizza_ordered_in_single_order desc) as rnk 
from cte_pizza_in_single_order
)
select
order_id,
pizza_ordered_in_single_order
from cte_ranked
where rnk = 1;


 
 -- A7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

 select 
 cco.customer_id,
 count(cco.pizza_id) as total_pizza_ordered,
  sum(case when cco.exclusions is not null or cco.extras is not null then 1 else 0 end) as change_counter,
  sum(case when cco.exclusions is null and cco.extras is null then 1 else 0 end) as no_change_counter
 from clean_customer_orders cco
 inner join clean_runner_orders cro on cco.order_id = cro.order_id
 where  cro.cancellation is null 
 group by  cco.customer_id;
 

 --  A8. How many pizzas were delivered that had both exclusions and extras?
 -- answer  order_id 10 pizza order was the only pizza which had exlusion and extra toppings  only 1 pzza .
 select 
 cco.order_id,
 cco.customer_id,
 count(*) as exclusion_and_extra_applied
 from clean_customer_orders cco
 inner join clean_runner_orders cro on cco.order_id = cro.order_id
 where cro.cancellation is null and (cco.exclusions is not null and cco.extras is not null) 
 group by cco.order_id, cco.customer_id;

-- Orders cluster in six hours: 11, 13, 18, 19, 21, 23.
-- The remaining 18 hours have no orders at all.
-- With 14 pizzas over 10 days this is too little data to claim a daily
-- pattern - a single order shifting by an hour would change the shape.
-- Worth re-checking on a larger period before drawing conclusions.

 with recursive cte_24h as (
 select  0 as  hour_of_day
 
 union all 

 select 
 hour_of_day + 1
 from cte_24h
 where hour_of_day < 23
 )
select
hour_of_day,
count(pizza_id) as total_pizza_ordered
from cte_24h rt
left join clean_customer_orders cco on rt.hour_of_day = hour(cco.order_time)
group by hour_of_day
order by total_pizza_ordered desc;

 -- A10: What was the volume of orders for each day of the week?
 -- From two weeks of data Wendnesday is currently the  best day with a total of 5 orders.
 -- Thursday and Saturday  are following tie sharing 2 orders. Lastly Friday with one order in total. Rest of the not mentioned days are 0.
 with cte_weekday as (
select 1 as week_of_day, 'Monday' as day_name
union all select 2, 'Tuesday'
union all select 3, 'Wednesday'
union all select 4, 'Thursday'
union all select 5, 'Friday'
union all select 6, 'Saturday'
union all select 7, 'Sunday'
 )
 select
	cw.week_of_day,
	cw.day_name,
    count(distinct cco.order_id) as order_counter_per_week_day
 from cte_weekday cw
 left join clean_customer_orders cco on cw.week_of_day = weekday(cco.order_time) + 1
 group by cw.week_of_day, cw.day_name
 order by cw.week_of_day
;