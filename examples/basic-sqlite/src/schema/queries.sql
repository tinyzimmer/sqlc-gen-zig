-- name: GetUsers :many
SELECT * FROM users
ORDER BY id ASC;

-- name: GetUserEmails :many
SELECT id, email FROM users
ORDER BY id ASC;

-- name: GetUser :one
SELECT * FROM users
WHERE id = ? LIMIT 1;

-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = ? LIMIT 1;

-- name: GetUserIDsBySalaryRange :many
SELECT id FROM users
WHERE salary >= ? AND salary <= ?
ORDER BY id ASC;

-- name: CreateUser :exec
INSERT INTO users (
    name, 
    email, 
    password, 
    salary
) VALUES (
    ?, ?, ?, ?
);