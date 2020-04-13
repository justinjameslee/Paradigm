require "bundler"
Bundler.require

require "dotenv"
require "active_support/all"
require_relative "functions/schedule"
require_relative "functions/setup"
require_relative "functions/reminder"
Dotenv.load

bot = Discordrb::Commands::CommandBot.new token: ENV["TOKEN"], client_id: ENV["ID"], prefix: ENV["PREFIX"]
bot.run true

@count = 0
@reminderTimeArray = Array.new

@setupTime = false
@setupTeam = false

@startup = true

@reminderStartup = true
@reminderTimer = Time.now
@scheduleTimer = Time.now

@setupTimezone = ""
@setupOffset = ""
@setupMention = ""

#dateDay = DateTime.parse(Time.parse(testTime).to_s)

class Event
  attr_accessor :id, :date, :type, :info, :t1, :t2, :t3, :duration

  def initialize()
    id = nil
    date = nil
    type = nil
    info = nil
    t1 = nil
    t2 = nil
    t3 = nil
    duration = nil
  end
end

class Events
  attr_accessor :date, :event

  def initialize()
    @date = Array.new
    @event = Array.new
  end
end

class Reminder
  attr_accessor :time, :channel

  def initialize()
    time = Array.new
    channel = Array.new
  end
end

# Help Command
bot.command(:help, description: "Command List", usage: "m?help") do |e|
  e.channel.send_embed do |embed|
    embed.colour = 0xef0000
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: "\u{1F4BB} Command List", icon_url: "https://i.imgur.com/tpZy4mK.jpg")
    embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: "https://i.imgur.com/yVVmjG5.png")
    embed.add_field(name: "**#{ENV["PREFIX"]}setup** [team name] [mention role]", value: "Setup Schedule Bot for Team")
    embed.add_field(name: "**#{ENV["PREFIX"]}setupTime** [timezone] ([timezone] [timezone])", value: "Setup Time for Intitialised Team")
    embed.add_field(name: "**#{ENV["PREFIX"]}schedule**", value: "Resets Channel and Displays Teams Schedule")
    embed.add_field(name: "**#{ENV["PREFIX"]}delete** [team name]", value: "Remove Schedule Bot from channel")
    embed.add_field(name: "**#{ENV["PREFIX"]}invite**", value: "Provides the invite link for Imagination")
    embed.add_field(name: "**#{ENV["PREFIX"]}info**", value: "Provides information about the bot itself")
    embed.add_field(name: "**#{ENV["PREFIX"]}prune** [amount]", value: "Deletes messages in this channel")
    embed.add_field(name: "**#{ENV["PREFIX"]}spam** [message] [userid] [amount]", value: "Spams a user, x amount of times with a custom message.")
    embed.add_field(name: "**#{ENV["PREFIX"]}restart**", value: "Restart the bot (Owner Only)")
    embed.add_field(name: "**#{ENV["PREFIX"]}kill**", value: "Shutdown the bot (Owner Only)")
  end
end

# Owner Commands
bot.command(:restart, description: "Restart the bot (Owner Only)", usage: "m?restart") do |e|
  break unless e.user.id == ENV["OWNER_ID"].to_i
  e.respond("Restarting...")
  sleep 1
  exec("bundle exec ruby main.rb")
end

bot.command(:kill, description: "Shutdown the bot (Owner Only)", usage: "m?kill") do |e|
  break unless e.user.id == ENV["OWNER_ID"].to_i
  e.channel.send_embed do |embed|
    embed.image = Discordrb::Webhooks::EmbedImage.new(
      url: "https://i.imgur.com/C3Q2imN.jpg",
    )
    e.respond("ok, bot down")
  end
  exec("cls")
  exit
end

bot.command(:prune, description: "Deletes messages in this channel", min_args: 1, required_permissions: [:manage_messages], usage: "m?delete [amount]") do |e, amount|
  break unless e.user.id == ENV["OWNER_ID"].to_i
  if e.bot.profile.on(e.server).permission?(:manage_messages, e.channel)
    amount = amount.to_i
    next "Can't delete less than 2 messages." if amount < 2

    while amount > 100
      e.channel.prune(100)
      amount -= 100
    end
    e.channel.prune(amount) if amount >= 2
    nil
  else
    e.respond("Needs the manage messages permission.")
  end
end

# Fun/Interactive/General Commands
bot.command(:spam, description: "Spam a user", usage: "m?spam [msg] [userid] [amount]") do |e, *arg|
  amount = arg.pop
  user = arg.pop
  msg = arg.join(" ")
  amount.to_i.times do |i|
    bot.user(user).pm(msg)
    sleep(1)
  end
  e.respond("<@#{user}> o7")
end

bot.command(:invite, description: "Provides the invite link for the bot", usage: "m?invite", chain_usable: false) do |e|
  e.bot.invite_url
end

bot.command(:info, description: "Provides information regarding the author and version number", usage: "m?info") do |e|
  e.respond("```css\n[Imagination Bot Information]\n{Author: \"FiLeZekk#2594\"}\n{Version: \"v1.12\"}\n{Prefix: \"m?\"}```")
end

# General Commands for Scheduling
bot.command(:schedule, description: "Resets Channel and Displays Teams Schedule", usage: "m?schedule") do |e|
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  teams.all(filter: "{Channel} = \"#{e.channel.id}\"").each do |record|
    found = true
  end
  if (found)
    send_schedule(bot, e.channel.id)
  else
    embed_response(bot, e, "Warning", ":warning: | #{e.channel.name}", "`#{e.channel.name}` does not have a team associated with this channel.\nUse `m?setup` to get started.")
  end
end

bot.command(:delete, description: "Remove Schedule Bot from Channel", usage: "m?delete") do |e, *arg|
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  team = nil
  id = nil
  teams.all(filter: "{Channel} = \"#{e.channel.id}\"").each do |record|
    found = true
    team = record["Team"]
    id = record.id
  end
  if (!found)
    embed_response(bot, e, "Warning", ":warning: | #{e.channel.name}", "`#{e.channel.name}` does not have a team associated with this channel.\nUse `m?setup` to get started.")
    break
  end
  if (team == arg.join(" "))
    record = teams.find(id)
    record.destroy
    embed_response(bot, e, "Success", ":white_check_mark: | **#{team}** removed", "`#{team}` has successfully been removed from the Paradigm Schedule Bot Service.\nUse `m?setup` to register a new team!")
  else
    embed_response(bot, e, "Warning", ":warning: | #{team}", "`m?delete [team name]` To confirm the deletion, please ensure you type the team name when calling the command to confirm the deletion process.")
    break
  end
end

bot.command(:setup, description: "Setup Schedule Bot for Team", usage: "m?setup [team name] [mention role]") do |e, *arg|
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  teams.all(filter: "{Channel} = \"#{e.channel.id}\"").each do |record|
    found = true
    team = record["Team"]
  end
  if (found)
    embed_response(bot, e, "Warning", ":warning: | #{e.channel.name}", "`#{e.channel.name}` already has a team associated with this channel: `#{team}`")
    break
  end
  @setupChannel = e.channel.id
  @setupMention = arg.pop
  @setupTeamName = arg.join(" ")
  if (@setupTeamName == "")
    embed_response(bot, e, "m?setup", ":information_source: | Command Information", "You need to include team name when using the command\n\n`m?setup [team name] [mention role]`- please remember to remove the square brackets.")
    break
  else
    @setupTeam = true
    msg = embed_response(bot, e, "m?setup", ":information_source: | Initialisation for #{@setupTeamName}", "Are you sure you want to setup the schedule bot in this channel?\n`It will delete all the messages in this channel.`\nReact below once you have read and understand the risks.")
    msg.create_reaction("\u{2705}")
    msg.create_reaction("\u{274E}")
  end
end

bot.command(:setupTime, description: "Setup Time for Intitialised Team", usage: "m?setupTime [timezone] ([timezone] [timezone])") do |e, *arg|
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  teams.all(filter: "{Channel} = \"#{e.channel.id}\"").each do |record|
    found = true
    @setupTeamName = record["Team"]
    @setupChannel = record["Channel"]
  end
  if (found)
    timeStr = arg.join(" ")
    if (timeStr == "")
      embed_response(bot, e, "m?setupTime", ":information_source: | Command Information", "You need to include the timezone when using the command\n\n`m?setupTime ([timezone] [timezone])`- please remember to remove the square brackets.\n\nRefer to the TZ Database column for your timezone: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
      break
    else
      time = timeStr.split(" ")
      if (time.length <= 3)
        identifiers = TZInfo::Timezone.all_identifiers
        @setupTimezone = ""
        @setupOffset = ""
        time.length.times do |i|
          if (identifiers.include?(time[i]))
            tz = TZInfo::Timezone.get(time[i])
            utc = tz.local_to_utc(tz.now)
            period = tz.period_for_utc(utc)
            @setupTimezone += period.zone_identifier.to_s + " "
            formatOffset = (period.offset.utc_total_offset).to_f / 3600.0
            formatOffset = formatOffset.to_s
            if (!formatOffset.include?("-"))
              formatOffset.insert(0, "+")
            end
            formatOffset.delete_suffix!(".0")
            formatOffset += ":00"
            @setupOffset += formatOffset + " "
          else
            embed_response(bot, e, "m?setupTime", ":information_source: | Command Information", "The inputted timezone must follow the correct format.\n\n`m?setupTime ([timezone] [timezone])`- please remember to remove the square brackets.\n\nRefer to the TZ Database column for your timezone: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
            break
          end
        end
        @setupTime = true
        msg = embed_response(bot, e, "m?setupTime", ":information_source: | Timezone Initialisation for #{@setupTeamName}", "Are you sure the timezones entered are correct?\nReact below once you have double checked the timezones being set.")
        msg.create_reaction("\u{2705}")
        msg.create_reaction("\u{274E}")
      else
        embed_response(bot, e, "m?setupTime", ":information_source: | Command Information", "There is a current limit of three timezones allowed to be inputted.\n\n`m?setupTime ([timezone] [timezone])`- please remember to remove the square brackets.\n\nRefer to the TZ Database column for your timezone: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
        break
      end
    end
  else
    embed_response(bot, e, "m?setupTime", ":information_source: | Command Information", "You need to first initialise the team for this channel\n\n`m?setup [team name] [mention role]` - please remember to move the sqaure brackets.")
    break
  end
end

# Bot Events/Triggers
bot.reaction_add do |e|
  if (@setupTeam and !@setupTime)
    reaction_team(bot, e)
  elsif (@setupTime)
    reaction_time(bot, e)
  end
end

# Constant Update Loop
while true
  if (@startup)
    startup(bot)
  end
  if ((Time.now >= @scheduleTimer + 3600) and ((Time.now).strftime("%M") == "00"))
    @scheduleTimer = Time.now
    @count = 0
    startup(bot)
  end
  if ((Time.now >= @reminderTimer + 60) or (@reminderStartup))
    @reminderStartup = false
    check_reminder(bot)
  end
end

bot.join
