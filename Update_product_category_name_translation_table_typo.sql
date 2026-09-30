-- Standardize the typo before it reaches your dashboard
UPDATE product_category_name_translation
SET product_category_name_english = REPLACE(product_category_name_english, 'costruction', 'construction')
WHERE product_category_name_english LIKE 'costruction%';