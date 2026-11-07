Config = {}

Config.Item = 'phone'

-- @username: letters, numbers, dot and underscore, lowercase
Config.UsernameLength = { min = 3, max = 20 }
Config.NameLength = 30
Config.BioLength = 150
Config.CaptionLength = 300
Config.CommentLength = 200

-- Hours a story stays up
Config.StoryHours = 24

-- Seconds between two posts (or stories) from one character, and between two comments
Config.PostCooldown = 30
Config.CommentCooldown = 3

-- Posts per page in the feed, explore and profiles; comments per page
Config.PageSize = 15
Config.CommentPage = 30

-- Who may remove anyone's post or comment (written to the staff log)
Config.StaffAce = 'group.mod'
