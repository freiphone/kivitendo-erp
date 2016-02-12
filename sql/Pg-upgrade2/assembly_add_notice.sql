-- @tag: assembly_add_notice
-- @description: Add notice field to table assembly
-- @depends:  release_3_4_0

ALTER TABLE assembly          ADD notice character varying(75);
