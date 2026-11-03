CREATE OR REPLACE FUNCTION get_available_stock_summary(
    p_spot_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    spot_id BIGINT,
    spot_address VARCHAR(255),
    type_id BIGINT,
    type_name VARCHAR(50),
    inventory_size REAL,
    available_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
RETURN QUERY
SELECT
    rs.ID AS spot_id,
    rs.Address AS spot_address,
    it.ID AS type_id,
    it.Name AS type_name,
    i.Size AS inventory_size,
    COUNT(i.ID) AS available_count
FROM RentalSpot rs
         JOIN InStock s ON s.SpotID = rs.ID
         JOIN Inventory i ON i.ID = s.InventoryID
         JOIN InventoryType it ON it.ID = i.Type
WHERE (p_spot_id IS NULL OR rs.ID = p_spot_id)
  AND i.State = 'available'
  AND i.Condition <> 'damaged'
GROUP BY rs.ID, rs.Address, it.ID, it.Name, i.Size
ORDER BY rs.ID, it.Name, i.Size;
END;
$$;