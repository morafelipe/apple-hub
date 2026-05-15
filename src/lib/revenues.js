import { defaultPool } from "@/lib/db";

export async function getRevenues() {
  const [todayRows, historicRows, totalResult, todayResult] = await Promise.all([
    defaultPool.query(`
      SELECT id, order_id, product_id, quantity, unit_price, subtotal, status, created_at
      FROM order_items
      WHERE status IN ('Enviado', 'Entregado', 'Garantía')
        AND created_at::date = CURRENT_DATE
      ORDER BY created_at DESC
    `),
    defaultPool.query(`
      SELECT id, order_id, product_id, quantity, unit_price, subtotal, status, created_at
      FROM order_items
      WHERE status IN ('Enviado', 'Entregado', 'Garantía')
        AND created_at::date <> CURRENT_DATE
      ORDER BY created_at DESC
    `),
    defaultPool.query("SELECT total_revenues() AS total"),
    defaultPool.query(`
      SELECT COALESCE(SUM(subtotal), 0.00) AS today_total
      FROM order_items
      WHERE status IN ('Enviado', 'Entregado', 'Garantía')
        AND created_at::date = CURRENT_DATE
    `),
  ]);

  return {
    todayRevenues: todayRows.rows,
    historicRevenues: historicRows.rows,
    historicTotal: totalResult.rows[0]?.total ?? 0,
    todayTotal: todayResult.rows[0]?.today_total ?? 0,
  };
}
