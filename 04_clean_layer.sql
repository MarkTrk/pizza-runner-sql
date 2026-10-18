drop table if exists clean_pizza_recipes;	   -- gyerek
drop table if exists clean_runner_orders;      -- gyerek
drop table if exists clean_customer_orders;    -- gyerek
drop table if exists clean_runners;            -- szülő
drop table if exists clean_pizza_names;        -- szülő
drop table if exists clean_pizza_toppings;     -- szülő


/*I had to create the clean runners table first to be able to give a foreign key in another related table. */

create table  clean_runners (
runner_id int primary key,
registration_date date not null
);
insert into clean_runners (runner_id, registration_date)
select
runner_id,
registration_date
from runners;

/*Creating a clean runner order table With the right data type and constraints */

create table clean_runner_orders (
order_id int primary key,
runner_id int not null,
pickup_time datetime,
distance_km decimal(5,2),
duration_mins int,
cancellation varchar(40),
constraint fk_runner_id
	foreign key (runner_id) references clean_runners (runner_id),
constraint chk_cancellation check(cancellation = 'Restaurant Cancellation' or cancellation = 'Customer Cancellation')
);

/*Inserting clustered columns into clean runner orders table */

-- Two MySQL 8.0.46 workarounds are used in this INSERT.
--
-- 1. pickup_time
--    CAST(NULLIF(x,'null') AS DATETIME) returns NULL for every row, not just
--    the rows holding the string 'null'. The NULLIF works on its own and a
--    direct CAST of the same literal works, but the combination fails.
--    MySQL bug #118053 (affects 8.0.42 - 9.3.0, fixed in 9.7.2).
--    STR_TO_DATE with an explicit format is used instead, which also makes
--    the expected format visible rather than letting the server guess it.
--
-- 2. distance_km
--    CAST(REGEXP_SUBSTR(...) AS DECIMAL(5,2)) drops the fractional part:
--    '13.4' becomes 13.00, with no warning. HEX() confirms the regexp returns
--    a clean '13.4', so the data is not at fault. The same failure shape was
--    reported for TRIM in MySQL bug #17043 and fixed in 5.0.21.
--    Adding + 0 forces a numeric conversion first, and the CAST then produces
--    the exact DECIMAL the column expects.
insert into clean_runner_orders(order_id, runner_id, pickup_time, distance_km, duration_mins, cancellation)
select
order_id,
runner_id,
STR_TO_DATE(NULLIF(pickup_time,'null'), '%Y-%m-%d %H:%i:%s') as pickup_time,
CAST(REGEXP_SUBSTR(distance,'^[0-9]+(\\.[0-9]+)?') + 0 AS DECIMAL(5,2)) AS distance_km,
cast(regexp_substr(duration,'^[0-9]+')as unsigned )  as duration_mins,
case
	when cancellation in('','null') then null else cancellation
    end as cancellation
from runner_orders;

create table clean_pizza_names(
pizza_id int primary key,
pizza_name varchar(20) not null
);

insert into clean_pizza_names(pizza_id,pizza_name)
select
pizza_id,
pizza_name
from pizza_names;


create table clean_customer_orders(
order_item_id int auto_increment primary key,
order_id int not null,
customer_id int not null,
pizza_id int not null,
exclusions varchar(10) ,
extras varchar(10),
order_time datetime not null,
constraint fk_pizza_id
foreign key (pizza_id) references clean_pizza_names (pizza_id)
);

insert into clean_customer_orders(order_id,customer_id,pizza_id,exclusions,extras,order_time)
select
order_id,
customer_id,
pizza_id,
case
	 when exclusions in('','null') then null else exclusions
end as exclusions,
case
	when extras in ('','null') then null else extras
end as extras,
order_time
from customer_orders
order by order_id;

create table clean_pizza_toppings(
topping_id int primary key,
topping_name varchar(20) not null
);
insert into clean_pizza_toppings(topping_id,topping_name)
select
topping_id,
topping_name
from pizza_toppings;
-- TODO: pizza_recipes holds a comma-separated topping list in one column.
-- It needs a bridge table (pizza_id, topping_id) built with a recursive CTE,
-- not a straight clean_ copy. See case study section C.

-- pizza_recipes stores the toppings as a comma-separated list in one column
-- ('1, 2, 3, 4, 5, 6, 8, 10'), which cannot be grouped or joined.
-- This builds a bridge table instead: one row per (pizza, topping).
--
-- The recursive CTE splits the list one element at a time:
--   anchor member     - takes the first element, keeps the remainder in 'rest'
--   recursive member  - reads the previous iteration's output, repeats on 'rest'
--   termination       - stops when 'rest' is empty
--
-- String functions used: CONCAT, SUBSTRING_INDEX, SUBSTRING, LOCATE, TRIM.
--
-- The trailing comma added by CONCAT(toppings, ',') is required:
-- without it the last element has no delimiter left, LOCATE returns 0,
-- SUBSTRING(rest, 1) returns the whole string unchanged, and the
-- recursion never terminates.
--
-- Result: 2 source rows -> 14 rows. Composite PK (pizza_id, topping_id)
-- verified: 14 rows, 14 distinct pairs, no NULLs.
create table clean_pizza_recipes(
pizza_id int,
topping_id int,
primary key (pizza_id,topping_id),
constraint fk_recipes_pizza_id
	foreign key (pizza_id) references clean_pizza_names (pizza_id),
constraint fk_recipes_topping_id
	foreign key(topping_id) references clean_pizza_toppings(topping_id)
);
insert into clean_pizza_recipes(pizza_id, topping_id)

with recursive split as(
select 
pizza_id,
substring_index(concat(toppings, ',') ,',',1) as topping_id,
trim(substring(concat(toppings, ',') ,locate(',',concat(toppings, ','))+1)) as trimmed_rest_string
from pizza_recipes

union all

select 
pizza_id,
substring_index(trimmed_rest_string,',',1) as topping_id,
 trim(substring(trimmed_rest_string,locate(',',trimmed_rest_string)+1))  as trimmed_rest_string
from split
where trimmed_rest_string  <> ''
)
select
pizza_id,
cast(topping_id as unsigned)  as topping_id
from split
order by pizza_id, topping_id;

