-- name: GetOrders :many
SELECT * FROM orders
ORDER BY id ASC;