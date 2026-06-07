-- ============================================================
-- SUPABASE SQL SCHEMA для дашборда Bitrix24
-- Запустите в Supabase → SQL Editor → New Query → Run
-- ============================================================

-- 1. Профили пользователей (роли: admin / viewer)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT,
  role TEXT DEFAULT 'viewer' CHECK (role IN ('admin','viewer')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Автоматически создаём профиль при регистрации пользователя
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles(id, email, role)
  VALUES (NEW.id, NEW.email, 'viewer')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Стоимость лида по дням (расходы Войстрансфер)
CREATE TABLE IF NOT EXISTS lead_costs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL UNIQUE,
  source TEXT DEFAULT 'Войстрансфер',
  cost_per_lead NUMERIC(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Ставки продажи лидов
CREATE TABLE IF NOT EXISTS sale_rates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer TEXT,
  geo_mode TEXT DEFAULT 'include',
  geos JSONB DEFAULT '[]',
  sale_rate NUMERIC(12,2) DEFAULT 0,
  date_from DATE,
  date_to DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Дополнительные расходы
CREATE TABLE IF NOT EXISTS extra_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL,
  category TEXT,
  description TEXT,
  amount NUMERIC(12,2) DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Фактические поступления от заказчиков
CREATE TABLE IF NOT EXISTS actual_payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  payment_date DATE NOT NULL,
  customer TEXT,
  period_from DATE,
  period_to DATE,
  amount NUMERIC(12,2) DEFAULT 0,
  comment TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Ставка оператора
CREATE TABLE IF NOT EXISTS operator_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  rate_per_lead NUMERIC(10,2) DEFAULT 200,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO operator_settings(rate_per_lead) VALUES(200) ON CONFLICT DO NOTHING;

-- 7. Реестр брака
CREATE TABLE IF NOT EXISTS bad_leads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  phone TEXT,
  name TEXT,
  responsible TEXT,
  customer TEXT,
  source TEXT,
  defect_reason TEXT,
  comment TEXT,
  def_date DATE DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Общие настройки дашборда
CREATE TABLE IF NOT EXISTS dashboard_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO dashboard_settings(setting_key, setting_value) VALUES
  ('op_rate', '200'),
  ('tax_rate', '7')
ON CONFLICT (setting_key) DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- Без авторизации данные недоступны
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE extra_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE actual_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE operator_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bad_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_settings ENABLE ROW LEVEL SECURITY;

-- Все авторизованные могут читать
CREATE POLICY "auth_read" ON lead_costs FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read" ON sale_rates FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read" ON extra_expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read" ON actual_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read" ON operator_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read" ON bad_leads FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read" ON dashboard_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_own" ON profiles FOR SELECT TO authenticated USING (id = auth.uid());

-- Только admin может писать
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS(SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
$$;

CREATE POLICY "admin_write" ON lead_costs FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "admin_write" ON sale_rates FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "admin_write" ON extra_expenses FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "admin_write" ON actual_payments FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "admin_write" ON operator_settings FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "admin_write" ON bad_leads FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY "admin_write" ON dashboard_settings FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- ============================================================
-- ПОСЛЕ СОЗДАНИЯ: назначьте роль admin первому пользователю
-- Выполните после регистрации:
-- UPDATE profiles SET role = 'admin' WHERE email = 'ваш@email.ru';
-- ============================================================
