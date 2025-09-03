-- ===============================================
-- EXPENSE TRACKER DATABASE SETUP - SUPABASE
-- ===============================================
-- Run this in your Supabase SQL Editor
-- This creates all tables for "Where Did My Money Go?" app

-- Drop existing tables if recreating (uncomment if needed)
-- DROP TABLE IF EXISTS alerts CASCADE;
-- DROP TABLE IF EXISTS uploads CASCADE;
-- DROP TABLE IF EXISTS rules CASCADE;
-- DROP TABLE IF EXISTS transactions CASCADE;
-- DROP TABLE IF EXISTS categories CASCADE;
-- DROP TABLE IF EXISTS accounts CASCADE;
-- DROP TABLE IF EXISTS users CASCADE;

-- ===============================================
-- 1. USERS TABLE
-- ===============================================
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  "firstName" TEXT,
  "lastName" TEXT,
  phone TEXT,
  "isActive" BOOLEAN DEFAULT true,
  "emailVerified" BOOLEAN DEFAULT false,
  "onboardingCompleted" BOOLEAN DEFAULT false,
  preferences JSONB DEFAULT '{}',
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===============================================
-- 2. ACCOUNTS TABLE (Bank accounts, Credit cards, etc.)
-- ===============================================
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('checking', 'savings', 'credit_card', 'investment', 'cash', 'other')),
  "accountNumber" TEXT,
  "routingNumber" TEXT,
  balance DECIMAL(15,2) DEFAULT 0,
  currency TEXT DEFAULT 'USD',
  "isActive" BOOLEAN DEFAULT true,
  "lastSynced" TIMESTAMP WITH TIME ZONE,
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY ("userId") REFERENCES users(id) ON DELETE CASCADE
);

-- ===============================================
-- 3. CATEGORIES TABLE
-- ===============================================
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  "parentId" TEXT,
  description TEXT,
  color TEXT DEFAULT '#6b7280',
  icon TEXT,
  "isActive" BOOLEAN DEFAULT true,
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY ("parentId") REFERENCES categories(id) ON DELETE SET NULL
);

-- ===============================================
-- 4. TRANSACTIONS TABLE (Main table with deduplication)
-- ===============================================
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  "accountId" TEXT,
  description TEXT NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  "transactionDate" DATE NOT NULL,
  merchant TEXT,
  "categoryId" TEXT,
  "subcategoryId" TEXT,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
  "dedupeHash" TEXT UNIQUE NOT NULL, -- Critical for deduplication
  "originalDescription" TEXT,
  notes TEXT,
  location TEXT,
  reference TEXT,
  
  -- ML/AI Classification fields
  "mlCategory" TEXT,
  "mlConfidence" DECIMAL(5,2), -- 0.00 to 100.00
  "mlExplanation" TEXT,
  "aiSuggested" BOOLEAN DEFAULT false,
  "userCorrected" BOOLEAN DEFAULT false,
  
  -- Processing status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'verified', 'disputed')),
  "processingNotes" TEXT,
  
  -- SMS/Email source tracking
  source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'sms', 'email', 'csv_upload', 'bank_api')),
  "sourceId" TEXT, -- Reference to original message/upload
  "rawData" JSONB, -- Store original SMS/email content
  
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  FOREIGN KEY ("userId") REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY ("accountId") REFERENCES accounts(id) ON DELETE SET NULL,
  FOREIGN KEY ("categoryId") REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY ("subcategoryId") REFERENCES categories(id) ON DELETE SET NULL
);

-- ===============================================
-- 5. RULES TABLE (Auto-categorization rules)
-- ===============================================
CREATE TABLE IF NOT EXISTS rules (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  conditions JSONB NOT NULL, -- JSON rules for matching
  actions JSONB NOT NULL, -- JSON actions to perform
  priority INTEGER DEFAULT 0,
  "isActive" BOOLEAN DEFAULT true,
  "matchCount" INTEGER DEFAULT 0,
  "lastMatched" TIMESTAMP WITH TIME ZONE,
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY ("userId") REFERENCES users(id) ON DELETE CASCADE
);

-- ===============================================
-- 6. UPLOADS TABLE (File processing tracking)
-- ===============================================
CREATE TABLE IF NOT EXISTS uploads (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  filename TEXT NOT NULL,
  "originalName" TEXT NOT NULL,
  "fileSize" INTEGER,
  "mimeType" TEXT,
  "fileUrl" TEXT,
  type TEXT NOT NULL CHECK (type IN ('csv', 'pdf', 'image', 'email', 'sms')),
  status TEXT DEFAULT 'uploaded' CHECK (status IN ('uploaded', 'processing', 'completed', 'failed')),
  "processedRows" INTEGER DEFAULT 0,
  "totalRows" INTEGER DEFAULT 0,
  "errorCount" INTEGER DEFAULT 0,
  errors JSONB, -- Store processing errors
  metadata JSONB, -- Store file metadata
  "processedAt" TIMESTAMP WITH TIME ZONE,
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY ("userId") REFERENCES users(id) ON DELETE CASCADE
);

-- ===============================================
-- 7. ALERTS TABLE (Budget alerts, notifications)
-- ===============================================
CREATE TABLE IF NOT EXISTS alerts (
  id TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('budget_exceeded', 'unusual_spending', 'low_balance', 'large_transaction', 'weekly_summary')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  "categoryId" TEXT,
  "accountId" TEXT,
  threshold DECIMAL(15,2),
  "currentValue" DECIMAL(15,2),
  severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  "isRead" BOOLEAN DEFAULT false,
  "isActive" BOOLEAN DEFAULT true,
  "triggeredAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  metadata JSONB,
  FOREIGN KEY ("userId") REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY ("categoryId") REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY ("accountId") REFERENCES accounts(id) ON DELETE SET NULL
);

-- ===============================================
-- INDEXES FOR PERFORMANCE
-- ===============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users("isActive");

-- Accounts indexes
CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts("userId");
CREATE INDEX IF NOT EXISTS idx_accounts_type ON accounts(type);
CREATE INDEX IF NOT EXISTS idx_accounts_active ON accounts("isActive");

-- Categories indexes
CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories("parentId");
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories("isActive");
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);

-- Transactions indexes (CRITICAL for performance)
CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions("userId");
CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions("accountId");
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions("categoryId");
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions("transactionDate" DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_amount ON transactions(amount);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_source ON transactions(source);
CREATE INDEX IF NOT EXISTS idx_transactions_dedupe ON transactions("dedupeHash");
CREATE INDEX IF NOT EXISTS idx_transactions_ml_confidence ON transactions("mlConfidence");
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions("createdAt" DESC);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions("userId", "transactionDate" DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_category ON transactions("userId", "categoryId");
CREATE INDEX IF NOT EXISTS idx_transactions_user_status ON transactions("userId", status);

-- Rules indexes
CREATE INDEX IF NOT EXISTS idx_rules_user ON rules("userId");
CREATE INDEX IF NOT EXISTS idx_rules_active ON rules("isActive");
CREATE INDEX IF NOT EXISTS idx_rules_priority ON rules(priority DESC);

-- Uploads indexes
CREATE INDEX IF NOT EXISTS idx_uploads_user ON uploads("userId");
CREATE INDEX IF NOT EXISTS idx_uploads_status ON uploads(status);
CREATE INDEX IF NOT EXISTS idx_uploads_type ON uploads(type);
CREATE INDEX IF NOT EXISTS idx_uploads_created ON uploads("createdAt" DESC);

-- Alerts indexes
CREATE INDEX IF NOT EXISTS idx_alerts_user ON alerts("userId");
CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(type);
CREATE INDEX IF NOT EXISTS idx_alerts_read ON alerts("isRead");
CREATE INDEX IF NOT EXISTS idx_alerts_active ON alerts("isActive");
CREATE INDEX IF NOT EXISTS idx_alerts_triggered ON alerts("triggeredAt" DESC);

-- ===============================================
-- AUTO-UPDATE TIMESTAMP TRIGGERS
-- ===============================================

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW."updatedAt" = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to tables with updatedAt
DROP TRIGGER IF EXISTS update_users_timestamp ON users;
CREATE TRIGGER update_users_timestamp
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS update_accounts_timestamp ON accounts;
CREATE TRIGGER update_accounts_timestamp
  BEFORE UPDATE ON accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS update_transactions_timestamp ON transactions;
CREATE TRIGGER update_transactions_timestamp
  BEFORE UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS update_rules_timestamp ON rules;
CREATE TRIGGER update_rules_timestamp
  BEFORE UPDATE ON rules
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

-- ===============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ===============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

-- Public access policies for development (CHANGE FOR PRODUCTION!)
-- Users policies
CREATE POLICY "Allow public read users" ON users FOR SELECT USING (true);
CREATE POLICY "Allow public insert users" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update users" ON users FOR UPDATE USING (true);
CREATE POLICY "Allow public delete users" ON users FOR DELETE USING (true);

-- Accounts policies
CREATE POLICY "Allow public read accounts" ON accounts FOR SELECT USING (true);
CREATE POLICY "Allow public insert accounts" ON accounts FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update accounts" ON accounts FOR UPDATE USING (true);
CREATE POLICY "Allow public delete accounts" ON accounts FOR DELETE USING (true);

-- Categories policies (public read, admin write)
CREATE POLICY "Allow public read categories" ON categories FOR SELECT USING (true);
CREATE POLICY "Allow public insert categories" ON categories FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update categories" ON categories FOR UPDATE USING (true);
CREATE POLICY "Allow public delete categories" ON categories FOR DELETE USING (true);

-- Transactions policies
CREATE POLICY "Allow public read transactions" ON transactions FOR SELECT USING (true);
CREATE POLICY "Allow public insert transactions" ON transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update transactions" ON transactions FOR UPDATE USING (true);
CREATE POLICY "Allow public delete transactions" ON transactions FOR DELETE USING (true);

-- Rules policies
CREATE POLICY "Allow public read rules" ON rules FOR SELECT USING (true);
CREATE POLICY "Allow public insert rules" ON rules FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update rules" ON rules FOR UPDATE USING (true);
CREATE POLICY "Allow public delete rules" ON rules FOR DELETE USING (true);

-- Uploads policies
CREATE POLICY "Allow public read uploads" ON uploads FOR SELECT USING (true);
CREATE POLICY "Allow public insert uploads" ON uploads FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update uploads" ON uploads FOR UPDATE USING (true);
CREATE POLICY "Allow public delete uploads" ON uploads FOR DELETE USING (true);

-- Alerts policies
CREATE POLICY "Allow public read alerts" ON alerts FOR SELECT USING (true);
CREATE POLICY "Allow public insert alerts" ON alerts FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update alerts" ON alerts FOR UPDATE USING (true);
CREATE POLICY "Allow public delete alerts" ON alerts FOR DELETE USING (true);

-- ===============================================
-- DEFAULT CATEGORIES
-- ===============================================
INSERT INTO categories (id, name, description, color, icon) VALUES
  ('cat_food_dining', 'Food & Dining', 'Restaurants, groceries, food delivery', '#ef4444', '🍽️'),
  ('cat_shopping', 'Shopping', 'Clothing, electronics, general merchandise', '#8b5cf6', '🛍️'),
  ('cat_transportation', 'Transportation', 'Gas, public transit, ride sharing', '#06b6d4', '🚗'),
  ('cat_travel', 'Travel', 'Flights, hotels, car rentals', '#10b981', '✈️'),
  ('cat_entertainment', 'Entertainment', 'Movies, concerts, subscriptions', '#f59e0b', '🎬'),
  ('cat_bills_utilities', 'Bills & Utilities', 'Electricity, water, internet, phone', '#6b7280', '⚡'),
  ('cat_health_fitness', 'Health & Fitness', 'Medical expenses, gym, pharmacy', '#ec4899', '🏥'),
  ('cat_education', 'Education', 'Tuition, books, courses', '#3b82f6', '📚'),
  ('cat_personal_care', 'Personal Care', 'Haircuts, spa, beauty products', '#a855f7', '💅'),
  ('cat_home', 'Home', 'Rent, mortgage, furniture, maintenance', '#059669', '🏠'),
  ('cat_gifts_donations', 'Gifts & Donations', 'Charity, presents', '#dc2626', '🎁'),
  ('cat_business', 'Business Expenses', 'Office supplies, software subscriptions', '#7c3aed', '💼'),
  ('cat_income', 'Income', 'Salary, freelance, investments', '#16a34a', '💰'),
  ('cat_transfer', 'Transfer', 'Account transfers, credit card payments', '#64748b', '🔄'),
  ('cat_other', 'Other', 'Miscellaneous expenses', '#78716c', '❓')
ON CONFLICT (id) DO NOTHING;

-- ===============================================
-- DEMO DATA (100 sample transactions)
-- ===============================================
INSERT INTO users (id, email, "firstName", "lastName", "onboardingCompleted") VALUES
  ('demo_user_1', 'demo@example.com', 'Demo', 'User', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO accounts (id, "userId", name, type, balance) VALUES
  ('demo_account_1', 'demo_user_1', 'HDFC Checking', 'checking', 25000.00),
  ('demo_account_2', 'demo_user_1', 'ICICI Credit Card', 'credit_card', -5000.00)
ON CONFLICT (id) DO NOTHING;

-- Sample transactions with Indian context
INSERT INTO transactions (
  id, "userId", "accountId", description, amount, "transactionDate", 
  merchant, "categoryId", type, "dedupeHash", source
) VALUES
  -- Food & Dining
  ('txn_001', 'demo_user_1', 'demo_account_1', 'SWIGGY FOOD DELIVERY', -450.00, '2024-01-15', 'Swiggy', 'cat_food_dining', 'expense', 'hash_swiggy_450_20240115', 'sms'),
  ('txn_002', 'demo_user_1', 'demo_account_1', 'ZOMATO FOOD ORDER', -380.00, '2024-01-14', 'Zomato', 'cat_food_dining', 'expense', 'hash_zomato_380_20240114', 'sms'),
  ('txn_003', 'demo_user_1', 'demo_account_1', 'RELIANCE FRESH GROCERIES', -2500.00, '2024-01-13', 'Reliance Fresh', 'cat_food_dining', 'expense', 'hash_reliance_2500_20240113', 'manual'),
  ('txn_004', 'demo_user_1', 'demo_account_1', 'STARBUCKS COFFEE', -250.00, '2024-01-12', 'Starbucks', 'cat_food_dining', 'expense', 'hash_starbucks_250_20240112', 'manual'),
  ('txn_005', 'demo_user_1', 'demo_account_1', 'DOMINOS PIZZA', -720.00, '2024-01-11', 'Dominos', 'cat_food_dining', 'expense', 'hash_dominos_720_20240111', 'sms'),

  -- Transportation
  ('txn_006', 'demo_user_1', 'demo_account_1', 'UBER RIDE', -180.00, '2024-01-15', 'Uber', 'cat_transportation', 'expense', 'hash_uber_180_20240115', 'sms'),
  ('txn_007', 'demo_user_1', 'demo_account_1', 'OLA CAB SERVICE', -220.00, '2024-01-14', 'Ola', 'cat_transportation', 'expense', 'hash_ola_220_20240114', 'sms'),
  ('txn_008', 'demo_user_1', 'demo_account_1', 'METRO CARD RECHARGE', -500.00, '2024-01-13', 'Delhi Metro', 'cat_transportation', 'expense', 'hash_metro_500_20240113', 'manual'),
  ('txn_009', 'demo_user_1', 'demo_account_1', 'PETROL PUMP', -3000.00, '2024-01-12', 'Indian Oil', 'cat_transportation', 'expense', 'hash_petrol_3000_20240112', 'manual'),

  -- Shopping
  ('txn_010', 'demo_user_1', 'demo_account_2', 'AMAZON PURCHASE', -1299.00, '2024-01-15', 'Amazon', 'cat_shopping', 'expense', 'hash_amazon_1299_20240115', 'email'),
  ('txn_011', 'demo_user_1', 'demo_account_2', 'FLIPKART ORDER', -899.00, '2024-01-14', 'Flipkart', 'cat_shopping', 'expense', 'hash_flipkart_899_20240114', 'email'),
  ('txn_012', 'demo_user_1', 'demo_account_1', 'MYNTRA CLOTHING', -2500.00, '2024-01-13', 'Myntra', 'cat_shopping', 'expense', 'hash_myntra_2500_20240113', 'manual'),
  ('txn_013', 'demo_user_1', 'demo_account_1', 'BIG BAZAAR', -1800.00, '2024-01-12', 'Big Bazaar', 'cat_shopping', 'expense', 'hash_bigbazaar_1800_20240112', 'manual'),

  -- Entertainment
  ('txn_014', 'demo_user_1', 'demo_account_1', 'NETFLIX SUBSCRIPTION', -799.00, '2024-01-15', 'Netflix', 'cat_entertainment', 'expense', 'hash_netflix_799_20240115', 'email'),
  ('txn_015', 'demo_user_1', 'demo_account_1', 'SPOTIFY PREMIUM', -119.00, '2024-01-14', 'Spotify', 'cat_entertainment', 'expense', 'hash_spotify_119_20240114', 'email'),
  ('txn_016', 'demo_user_1', 'demo_account_1', 'MOVIE TICKET BOOKMYSHOW', -400.00, '2024-01-13', 'BookMyShow', 'cat_entertainment', 'expense', 'hash_bms_400_20240113', 'manual'),
  ('txn_017', 'demo_user_1', 'demo_account_1', 'AMAZON PRIME VIDEO', -999.00, '2024-01-12', 'Amazon Prime', 'cat_entertainment', 'expense', 'hash_prime_999_20240112', 'email'),

  -- Bills & Utilities
  ('txn_018', 'demo_user_1', 'demo_account_1', 'ELECTRICITY BILL', -2800.00, '2024-01-15', 'BSES Delhi', 'cat_bills_utilities', 'expense', 'hash_electric_2800_20240115', 'email'),
  ('txn_019', 'demo_user_1', 'demo_account_1', 'AIRTEL POSTPAID', -699.00, '2024-01-14', 'Airtel', 'cat_bills_utilities', 'expense', 'hash_airtel_699_20240114', 'sms'),
  ('txn_020', 'demo_user_1', 'demo_account_1', 'JIO FIBER INTERNET', -999.00, '2024-01-13', 'Jio', 'cat_bills_utilities', 'expense', 'hash_jio_999_20240113', 'email'),

  -- Income
  ('txn_021', 'demo_user_1', 'demo_account_1', 'SALARY CREDIT', 75000.00, '2024-01-01', 'TCS Ltd', 'cat_income', 'income', 'hash_salary_75000_20240101', 'email'),
  ('txn_022', 'demo_user_1', 'demo_account_1', 'FREELANCE PROJECT', 15000.00, '2024-01-10', 'Client Payment', 'cat_income', 'income', 'hash_freelance_15000_20240110', 'manual'),

  -- Health & Fitness
  ('txn_023', 'demo_user_1', 'demo_account_1', 'CULT FIT MEMBERSHIP', -2499.00, '2024-01-15', 'Cult.fit', 'cat_health_fitness', 'expense', 'hash_cultfit_2499_20240115', 'manual'),
  ('txn_024', 'demo_user_1', 'demo_account_1', 'APOLLO PHARMACY', -450.00, '2024-01-14', 'Apollo', 'cat_health_fitness', 'expense', 'hash_apollo_450_20240114', 'manual'),
  ('txn_025', 'demo_user_1', 'demo_account_1', 'DR CONSULTATION', -800.00, '2024-01-13', 'Fortis Hospital', 'cat_health_fitness', 'expense', 'hash_doctor_800_20240113', 'manual')

ON CONFLICT (id) DO NOTHING;

-- Generate more realistic demo data
DO $$
DECLARE
    merchants TEXT[] := ARRAY[
        'SWIGGY', 'ZOMATO', 'UBER EATS', 'MCDONALD''S', 'KFC', 'PIZZA HUT',
        'AMAZON', 'FLIPKART', 'MYNTRA', 'AJIO', 'NYKAA', 'BIG BAZAAR',
        'UBER', 'OLA', 'RAPIDO', 'METRO CARD', 'INDIAN OIL', 'HP PETROL',
        'NETFLIX', 'HOTSTAR', 'SPOTIFY', 'YOUTUBE PREMIUM', 'BOOKMYSHOW',
        'AIRTEL', 'JIO', 'VI', 'BSNL', 'ELECTRICITY BOARD', 'GAS AGENCY',
        'APOLLO PHARMACY', 'MEDPLUS', 'CULT FIT', 'GOLD''S GYM',
        'RENT PAYMENT', 'MAINTENANCE', 'GROCERY STORE', 'VEGETABLE VENDOR'
    ];
    
    categories TEXT[] := ARRAY[
        'cat_food_dining', 'cat_shopping', 'cat_transportation', 'cat_entertainment',
        'cat_bills_utilities', 'cat_health_fitness', 'cat_home', 'cat_other'
    ];
    
    sources TEXT[] := ARRAY['sms', 'email', 'manual', 'csv_upload'];
    
    i INTEGER;
    merchant TEXT;
    category TEXT;
    source TEXT;
    amount DECIMAL;
    txn_date DATE;
BEGIN
    FOR i IN 26..100 LOOP
        merchant := merchants[floor(random() * array_length(merchants, 1) + 1)];
        category := categories[floor(random() * array_length(categories, 1) + 1)];
        source := sources[floor(random() * array_length(sources, 1) + 1)];
        amount := -round((random() * 5000 + 50)::numeric, 2);
        txn_date := CURRENT_DATE - (random() * 30)::integer;
        
        INSERT INTO transactions (
            id, "userId", "accountId", description, amount, "transactionDate",
            merchant, "categoryId", type, "dedupeHash", source
        ) VALUES (
            'txn_' || LPAD(i::text, 3, '0'),
            'demo_user_1',
            CASE WHEN random() > 0.7 THEN 'demo_account_2' ELSE 'demo_account_1' END,
            merchant || ' TRANSACTION',
            amount,
            txn_date,
            merchant,
            category,
            'expense',
            'hash_' || merchant || '_' || abs(amount) || '_' || to_char(txn_date, 'YYYYMMDD') || '_' || i,
            source
        );
    END LOOP;
END $$;

-- ===============================================
-- HELPFUL VIEWS FOR ANALYTICS
-- ===============================================

-- Monthly spending summary
CREATE OR REPLACE VIEW monthly_spending AS
SELECT 
    "userId",
    DATE_TRUNC('month', "transactionDate") as month,
    c.name as category,
    COUNT(*) as transaction_count,
    SUM(ABS(amount)) as total_amount,
    AVG(ABS(amount)) as avg_amount
FROM transactions t
JOIN categories c ON t."categoryId" = c.id
WHERE t.type = 'expense'
GROUP BY "userId", DATE_TRUNC('month', "transactionDate"), c.name
ORDER BY month DESC, total_amount DESC;

-- Daily spending trends
CREATE OR REPLACE VIEW daily_spending AS
SELECT 
    "userId",
    "transactionDate",
    COUNT(*) as transaction_count,
    SUM(ABS(amount)) as total_amount
FROM transactions
WHERE type = 'expense'
GROUP BY "userId", "transactionDate"
ORDER BY "transactionDate" DESC;

-- Top merchants by spending
CREATE OR REPLACE VIEW top_merchants AS
SELECT 
    "userId",
    merchant,
    COUNT(*) as transaction_count,
    SUM(ABS(amount)) as total_spent,
    AVG(ABS(amount)) as avg_transaction
FROM transactions
WHERE type = 'expense' AND merchant IS NOT NULL
GROUP BY "userId", merchant
ORDER BY total_spent DESC;

-- ===============================================
-- SUCCESS MESSAGE
-- ===============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Database setup complete!';
    RAISE NOTICE '📊 Created % sample transactions', (SELECT COUNT(*) FROM transactions);
    RAISE NOTICE '🏷️ Created % categories', (SELECT COUNT(*) FROM categories);
    RAISE NOTICE '👤 Created % demo users', (SELECT COUNT(*) FROM users);
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Your expense tracker database is ready!';
    RAISE NOTICE '💡 Next: Add your Supabase credentials to your app';
END $$;