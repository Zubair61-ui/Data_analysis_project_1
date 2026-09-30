/* ============================================================
   OLIST DATA CLEANING CHECKLIST
   Framework applied to EACH table:
     1. Integrity & Duplicate Checks
     2. Missing Value / Null Audits
     3. Data Type & Format Anomalies
     4. Logical Constraints & Range Validation
     5. Categorical Consistency

   Run each section per table. Note the output before moving on -
   this becomes your "data cleaning" writeup for the README later.
   ============================================================ */


/* ============================================================
   TABLE: customers  (olist_customers_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT customer_id, COUNT(*) 
FROM customers 
GROUP BY customer_id 
HAVING COUNT(*) > 1;
-- Expect 0 rows. customer_id should be unique per row in this table.

-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE unique_customer_id IS NULL) AS null_unique_id,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS null_state,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS null_zip
FROM customers;

-- 3. Data Type & Format Anomalies
SELECT customer_zip_code_prefix 
FROM customers 
WHERE customer_zip_code_prefix::text !~ '^[0-9]+$';
-- Catches non-numeric junk in what should be a numeric zip prefix.

-- 4. Logical Constraints & Range Validation
SELECT LENGTH(customer_zip_code_prefix::text) AS zip_length, COUNT(*)
FROM customers
GROUP BY zip_length
ORDER BY zip_length;
-- Brazilian zip prefixes should be a consistent digit length; flag outliers.

-- 5. Categorical Consistency
SELECT DISTINCT customer_state 
FROM customers 
ORDER BY customer_state;
-- Should be exactly 27 valid Brazilian state codes (e.g. SP, RJ, MG).
-- Look for typos, lowercase versions, or stray whitespace.

SELECT DISTINCT customer_city 
FROM customers 
WHERE customer_city != TRIM(LOWER(customer_city))
LIMIT 50;
-- Flags cities with inconsistent casing/whitespace vs a normalized version.


/* ============================================================
   TABLE: orders  (olist_orders_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT order_id, COUNT(*) 
FROM orders 
GROUP BY order_id 
HAVING COUNT(*) > 1;

SELECT o.customer_id 
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
-- Orphaned orders with no matching customer.

-- 2. Missing Value / Null Audit
SELECT 
    order_status,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS null_approved,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_delivered_date
FROM orders
GROUP BY order_status
ORDER BY total DESC;

-- Pull the specific "delivered" orders with missing timestamps
SELECT order_id, order_status, order_purchase_timestamp, 
       order_approved_at, order_delivered_carrier_date, order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND (order_approved_at IS NULL 
       OR order_delivered_carrier_date IS NULL 
       OR order_delivered_customer_date IS NULL);
-- IMPORTANT: nulls here are often *expected* for canceled/unavailable/shipping
-- statuses. Don't delete these rows - group by order_status first to see
-- whether the null pattern makes sense (e.g. "canceled" orders should have
-- null delivered dates). Only investigate nulls that appear on "delivered" status.

-- rows are too broken to trust, exclude them
DELETE FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 3. Data Type & Format Anomalies
SELECT order_id, order_purchase_timestamp
FROM orders
WHERE order_purchase_timestamp::text !~ '^\d{4}-\d{2}-\d{2}';
-- Confirms timestamps are in expected date format after import.

-- 4. Logical Constraints & Range Validation
SELECT COUNT(*) 
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;
-- Should be 0. Delivery before purchase is impossible - a data error if found.

SELECT COUNT(*)
FROM orders
WHERE order_approved_at < order_purchase_timestamp;
-- Should be 0. Approval before purchase is impossible.

SELECT MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)
FROM orders;
-- Sanity check the date range matches what you expect (Olist data spans ~2016-2018).

-- 5. Categorical Consistency
SELECT DISTINCT order_status 
FROM orders 
ORDER BY order_status;
-- Should be a small fixed set: delivered, shipped, canceled, unavailable,
-- invoiced, processing, created, approved. Flag anything unexpected.


/* ============================================================
   TABLE: order_items  (olist_order_items_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT order_id, order_item_id, COUNT(*)
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;
-- Composite key (order_id + order_item_id) should be unique.

SELECT oi.product_id
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
-- Orphaned product references.

SELECT oi.seller_id
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
-- Orphaned seller references.

SELECT oi.order_id
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Orphaned order references.
-- DELETE Orphaned order references
DELETE FROM order_items
WHERE order_id IN (
    SELECT oi.order_id
    FROM order_items oi
    LEFT JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_id IS NULL
);

-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS null_freight,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS null_ship_limit
FROM order_items;

-- 3. Data Type & Format Anomalies
SELECT price, freight_value
FROM order_items
WHERE price::text !~ '^[0-9]+(\.[0-9]+)?$'
   OR freight_value::text !~ '^[0-9]+(\.[0-9]+)?$';
-- Should return 0 rows if numeric columns imported cleanly.

-- 4. Logical Constraints & Range Validation
SELECT MIN(price), MAX(price), AVG(price) FROM order_items;
SELECT COUNT(*) FROM order_items WHERE price <= 0;
-- Zero or negative prices are a red flag - inspect these rows individually.

SELECT MIN(freight_value), MAX(freight_value) FROM order_items;
SELECT COUNT(*) FROM order_items WHERE freight_value < 0;

-- 5. Categorical Consistency
-- N/A for this table - no categorical text fields to standardize.


/* ============================================================
   TABLE: order_payments  (olist_order_payments_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT order_id, payment_sequential, COUNT(*)
FROM order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

SELECT op.order_id
FROM order_payments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Orphaned payment records.
-- DELETE Orphaned payment references
DELETE FROM order_payments
WHERE order_id IN (
    SELECT op.order_id
FROM order_payments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL
);

-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS null_type,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS null_installments,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS null_value
FROM order_payments;

-- 3. Data Type & Format Anomalies
SELECT payment_value
FROM order_payments
WHERE payment_value::text !~ '^[0-9]+(\.[0-9]+)?$';

-- 4. Logical Constraints & Range Validation
SELECT COUNT(*) FROM order_payments WHERE payment_value <= 0;
-- Investigate: some legitimate $0 payments can exist for voucher-only orders,
-- but worth checking the volume.
SELECT * FROM order_payments WHERE payment_value <= 0;
-- DELETE the rows where payment_type is "not_defined"
DELETE FROM order_payments
WHERE payment_type = 'not_defined';


SELECT COUNT(*) FROM order_payments WHERE payment_installments < 0;
SELECT MIN(payment_installments), MAX(payment_installments) FROM order_payments;
-- Installments should be a small positive integer (typically 1-24).

-- 5. Categorical Consistency
SELECT DISTINCT payment_type 
FROM order_payments 
ORDER BY payment_type;
-- Should be: credit_card, boleto, voucher, debit_card, not_defined.
-- Flag "not_defined" volume separately - decide whether to exclude from analysis.


/* ============================================================
   TABLE: reviews  (olist_order_reviews_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT review_id, COUNT(*)
FROM reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- Note: multiple reviews CAN share the same order_id (rare re-reviews) -
-- that's not necessarily a duplicate. review_id is the true unique key.
-- See what a duplicate actually looks like - are the rows IDENTICAL,
-- or do they differ in some way?
SELECT *
FROM reviews
WHERE review_id IN (
    SELECT review_id
    FROM reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id
LIMIT 20;
-- Check the exact duplicate count distribution - are these all just
-- 2x duplicates, or are some review_ids repeated many more times?
SELECT review_id, COUNT(*) AS occurrences
FROM reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;
-- Check if duplicates are TRUE full-row duplicates (every column identical)
-- vs. same review_id but different order_id/score/date (partial duplicates)
SELECT review_id, COUNT(DISTINCT order_id) AS distinct_orders,
       COUNT(DISTINCT review_score) AS distinct_scores,
       COUNT(DISTINCT review_creation_date) AS distinct_dates
FROM reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY distinct_orders DESC
LIMIT 20;
-- review_id alone is NOT a safe unique key. 
--The real grain of this table is (review_id, order_id)
SELECT review_id, order_id, COUNT(*)
FROM reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;

SELECT r.order_id
FROM reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Orphaned reviews with no matching order.
-- DELETE Orphaned reviews with no matching order
DELETE FROM reviews
WHERE order_id IN (
    SELECT r.order_id
FROM reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
);


-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS null_score,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS null_creation_date,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL) AS null_comment,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL) AS null_title
FROM reviews;
-- null_comment / null_title being high is EXPECTED (most reviews have no
-- written text). null_score or null_creation_date should be near 0 -
-- investigate and likely drop rows where these are missing (this is the
-- issue from your import error).

-- 3. Data Type & Format Anomalies
SELECT review_score
FROM reviews
WHERE review_score::text !~ '^[0-9]+$';
-- Should be 0 rows - review_score must be a clean integer.

-- 4. Logical Constraints & Range Validation
SELECT MIN(review_score), MAX(review_score) FROM reviews;
-- Should be strictly between 1 and 5. Anything outside that range is corrupt data.

SELECT COUNT(*) 
FROM reviews 
WHERE review_answer_timestamp < review_creation_date;
-- Should be 0 - can't answer a review before it was created.

-- 5. Categorical Consistency
-- N/A for numeric score field; comment/title text is free-form, not categorical.


/* ============================================================
   TABLE: products  (olist_products_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT product_id, COUNT(*)
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS null_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS null_length,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS null_height,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS null_width
FROM products;

-- null_category is a known gap in this dataset - decide: bucket as
-- "Unknown category" or exclude from category-level analysis.
-- This one COALESCE handles two problems at once: 
-- products with a null product_category_name, and products whose category exists 
-- but has no English translation match (the join-check we ran earlier). 
-- Both cases fall into 'unknown_category'.
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, 'unknown_category') AS category_english
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name;
	
-- 3. Data Type & Format Anomalies
SELECT product_weight_g
FROM products
WHERE product_weight_g::text !~ '^[0-9]+(\.[0-9]+)?$'
  AND product_weight_g IS NOT NULL;

-- 4. Logical Constraints & Range Validation
SELECT COUNT(*) FROM products WHERE product_weight_g <= 0;
-- DELETE product_weight_g with zero values
DELETE FROM products
WHERE products.product_weight_g IN (
SELECT product_weight_g FROM products WHERE product_weight_g <= 0
)
SELECT COUNT(*) FROM products 
WHERE product_length_cm <= 0 OR product_height_cm <= 0 OR product_width_cm <= 0;
-- Zero/negative physical dimensions are impossible - flag these rows.

SELECT MAX(product_weight_g), MAX(product_length_cm) FROM products;
-- Check for absurd outliers (e.g. a 50kg "product" that's likely a data entry error).

-- 5. Categorical Consistency
SELECT product_category_name, COUNT(*) 
FROM products 
GROUP BY product_category_name 
ORDER BY COUNT(*) DESC;
-- Scan for near-duplicate category names (typos, trailing spaces, case differences).

SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN product_category_name_translation t
  ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL;
-- Categories in products table with NO matching English translation -
-- these will show up blank/broken on your Power BI dashboard if not caught now.
-- DELETE these categories
DELETE FROM products 
WHERE product_category_name IN  (
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN product_category_name_translation t
  ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL
)

/* ============================================================
   TABLE: sellers  (olist_sellers_dataset)
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT seller_id, COUNT(*)
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) FILTER (WHERE seller_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE seller_state IS NULL) AS null_state,
    COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) AS null_zip
FROM sellers;

-- 3. Data Type & Format Anomalies
SELECT seller_zip_code_prefix
FROM sellers
WHERE seller_zip_code_prefix::text !~ '^[0-9]+$';

-- 4. Logical Constraints & Range Validation
SELECT LENGTH(seller_zip_code_prefix::text), COUNT(*)
FROM sellers
GROUP BY LENGTH(seller_zip_code_prefix::text)
ORDER BY LENGTH(seller_zip_code_prefix::text);


-- 5. Categorical Consistency
SELECT DISTINCT seller_state 
FROM sellers 
ORDER BY seller_state;
-- Same check as customers table - valid Brazilian state codes only.


/* ============================================================
   TABLE: product_category_name_translation
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT product_category_name, COUNT(*)
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_pt,
    COUNT(*) FILTER (WHERE product_category_name_english IS NULL) AS null_en
FROM product_category_name_translation;

-- 3. Data Type & Format Anomalies
-- N/A - both columns are text, no type conversion risk.

-- 4. Logical Constraints & Range Validation
-- N/A - this is a lookup/reference table, no numeric ranges to validate.

-- 5. Categorical Consistency
SELECT product_category_name_english, COUNT(*)
FROM product_category_name_translation
GROUP BY product_category_name_english
HAVING COUNT(*) > 1;
-- Checks if multiple Portuguese categories map to the same English name
-- (not necessarily wrong, but worth knowing for aggregation decisions).


/* ============================================================
   TABLE: geolocation  (olist_geolocation_dataset)
   Optional - only clean this if you plan to build a map visual.
   ============================================================ */

-- 1. Integrity & Duplicates
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, COUNT(*)
FROM geolocation
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1;
-- This table naturally has many duplicate zip/lat/lng combos - large duplicate
-- counts are expected here, not necessarily an error.
-- Real anomaly check: same zip prefix, but suspiciously inconsistent coordinates
SELECT geolocation_zip_code_prefix,
       MIN(geolocation_lat) AS min_lat, MAX(geolocation_lat) AS max_lat,
       MIN(geolocation_lng) AS min_lng, MAX(geolocation_lng) AS max_lng
FROM geolocation
GROUP BY geolocation_zip_code_prefix
HAVING MAX(geolocation_lat) - MIN(geolocation_lat) > 1  -- ~111km spread, too wide for one zip prefix
    OR MAX(geolocation_lng) - MIN(geolocation_lng) > 1;
-- The fix that will help for buiding map visual in POwer BI later on
SELECT geolocation_zip_code_prefix,
       AVG(geolocation_lat) AS avg_lat,
       AVG(geolocation_lng) AS avg_lng
FROM geolocation
GROUP BY geolocation_zip_code_prefix;
-- 2. Missing Value / Null Audit
SELECT 
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS null_lat,
    COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS null_lng
FROM geolocation;

-- 3. Data Type & Format Anomalies
-- Handled automatically since lat/lng should import as numeric/float.

-- 4. Logical Constraints & Range Validation
SELECT MIN(geolocation_lat), MAX(geolocation_lat),
       MIN(geolocation_lng), MAX(geolocation_lng)
FROM geolocation;
-- Brazil's real bounding box is roughly lat -34 to 5, lng -74 to -34.
-- Anything far outside that range is a bad coordinate.
-- Find every row with a coordinate outside Brazil's real bounding box
SELECT *
FROM geolocation
WHERE geolocation_lat NOT BETWEEN -34 AND 6
   OR geolocation_lng NOT BETWEEN -75 AND -33;
-- Get the count so you know the scale of the problem
SELECT COUNT(*) AS bad_coordinate_rows
FROM geolocation
WHERE geolocation_lat NOT BETWEEN -34 AND 6
   OR geolocation_lng NOT BETWEEN -75 AND -33;
-- This becomes your clean geolocation base going forward
SELECT geolocation_zip_code_prefix,
       AVG(geolocation_lat) AS avg_lat,
       AVG(geolocation_lng) AS avg_lng
FROM geolocation
WHERE geolocation_lat BETWEEN -34 AND 6
  AND geolocation_lng BETWEEN -75 AND -33
GROUP BY geolocation_zip_code_prefix;
-- 5. Categorical Consistency
SELECT DISTINCT geolocation_state 
FROM geolocation 
ORDER BY geolocation_state;
-- Same Brazilian state code check as other tables.