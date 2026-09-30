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