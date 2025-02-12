CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    salary NUMERIC(10, 2),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW,
    archived_at TIMESTAMP
);

