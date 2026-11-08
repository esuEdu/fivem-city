Config = {}

Config.Item = 'phone'

-- Jobs whose members (on duty) write news; their boss grades delete anyone's article
Config.Jobs = { reporter = true }

Config.Categories = { 'city', 'police', 'economy', 'sports', 'entertainment', 'other' }

Config.TitleLength = 80
Config.BodyLength = 3000
Config.CommentLength = 300

-- Breaking news notifies every phone; minutes between two from one journalist
Config.BreakingCooldown = 10

-- Articles per page, comments per page
Config.PageSize = 20
Config.CommentPage = 30

-- Who may delete any article or comment (written to the staff log)
Config.StaffAce = 'group.mod'
