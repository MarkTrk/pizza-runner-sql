# Pizza Runner — SQL Case Study

A data cleaning, profiling and analysis project in **MySQL 8.0.46**, built on Danny Ma's
[8 Week SQL Challenge, Case Study #2](https://8weeksqlchallenge.com/case-study-2/).

The source data is deliberately dirty. Rather than patch the values inline, I built it as a
**layered pipeline** — raw, cleansed, analysis — with validation at each boundary, so that
every number in the analysis can be traced back to a source row.

---

## The data problem

The raw tables look simple and are not:

| Column | Ways a value can be missing or malformed |
|---|---|
| `pickup_time`, `distance`, `duration` | the **string** `'null'`, not SQL `NULL` |
| `cancellation` | empty string, real `NULL`, **and** the string `'null'` |
| `exclusions`, `extras` | all three of the above |
| `distance` | `20km`, `13.4km`, `23.4`, `23.4 km` — four formats |
| `duration` | `32 minutes`, `20 mins`, `25mins`, `15 minute`, `10minutes`, `40` — **six** formats |

A `WHERE col IS NULL` filter silently misses every row holding the string `'null'`.
`customer_orders` has **no natural key** — all six columns together still do not identify
every row — so the cleansed layer adds a surrogate key.

---

## Structure

Run the files in numeric order:

| File | What it does |
|---|---|
| `01_schema.sql` | table definitions, raw load |
| `02_load_validation.sql` | row counts checked against the source |
| `03_profiling.sql` | grain, keys, missing-value inventory, format inventory |
| `04_clean_layer.sql` | typed and cleansed tables, surrogate key |
| `05_clean_validation.sql` | proves nothing was lost or invented between layers |
| `06_analysis_section_a.sql` | Section A — pizza metrics |
| `07_analysis_section_b.sql` | Section B — runner and customer experience |

Each analysis query carries a comment stating the grain decisions it makes, which rows it
excludes and why, and what the result does **not** support.

---

## What the profiling established

- **`customer_orders` is at pizza grain, not order grain.** One row per pizza; an order with
  three pizzas has three rows. The repeating `order_id` is the link, not duplication.
- **Missing values in `runner_orders` mark cancellations.** `pickup_time`, `distance` and
  `duration` are empty exactly when `cancellation` is filled — verified with two mutually
  exclusive conditional counters that must sum to the total (2 + 8 = 10). These are not
  missing data; a cancelled order has no pickup time because it never happened.

---

## Findings worth reading the code for

**A grain error that produced a plausible wrong number.**
Averaging distance per customer by joining the pizza-grain table directly weighted each
order by its pizza count. Customer 102 came out at **16.73 km instead of 18.40 km**. Four of
the five customers were unaffected, so the result looked correct. It was caught by checking
the row count against the number of orders — not by the number looking wrong.

**An implausible speed that the data cannot explain.**
Order 8 works out at **93.6 km/h** — 23.4 km in 15 minutes — against 35–60 km/h for every
other delivery. The duration for that order was one of the malformed source values
(`'15 minute'`), and the same customer has two different recorded distances from the same
depot. Any trend in runner speed rests on this record, so it is reported with that caveat
rather than cleaned away.

**A metric that is named after the wrong thing.**
"Successful delivery percentage per runner" ranges from 50% to 100%, but both failures were
cancellations, and the source records *who* cancelled, not *why*. A customer cancellation can
follow a late runner. Excluding both cancellations puts every runner at 100%, which shows the
headline rate is driven by cancellations rather than by runner performance. Resolving it
would need columns this data does not hold: the cancellation timestamp and a free-text reason.

---

## Two MySQL bugs found along the way

Both were isolated by **bisection** — running each part alone, then adding one step at a time,
ruling out the data (`HEX()`), the server (literals) and neighbouring functions (control tests).

**1. `CAST(NULLIF(x, 'null') AS DATETIME)` returns `NULL` for
