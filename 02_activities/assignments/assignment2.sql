/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables! 
We tell them, no problem! We can produce a list with all of the appropriate details. 

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product

But wait! The product table has some bad data (a few NULL values). 
Find the NULLs and then using COALESCE, replace the NULL with a 
blank for the first problem, and 'unit' for the second problem. 

HINT: keep the syntax the same, but edited the correct components with the string. 
The `||` values concatenate the columns into strings. 
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed. 
All the other rows will remain the same.) */

SELECT 
product_name || ', ' || 
coalesce(product_size,' ') || 
' (' || coalesce(product_qty_type,'unit') || ')' as product_details
FROM product;

--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

-- unique dates per customer → ROW_NUMBER()
WITH visits AS (
  SELECT DISTINCT customer_id, market_date
  FROM customer_purchases
)
SELECT
  customer_id,
  market_date,
  ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY market_date
  ) AS visit_no
FROM visits;



/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */

WITH visits AS (
  SELECT DISTINCT customer_id, market_date
  FROM customer_purchases
),
labeled AS (
  SELECT
    customer_id,
    market_date,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY market_date DESC
    ) AS visit_no
  FROM visits
)
SELECT *
FROM labeled
WHERE visit_no = 1;   -- one row per customer: their most recent visit date

-- Check if the bellow result match the one above
/*SELECT customer_id, MAX(market_date) AS latest_date
FROM customer_purchases
GROUP BY customer_id;*/



/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */
SELECT customer_id, product_id, market_date, COUNT(*) AS rows_that_day
FROM customer_purchases
GROUP BY customer_id, product_id, market_date
HAVING COUNT(*) > 1
ORDER BY customer_id, product_id, market_date;

--“visits” = one row per (customer, product, date)
with visits as (
SELECT DISTINCT 
	customer_id,
	product_id,
	market_date
	FROM customer_purchases
)
SELECT * FROM visits LIMIT 10;

-- Count visits per (customer, product) with window COUNT()
with visits as (
	SELECT DISTINCT 
		customer_id,
		product_id,
		market_date
		FROM customer_purchases
	),
	counts as (
		SELECT 
			customer_id,
			product_id,
			market_date,
			count(*) OVER (
				PARTITION by 
					customer_id, 
					product_id
			) as times_on_distinct_dates
		from visits
	)
SELECT * FROM counts ;

-- Attach that count back to every original row
with visits as (
	SELECT DISTINCT 
		customer_id,
		product_id,
		market_date
		FROM customer_purchases
	),
	counts as (
		SELECT 
			customer_id,
			product_id,
			market_date,
			count(*) OVER (
				PARTITION by 
					customer_id, 
					product_id
			) as times_on_distinct_dates
		from visits
	)
SELECT
  cp.*,
  counts.times_on_distinct_dates
FROM customer_purchases AS cp
JOIN counts
  USING (customer_id, product_id, market_date);

-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

--SELECT * from product;

SELECT
  product_name,
  CASE
    WHEN INSTR(product_name, '-') > 0
      THEN NULLIF( TRIM( SUBSTR(product_name, INSTR(product_name, '-') + 1) ), '' )
  END AS description
FROM product;

/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */

SELECT
  product_name,
  product_size,
  CASE
    WHEN INSTR(product_name, '-') > 0
      THEN NULLIF(TRIM(SUBSTR(product_name, INSTR(product_name, '-') + 1)), '')
  END AS description
FROM product
WHERE product_size REGEXP '[0-9]';

-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day"; 
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

-- Daily totals
DROP TABLE IF EXISTS tmp_daily;
CREATE TEMP TABLE tmp_daily AS
SELECT
  market_date,
  SUM(quantity * cost_to_customer_per_qty) AS day_sales
FROM customer_purchases
GROUP BY market_date;

/* Rank best and worst */
DROP TABLE IF EXISTS tmp_ranked;
CREATE TEMP TABLE tmp_ranked AS
SELECT
  market_date,
  day_sales,
  DENSE_RANK() OVER (ORDER BY day_sales DESC) AS best_rank,
  DENSE_RANK() OVER (ORDER BY day_sales ASC)  AS worst_rank
FROM tmp_daily;

-- UNION best and worst rows
SELECT 0 AS sort_order, 'best'  AS kind, market_date, day_sales
FROM tmp_ranked
WHERE best_rank = 1
UNION
SELECT 1 AS sort_order, 'worst' AS kind, market_date, day_sales
FROM tmp_ranked
WHERE worst_rank = 1
ORDER BY sort_order, market_date;

/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

-- Get each vendor’s products with the unit price
SELECT
	v.vendor_name,
	p.product_name,
	vi.product_id,
	vi.vendor_id,
	vi.original_price AS unit_price
FROM vendor_inventory AS vi
JOIN vendor  AS v ON v.vendor_id  = vi.vendor_id
JOIN product AS p ON p.product_id = vi.product_id;

-- Get the list of all customers.
SELECT customer_id from customer;

-- CROSS JOIN them
WITH vp as (
	SELECT
		v.vendor_name,
		p.product_name,
		vi.product_id,
		vi.vendor_id,
		vi.original_price AS unit_price
	FROM vendor_inventory AS vi
	JOIN vendor  AS v ON v.vendor_id  = vi.vendor_id
	JOIN product AS p ON p.product_id = vi.product_id
),
cust as (
	-- Get the list of all customers.
	SELECT customer_id from customer
)
SELECT
  vp.vendor_name,
  vp.product_name,
  SUM(5 * vp.unit_price) AS revenue_if_sold_5_to_every_customer
FROM vp
CROSS JOIN cust         -- explode to every customer
GROUP BY vp.vendor_name, vp.product_name
ORDER BY vp.vendor_name, vp.product_name;

-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */
CREATE TABLE IF NOT EXISTS product_units AS 
SELECT *,
	CURRENT_TIMESTAMP as snapshot_timestamp
FROM product
WHERE product_qty_type = 'unit';


/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */
INSERT INTO product_units (
    product_id,
    product_name,
    product_size,
    product_category_id,
    product_qty_type,
    snapshot_timestamp
) VALUES (
    31,                          -- choose a new product_id that doesn't exist yet
    'Apple Pie',               -- product_name
    '11"',                        -- product_size
    4,                           -- product_category_id (example)
    'unit',                      -- product_qty_type
    CURRENT_TIMESTAMP            -- new timestamp at insert time
);


-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/
DELETE FROM product_units
WHERE product_name = 'Apple Pie'
  AND snapshot_timestamp < (
    SELECT MAX(snapshot_timestamp)
    FROM product_units
    WHERE product_name = 'Apple Pie'
);


-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */

-- Add the column (run once)
/*ALTER TABLE product_units
ADD COLUMN current_quantity INTEGER;*/

-- Determine the "last" quantity per product (latest market_date)
SELECT 
	product_id, 
	quantity, 
	market_date, 
	vendor_id
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY product_id
      ORDER BY DATE(market_date) DESC, vendor_id DESC
    ) AS rn
  FROM vendor_inventory 
) t
WHERE rn = 1;

-- 2) Coalesce NULL quantities to 0
SELECT 
	product_id, 
	COALESCE(quantity, 0) AS last_quantity, 
	market_date, 
	vendor_id
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY product_id
      ORDER BY DATE(market_date) DESC, vendor_id DESC
    ) AS rn
  FROM vendor_inventory 
) t
WHERE rn = 1;

-- Rearrange so you do get NULLs
-- latest date per product_id in vendor_inventory
WITH latest_date AS (
  SELECT product_id, 
  MAX(DATE(market_date)) AS market_date,
  quantity
  FROM vendor_inventory
  GROUP BY product_id
)
SELECT
  pu.product_id,
  pu.product_name,
  COALESCE(latest_date.quantity, 0) AS last_quantity   -- NULL -> 0 here
FROM product_units pu
LEFT JOIN latest_date
  ON latest_date.product_id = pu.product_id
ORDER BY pu.product_id;

-- Final UPDATE
UPDATE product_units AS pu
SET current_quantity = COALESCE((
  SELECT vi.quantity
  FROM vendor_inventory AS vi
  WHERE vi.product_id = pu.product_id
  ORDER BY DATE(vi.market_date) DESC, vi.vendor_id DESC
  LIMIT 1
), 0);

