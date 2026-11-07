Config = {}

Config.Item = 'phone'

Config.Categories = { 'vehicles', 'property', 'services', 'items', 'jobs', 'other' }

-- Paid from the bank when an ad is published or renewed (city_economy reason 'market-ad'); never given back
Config.Fee = 100

-- Days an ad stays up; renewing starts them again. Expired ads are deleted this many days later.
Config.Days = 7
Config.KeepExpiredDays = 7

-- Ads up at the same time per character
Config.MaxAds = 5

Config.TitleLength = 50
Config.DescriptionLength = 500
Config.MaxPrice = 10000000

-- Ads loaded per page of the list, and photos offered when picking one
Config.PageSize = 30
Config.PhotoPicker = 30

-- Who may remove anyone's ad (written to the staff log)
Config.StaffAce = 'group.mod'
