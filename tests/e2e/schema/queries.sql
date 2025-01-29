-- name: GetUser :one
SELECT * FROM "user"
WHERE id = $1 LIMIT 1;

-- name: CreateUser :exec
INSERT INTO "user" (
    name, 
    email, 
    password, 
    role, 
    ip_address,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, NOW(), NOW()
);