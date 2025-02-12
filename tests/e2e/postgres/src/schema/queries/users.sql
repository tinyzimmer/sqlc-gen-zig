-- name: GetUsers :many
SELECT * FROM users
ORDER BY id ASC;

-- name: GetUserEmails :many
SELECT id, email FROM users
ORDER BY id ASC;

-- name: GetUser :one
SELECT * FROM users
WHERE id = $1 LIMIT 1;

-- name: GetUserIDByEmail :one
SELECT id FROM users
WHERE email = $1 LIMIT 1;

-- name: GetUserIDsByRole :many
SELECT id FROM users
WHERE role = $1
ORDER BY id ASC;

-- name: GetUserIDsBySalaryRange :many
SELECT id FROM users
WHERE salary >= $1 AND salary <= $2
ORDER BY id ASC;

-- name: GetUserIDsByIPAddress :many
SELECT id FROM users
WHERE ip_address = $1
ORDER BY id ASC;

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