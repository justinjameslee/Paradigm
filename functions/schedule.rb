# Read Record from Online Spreadsheet
def read_record(record, dateDay)
  event = Event.new()
  event.id = record["ID"]
  event.date = dateDay.strftime("%A")
  event.type = record["Type"]
  event.info = record["Team/Coach"]
  strTimeA = record["Time"].split("-")[0]
  strTimeB = record["Time"].split("-")[1]
  date = dateDay.strftime("%m/%d/%y")
  offset = @offset.split(" ")
  initTime = DateTime.parse(strTimeA)
  endTime = DateTime.parse(strTimeB)
  t1 = DateTime.new(dateDay.strftime("%y").to_i, dateDay.strftime("%m").to_i, dateDay.strftime("%d").to_i, initTime.strftime("%H").to_i, initTime.strftime("%M").to_i, 0, "#{offset[0]}")
  event.duration = Time.parse(endTime.to_s) - Time.parse(initTime.to_s)
  event.t1 = t1
  offset_diff = offset[1].to_i - offset[0].to_i
  if (offset.length >= 2)
    event.t2 = t1.new_offset("#{offset[1]}")
  else
    event.t2 = ""
  end
  if (offset.length >= 3)
    offset_diff = offset[2].to_i - offset[0].to_i
    event.t3 = t1.new_offset("#{offset[2]}")
  else
    event.t3 = ""
  end
  return event
end

# Check for mutiple events in a single day
def check_type(events, index)
  if (events.event[index].length >= 2)
    temp = Array.new
    events.event[index].length.times do |i|
      temp << events.event[index][i].type
    end
    return temp.join(", ")
  else
    return events.event[index][0].type
  end
end

# Simplified Embed Response Method
def embed_response(bot, e, author, name, value)
  embedHash = Discordrb::Webhooks::Embed.new()
  embedHash.author = Discordrb::Webhooks::EmbedAuthor.new(name: "#{author}", icon_url: "https://i.imgur.com/tpZy4mK.jpg")
  embedHash.add_field(name: "#{name}", value: "#{value}")
  embedHash.colour = 0xef0000
  bot.send_message(e.channel.id, "", tts = false, embed = embedHash)
end

# on Bot startup
def startup(bot)
  @startup = false
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  channel = []
  teams.all.each do |record|
    @count += 1
    channel << record["Channel"]
  end
  puts @count
  @count.times do |i|
    send_schedule(bot, channel[i])
  end
end

# Reminder Response Message
def send_reminder(bot, channel, strTime)
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  teamID = nil
  team = nil
  mention = nil
  server = nil
  teams.all(filter: "{Channel} = \"#{channel}\"").each do |record|
    found = true
    team = record["Team"]
    teamID = record.id
    @offset = record["Offset"]
    @timezones = record["Timezone"]
    mention = record["Mention"]
    server = record["Server"]
  end

  events = Events.new()
  t = Time.now
  today = DateTime.parse(t.to_s)
  todayDate = today.strftime("%d/%m/%Y")
  schedule = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["SCHEDULE_TABLE"])
  arrayEvents = Array.new
  schedule.all(filter: "{Date} = \"#{todayDate}\"").each do |record|
    if (record["Owner"].include?("#{teamID}"))
      event = read_record(record, today)
      arrayEvents << event
    end
  end
  events.event << arrayEvents
  embedHash = Discordrb::Webhooks::Embed.new()
  embedHash.author = Discordrb::Webhooks::EmbedAuthor.new(name: "#{team}", icon_url: "https://i.imgur.com/tpZy4mK.jpg")
  embedHash.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: "https://i.imgur.com/YFB9ilT.png")
  embedHash.title = ":information_source: | Event Reminder"
  embedHash.description = "#{events.event[0][0].type} starting in approximately #{strTime}!"
  embedHash.colour = 0xef0000
  embedHash.footer = Discordrb::Webhooks::EmbedFooter.new(text: "\nLast Updated", icon_url: nil)
  embedHash.timestamp = Time.now
  typeDetail = "with #{events.event[0][0].info}"
  embedHash.add_field(name: "Event", value: "#{events.event[0][0].type} #{typeDetail}")
  timezone = @timezone.split(" ")
  embedHash.add_field(name: "Start Time", value: "#{DateTime.parse(events.event[0][0].t1.to_s).strftime("%I:%M%p")} #{timezone[0]}", inline: true)
  endTime = Time.parse(events.event[0][0].t1.to_s) + events.event[0][0].duration.to_i
  embedHash.add_field(name: "End Time", value: "#{DateTime.parse(endTime.to_s).strftime("%I:%M%p")} #{timezone[0]}", inline: true)
  bot.send_message(channel, "#{mention}", tts = false, embed = embedHash)
  mention.delete!("<@&>")
  users = bot.server(server).role(mention)&.members
  users.length.times do |i|
    dm = users[i].pm
    bot.send_message(dm, "", tts = false, embed = embedHash)
  end
end

# Set Reminder Times for 1HR and 10Mins
def reminderDetails(time, channel)
  offset = @offset.split(" ")
  reminderDetail = [Time.parse(time.split("-")[0]) - 3600, Time.parse(time.split("-")[0]) - 600, channel, offset[0]]
  @reminderTimeArray << reminderDetail
end

# Send Main Schedule for Specificed Channel
def send_schedule(bot, e)
  teams = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["TEAM_TABLE"])
  found = false
  teamID = nil
  channel = nil
  if ((e.to_i).is_a?(Integer))
    channel = e
  else
    channel = e.channel.id
  end
  teams.all(filter: "{Channel} = \"#{channel}\"").each do |record|
    found = true
    teamID = record.id
    @teamName = record["Team"].to_s
    @timezone = record["Timezone"].to_s
    @offset = record["Offset"].to_s
    puts teamID
    puts @teamName
  end
  if (!found)
    if (!((e.to_i).is_a?(Integer)))
      embed_response(bot, e, "Notice", ":warning: | **#{e.channel.name}**", "`#{e.channel.name}` channel has not been registered into the Paradigm Schedule Bot service.\nFor more information please contact: FiLeZekk#2594")
      return
    end
  end
  schedule = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["SCHEDULE_TABLE"])
  events = Events.new()
  t = Time.now
  dateDay = DateTime.parse(t.beginning_of_week.to_s)
  today = DateTime.parse(t.to_s)
  todayDate = today.strftime("%d/%m/%Y")
  7.times do |i|
    date = dateDay.strftime("%d/%m/%Y")
    events.date << date
    arrayEvents = Array.new()
    count = 0
    schedule.all(filter: "{Date} = \"#{date}\"").each do |record|
      if (record["Owner"].include?("#{teamID}"))
        event = read_record(record, dateDay)
        arrayEvents << event
        if ((date == todayDate and count == 0) or (count == 0 and DateTime.parse(Time.parse(record["Time"].split("-")[0]).to_s).strftime("%H") == "00"))
          reminderDetails(record["Time"], channel)
          count += 1
        end
      end
    end
    if (arrayEvents != [])
      events.event << arrayEvents
    else
      if (date == todayDate)
        @reminderTimeArray.concat([["", ""]])
      end
      events.event << [0, dateDay.strftime("%A")]
    end
    dateDay += 1
  end

  # Prune Above Messages
  if ((e.to_i).is_a?(Integer))
    bot.channel(channel).prune(100)
  else
    message_count = e.channel.history(100).count
    if (message_count != 0)
      e.channel.prune(message_count)
    end
  end

  # Organise Data into Embed
  embedHash = Discordrb::Webhooks::Embed.new()
  embedHash.title = "**#{@teamName}**"
  if (@timezone == "")
    embedHash.description = ""
  elsif (@timezone.include?(" "))
    embedHash.description = "Timezones: `#{@timezone}`"
  else
    embedHash.description = "Timezone: `#{@timezone}`"
  end
  embedHash.colour = 0xef0000
  embedHash.footer = Discordrb::Webhooks::EmbedFooter.new(text: "\nLast Updated", icon_url: nil)
  embedHash.timestamp = Time.now
  events.event.length.times do |index|
    if (events.event[index][0] != 0)
      type = check_type(events, index)
      temp = Array.new
      events.event[index].length.times do |i|
        info = "#{events.event[index][i].info}"
        t1 = "#{events.event[index][i].t1}"
        t2 = "#{events.event[index][i].t2}"
        t3 = "#{events.event[index][i].t3}"
        duration = "#{events.event[index][i].duration}"
        timezone = @timezone.split(" ")
        t1End = (Time.parse(t1) + duration.to_i)
        t1 = "[" + DateTime.parse(t1.to_s).strftime("%I:%M%p") + " - " + DateTime.parse(t1End.to_s).strftime("%I:%M%p") + " #{timezone[0]}]"
        if (timezone.length >= 2)
          t2End = (Time.parse(t2) + duration.to_i)
          t2 = "[" + DateTime.parse(t2.to_s).strftime("%I:%M%p") + " - " + DateTime.parse(t2End.to_s).strftime("%I:%M%p") + " #{timezone[1]}]"
        end
        if (timezone.length >= 3)
          t3End = (Time.parse(t3) + duration.to_i)
          t3 = "[" + DateTime.parse(t3.to_s).strftime("%I:%M%p") + " - " + DateTime.parse(t3End.to_s).strftime("%I:%M%p") + " #{timezone[2]}]"
        end

        value = "- #{info} - \n#{t1}\n#{t2}\n#{t3}"
        temp << value
      end
      value = temp.join("\n")
      if (index == 0)
        embedHash.add_field(name: "**\n#{events.event[index][0].date}** | #{type}", value: "```diff\n#{value}```")
      else
        embedHash.add_field(name: "**#{events.event[index][0].date}** | #{type}", value: "```diff\n#{value}```")
      end
    else
      if (index == 0)
        embedHash.add_field(name: "**\n#{events.event[index][1]}**", value: "```diff\n- BREAK -```")
      else
        embedHash.add_field(name: "**#{events.event[index][1]}**", value: "```diff\n- BREAK -```")
      end
    end
  end
  bot.send_message(channel, "", tts = false, embed = embedHash)
end
