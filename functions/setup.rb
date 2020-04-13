# Reaction Event for the Team Setup
def reaction_team(bot, e)
  if ((e.channel.id == @setupChannel) and (@setupChannel != nil) and (@setupTeamName != nil))
    reaction = e.message.reactions.to_s
    array = reaction.split(">, ")
    array[0].slice!(0)
    array[(array.length - 1)].slice!(-1)
    array[(array.length - 1)].slice!(-1)
    check = array[0].split("@")
    cross = array[1].split("@")
    if (check[1].include?("2"))
      save_team(e)
      embed_response(bot, e, "m?setup", ":white_check_mark: | **#{@setupTeamName}** registered", "`#{@setupTeamName}` with #{@setupMention} is now assigned to the chnnnal name: `#{e.channel.name}`\nUse `m?setupTime` to setup a timezone for this team.\nUse `m?schedule` to get started, without a timezone.")
    elsif (cross[1].include?("2"))
      embed_response(bot, e, "m?setup", ":arrow_left: | **#{@setupTeamName}** registration cancelled", "**#{e.user.name}**, you have exited the setup menu.")
    end
    @setupChannel = nil
    @setupTeamName = nil
  end
end

# Reaction Event for the Time Setup
def reaction_time(bot, e)
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  teams.all(filter: "{Channel} = \"#{e.channel.id}\"").each do |record|
    found = true
    team = record["Team"]
  end
  channel = e.channel.id
  if(found)
    reaction = e.message.reactions.to_s
    array = reaction.split(">, ")
    array[0].slice!(0)
    array[(array.length - 1)].slice!(-1)
    array[(array.length - 1)].slice!(-1)
    check = array[0].split("@")
    cross = array[1].split("@")
    if (check[1].include?("2"))
      update_team_time(channel)
      embed_response(bot, e, "m?setupTime", ":white_check_mark: | **#{@setupTeamName}** timezone updated!", "`#{@setupTimezone}` is now assigned to the team: `#{@setupTeamName}`\nUse `m?schedule` to get started.")
    elsif (cross[1].include?("2"))
      embed_response(bot, e, "m?setupTime", ":arrow_left: | **#{@setupTeamName}** timezone update cancelled", "**#{e.user.name}**, you have exited the setup menu.")
    end
    @setupChannel = nil
    @setupTeamName = nil
    @setupTime = false
  end
end

# Save Initial Team Setup
def save_team(e)
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  record = teams.create("Team" => "#{@setupTeamName}", "Channel" => "#{@setupChannel}", "Mention" => "#{@setupMention}", "Server" => "#{e.server.id}")
  record.save
end
  
# Update Team Setup to Support Timezones
def update_team_time(channel)
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  id = nil
  teams.all(filter: "{Channel} = \"#{channel}\"").each do |record|
    found = true
    id = record.id
  end
  record = teams.find(id)
  record["Timezone"] = @setupTimezone
  record["Offset"] = @setupOffset
  record.save
end