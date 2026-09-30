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