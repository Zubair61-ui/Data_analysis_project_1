CREATE VIEW v_monthly_revenue AS
-- paste Question 1's query here (without the outer SELECT wrapper, just the CTE result)
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
    SUM(p.payment_value) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        (SUM(p.payment_value) - LAG(SUM(p.payment_value)) OVER (ORDER BY DATE_TRUNC('month', o.order_purchase_timestamp))) 
        / NULLIF(LAG(SUM(p.payment_value)) OVER (ORDER BY DATE_TRUNC('month', o.order_purchase_timestamp)), 0) * 100, 
    2) AS mom_growth_pct
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp);
ORDER BY order_month;


CREATE VIEW v_category_performance AS
-- paste Question 2's query here (after the typo fix)
WITH category_sales AS (
    SELECT 
        COALESCE(t.product_category_name_english, 'unknown_category') AS category,
        SUM(oi.price) AS total_revenue,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(oi.order_item_id) AS total_items_sold
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t 
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY COALESCE(t.product_category_name_english, 'unknown_category')
)
SELECT 
    category,
    total_revenue,
    total_orders,
    total_items_sold,
    ROUND(total_revenue / NULLIF(total_orders, 0), 2) AS avg_revenue_per_order,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM category_sales
ORDER BY revenue_rank;


CREATE VIEW v_delivery_vs_reviews AS
-- paste Question 3's query here
WITH delivery_reviews AS (
    SELECT 
        o.order_id,
        r.review_score,
        o.order_delivered_customer_date - o.order_purchase_timestamp AS delivery_days,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date,
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 'Late'
            ELSE 'On-time or Early'
        END AS delivery_status
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
)

-- Part A: average review score by delivery speed bucket
SELECT 
    CASE 
        WHEN EXTRACT(DAY FROM delivery_days) <= 7 THEN '0-7 days'
        WHEN EXTRACT(DAY FROM delivery_days) <= 14 THEN '8-14 days'
        WHEN EXTRACT(DAY FROM delivery_days) <= 21 THEN '15-21 days'
        ELSE '22+ days'
    END AS delivery_bucket,
    COUNT(*) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM delivery_reviews
GROUP BY delivery_bucket
ORDER BY MIN(EXTRACT(DAY FROM delivery_days));

-- Part B: on-time vs late delivery — average score comparison
WITH delivery_reviews AS (
    SELECT 
        o.order_id,
        r.review_score,
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 'Late'
            ELSE 'On-time or Early'
        END AS delivery_status
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
)
SELECT 
    delivery_status,
    COUNT(*) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM delivery_reviews
GROUP BY delivery_status;

CREATE VIEW v_repeat_purchase_by_state AS
-- paste Question 4's query here
WITH customer_orders AS (
    SELECT 
        c.unique_customer_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS num_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.unique_customer_id, c.customer_state
),
state_summary AS (
    SELECT 
        customer_state,
        COUNT(*) AS total_customers,
        COUNT(*) FILTER (WHERE num_orders > 1) AS repeat_customers
    FROM customer_orders
    GROUP BY customer_state
)
SELECT 
    customer_state,
    total_customers,
    repeat_customers,
    ROUND(repeat_customers::numeric / NULLIF(total_customers, 0) * 100, 2) AS repeat_rate_pct
FROM state_summary
ORDER BY total_customers DESC;

CREATE VIEW v_seller_region_performance AS
-- paste Question 5's query here
WITH seller_orders AS (
    SELECT 
        s.seller_state,
        oi.order_id,
        oi.price,
        r.review_score
    FROM order_items oi
    JOIN sellers s ON oi.seller_id = s.seller_id
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN reviews r ON oi.order_id = r.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
)
SELECT 
    seller_state,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(AVG(price), 2) AS avg_order_item_value,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    RANK() OVER (ORDER BY SUM(price) DESC) AS revenue_rank
FROM seller_orders
GROUP BY seller_state
ORDER BY revenue_rank;


CREATE VIEW v_order_fact AS
SELECT 
    o.order_id,
    o.order_purchase_timestamp,
    o.customer_id,
    c.customer_state,
    s.seller_state,
    p.payment_value,
    r.review_score,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On-time or Early'
    END AS delivery_status,
    COALESCE(t.product_category_name_english, 'unknown_category') AS category
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_payments p ON o.order_id = p.order_id
LEFT JOIN reviews r ON o.order_id = r.order_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN products pr ON oi.product_id = pr.product_id
LEFT JOIN product_category_name_translation t ON pr.product_category_name = t.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01';