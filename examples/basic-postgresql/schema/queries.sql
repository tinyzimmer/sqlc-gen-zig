-- name: GetUsers :many
SELECT * FROM users;

-- name: GetUser :one
SELECT * FROM users
WHERE id = $1 LIMIT 1;

-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = $1 LIMIT 1;

-- name: GetUsersByRole :many
SELECT * FROM users
WHERE role = $1;

-- name: GetUserSalaries :many
SELECT id, email, salary FROM users
WHERE salary >= sqlc.arg(minimum) AND salary <= sqlc.arg(maximum);

-- name: CreateUser :exec
INSERT INTO users (
    name, 
    email, 
    password, 
    role, 
    ip_address,
    salary,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6, NOW(), NOW()
);
