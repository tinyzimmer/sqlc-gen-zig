-- name: GetUsers :many
SELECT * FROM "user"
ORDER BY id ASC;

-- name: GetUserEmails :many
SELECT id, email FROM "user"
ORDER BY id ASC;

-- name: GetUser :one
SELECT * FROM "user"
WHERE id = $1 LIMIT 1;

-- name: GetUserIDByEmail :one
SELECT id FROM "user"
WHERE email = $1 LIMIT 1;

-- name: GetUserIDsByRole :many
SELECT id FROM "user"
WHERE role = $1;

-- name: GetUserIDsBySalaryRange :many
SELECT id FROM "user"
WHERE salary >= $1 AND salary <= $2;

-- name: GetUserIDsByIPAddress :many
SELECT id FROM "user"
WHERE ip_address = $1;

-- name: CreateUser :exec
INSERT INTO "user" (
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