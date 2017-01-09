-- @tag: add_cv_description
-- @description: Zusätzlich kunden/lieferanten-spezifische Beschreibung
-- @depends: add_exclusive_part create_part_customerprices release_3_3_0
ALTER TABLE part_customer_prices ADD COLUMN customer_partdescription text;
ALTER TABLE makemodel ADD COLUMN model_description text;
