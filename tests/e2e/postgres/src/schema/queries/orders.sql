-- name: GetOrders :many
SELECT * FROM orders
ORDER BY id ASC;

-- name: GetOrderByID :one
SELECT * FROM orders
WHERE id = $1 LIMIT 1;

-- name: GetOrderPartial :many
SELECT order_date, total_amount, products FROM orders;

-- name: CreateOrder :exec
INSERT INTO orders (
    order_date,
    item_ids,
    products,
    item_quantities,
    shipping_addresses,
    ip_addresses,
    total_amount
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7
);