CREATE DATABASE tj_price
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LOCALE_PROVIDER = 'libc'
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;
    
DROP TABLE IF EXISTS store_info;
    
CREATE TABLE store_info (
    store_name TEXT,
    street TEXT,
    city TEXT,
    state CHAR(255),
    zip VARCHAR(255),
    landline VARCHAR(255),
    mobile VARCHAR(255),
    website TEXT
);

DROP TABLE IF EXISTS product_prices;

CREATE TABLE product_prices (
    sku VARCHAR(255) NOT NULL,
    retail_price NUMERIC(12,2) NOT NULL,
    item_title TEXT NOT NULL,
    inserted_at TIMESTAMP NOT NULL,
    store_code INT NOT NULL,
    availability BOOLEAN NOT NULL,
    CONSTRAINT pk_product_price PRIMARY KEY (sku, inserted_at, store_code)
);

-- Index on date (for trend analysis)
CREATE INDEX idx_product_prices_inserted_at
    ON product_prices (inserted_at);

-- Index on store
CREATE INDEX idx_product_prices_store_code
    ON product_prices (store_code);

-- Index on product title (full-text search)
CREATE INDEX idx_product_prices_item_title
    ON product_prices USING gin (to_tsvector('english', item_title));