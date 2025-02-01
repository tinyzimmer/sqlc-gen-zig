CREATE TYPE user_role AS ENUM ('admin', 'user');

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    password TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'user',
    ip_address INET,
    salary NUMERIC(10, 2),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMP
);

CREATE TYPE product AS ENUM ('laptop', 'desktop', 'mobile', 'tablet');

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    order_date TIMESTAMP DEFAULT NOW() NOT NULL,
    item_ids INTEGER[] NOT NULL,
    products product[] NOT NULL,
    item_quantities NUMERIC(10, 2)[] NOT NULL,
    shipping_addresses TEXT[] NOT NULL,
    ip_addresses INET[] NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL
);
