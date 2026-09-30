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