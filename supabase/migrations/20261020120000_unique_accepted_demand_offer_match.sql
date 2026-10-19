-- Prevent concurrent requests from creating duplicate accepted matches
-- for the same demand/offer pair. Existing accepted duplicates were checked
-- in the connected database before proposing this index.
create unique index if not exists matches_accepted_demand_offer_unique
  on public.matches (demand_id, offer_id)
  where status = 'accepted'
    and demand_id is not null
    and offer_id is not null;
