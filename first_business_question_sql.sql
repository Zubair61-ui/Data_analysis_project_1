WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        SUM(p.payment_value) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'   -- excludes the partial final month
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT 
    order_month, total_revenue, total_orders,
    ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY order_month)) 
        / NULLIF(LAG(total_revenue) OVER (ORDER BY order_month), 0) * 100, 2) AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;