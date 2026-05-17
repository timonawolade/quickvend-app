-- =============================================
-- QUICKVEND DATABASE SCHEMA
-- Run this in Supabase SQL Editor
-- (Dashboard → SQL Editor → New Query → Paste → Run)
-- =============================================

-- 1. SELLERS TABLE
create table sellers (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default now(),
  email text unique not null,
  business_name text not null,
  slug text unique not null,
  phone text not null,
  whatsapp text not null,
  description text,
  location text not null default 'Lagos',
  verified boolean default false,
  verification_type text, -- 'nin' or 'bvn'
  profile_image_url text,
  rating numeric(2,1) default 0,
  review_count integer default 0,
  plan text default 'free',
  is_active boolean default true,
  user_id uuid references auth.users(id) on delete cascade
);

-- 2. CATEGORIES TABLE
create table categories (
  id serial primary key,
  name text unique not null,
  slug text unique not null,
  emoji text,
  display_order integer default 0
);

-- Seed default categories
insert into categories (name, slug, emoji, display_order) values
  ('Fashion', 'fashion', '👗', 1),
  ('Food & Drinks', 'food-drinks', '🍛', 2),
  ('Beauty', 'beauty', '💄', 3),
  ('Sneakers', 'sneakers', '👟', 4),
  ('Phones & Electronics', 'electronics', '📱', 5),
  ('Home & Living', 'home', '🛋', 6),
  ('Health & Fitness', 'health', '💪', 7),
  ('Services', 'services', '🔧', 8);

-- 3. PRODUCTS TABLE
create table products (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  seller_id uuid references sellers(id) on delete cascade not null,
  category_id integer references categories(id) not null,
  name text not null,
  description text,
  price numeric(12,2) not null,
  compare_price numeric(12,2), -- original price if on sale
  currency text default 'NGN',
  images text[] default '{}', -- array of image URLs
  variants text, -- e.g. "S, M, L, XL" or "Red, Blue, Green"
  in_stock boolean default true,
  featured boolean default false,
  view_count integer default 0,
  inquiry_count integer default 0,
  is_active boolean default true
);

-- 4. REVIEWS TABLE
create table reviews (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default now(),
  seller_id uuid references sellers(id) on delete cascade not null,
  buyer_name text not null,
  buyer_phone text,
  rating integer not null check (rating >= 1 and rating <= 5),
  comment text,
  is_verified_purchase boolean default false
);

-- 5. INQUIRIES TABLE (tracks buyer interest)
create table inquiries (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default now(),
  product_id uuid references products(id) on delete cascade not null,
  seller_id uuid references sellers(id) on delete cascade not null,
  source text default 'whatsapp' -- 'whatsapp', 'instagram', 'facebook'
);

-- =============================================
-- INDEXES (for fast queries)
-- =============================================
create index idx_products_seller on products(seller_id);
create index idx_products_category on products(category_id);
create index idx_products_active on products(is_active, in_stock);
create index idx_products_featured on products(featured) where featured = true;
create index idx_sellers_active on sellers(is_active);
create index idx_sellers_verified on sellers(verified) where verified = true;
create index idx_sellers_slug on sellers(slug);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS on all tables
alter table sellers enable row level security;
alter table products enable row level security;
alter table categories enable row level security;
alter table reviews enable row level security;
alter table inquiries enable row level security;

-- CATEGORIES: anyone can read
create policy "Categories are viewable by everyone" on categories
  for select using (true);

-- PRODUCTS: anyone can read active products, sellers can manage their own
create policy "Active products are viewable by everyone" on products
  for select using (is_active = true);

create policy "Sellers can insert their own products" on products
  for insert with check (
    seller_id in (select id from sellers where user_id = auth.uid())
  );

create policy "Sellers can update their own products" on products
  for update using (
    seller_id in (select id from sellers where user_id = auth.uid())
  );

create policy "Sellers can delete their own products" on products
  for delete using (
    seller_id in (select id from sellers where user_id = auth.uid())
  );

-- SELLERS: anyone can read active sellers, sellers can update their own
create policy "Active sellers are viewable by everyone" on sellers
  for select using (is_active = true);

create policy "Users can insert their own seller profile" on sellers
  for insert with check (user_id = auth.uid());

create policy "Users can update their own seller profile" on sellers
  for update using (user_id = auth.uid());

-- REVIEWS: anyone can read, anyone can insert
create policy "Reviews are viewable by everyone" on reviews
  for select using (true);

create policy "Anyone can create a review" on reviews
  for insert with check (true);

-- INQUIRIES: sellers can read their own
create policy "Sellers can view their own inquiries" on inquiries
  for select using (
    seller_id in (select id from sellers where user_id = auth.uid())
  );

create policy "Anyone can create an inquiry" on inquiries
  for insert with check (true);

-- =============================================
-- STORAGE BUCKET (for product images)
-- =============================================
-- Run this separately or create via Supabase Dashboard:
-- Go to Storage → Create Bucket → Name: "products" → Public: ON

-- =============================================
-- HELPER FUNCTION: Auto-update updated_at
-- =============================================
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger products_updated_at
  before update on products
  for each row execute function update_updated_at();
