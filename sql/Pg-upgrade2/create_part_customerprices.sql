-- @tag: create_part_customerprices
-- @description: VK-Preis fuer jeden Kunden speichern und das Datum der Eingabe
-- @depends: release_3_4_0

CREATE TABLE part_customer_prices (
    id          SERIAL PRIMARY KEY,
    parts_id    integer NOT NULL,
    customer_id integer NOT NULL,
    customer_partnumber text,
    price      numeric(15,5),
    sortorder  integer ,
    lastupdate date DEFAULT now(),

    FOREIGN KEY (parts_id)    REFERENCES parts (id),
    FOREIGN KEY (customer_id) REFERENCES customer (id)
);

CREATE INDEX part_customer_prices_parts_id_key    ON part_customer_prices USING btree (parts_id);
CREATE INDEX part_customer_prices_customer_id_key ON part_customer_prices USING btree (customer_id);
