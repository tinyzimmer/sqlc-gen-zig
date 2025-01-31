-- name: GetUsers :many
SELECT * FROM "user";

-- name: GetUser :one
SELECT * FROM "user"
WHERE id = $1 LIMIT 1;

-- name: GetUserByEmail :one
SELECT * FROM "user"
WHERE email = $1 LIMIT 1;

-- name: GetUsersByRole :many
SELECT * FROM "user"
WHERE role = $1;

-- name: GetUserSalaries :many
SELECT id, email, salary FROM "user"
WHERE salary >= sqlc.arg(minimum) AND salary <= sqlc.arg(maximum);

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
