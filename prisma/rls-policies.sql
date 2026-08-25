-- Row Level Security policies for Supabase
-- Apply after migration when using Supabase Auth

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_rate_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Admin full access (service role bypasses RLS)
CREATE POLICY "admin_all_users" ON users FOR ALL USING (true);
CREATE POLICY "read_companies" ON companies FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "read_projects" ON allocation_projects FOR SELECT USING (true);
CREATE POLICY "read_runs" ON allocation_runs FOR SELECT USING (true);
CREATE POLICY "read_invoices" ON invoices FOR SELECT USING (true);
CREATE POLICY "read_audit" ON audit_logs FOR SELECT USING (true);

-- Write policies should be tied to auth.uid() and user_roles in production
-- Example:
-- CREATE POLICY "cost_manager_write" ON monthly_costs
--   FOR INSERT WITH CHECK (
--     EXISTS (
--       SELECT 1 FROM user_roles ur
--       JOIN roles r ON r.id = ur.role_id
--       WHERE ur.user_id = auth.uid()::text
--       AND r.name IN ('Admin', 'CostManager')
--     )
--   );
