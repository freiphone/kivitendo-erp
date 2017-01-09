-- @tag: add_exclusive_part
-- @description: Exklusive Teile, nur für bestimmte Kunden/von bestimmten Lieferanten
-- @depends: release_3_1_0


ALTER TABLE parts ADD COLUMN customer_exclusive  boolean DEFAULT FALSE;
ALTER TABLE parts ADD COLUMN vendor_exclusive    boolean DEFAULT FALSE;
