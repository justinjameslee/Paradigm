# Periodic Reminder Check
def check_reminder(bot)
  @reminderTimer = Time.now
  @reminderTimeArray.length.times do |i|
    if (@reminderTimeArray[i][0].is_a?(Time))
      timeNow = DateTime.now
      if (@reminderTimeArray[i][3] != "")
        timeNow = timeNow.new_offset("#{@reminderTimeArray[i][3]}")
        startTime = [DateTime.parse((@reminderTimeArray[i][0]).to_s), DateTime.parse((@reminderTimeArray[i][1]).to_s)]
        startTime[0] = startTime[0].change(:offset => "#{@reminderTimeArray[i][3]}")
        startTime[1] = startTime[1].change(:offset => "#{@reminderTimeArray[i][3]}")
        endTime = [DateTime.parse((@reminderTimeArray[i][0] + 60).to_s), DateTime.parse((@reminderTimeArray[i][1] + 60).to_s)]
        endTime[0] = endTime[0].change(:offset => "#{@reminderTimeArray[i][3]}")
        endTime[1] = endTime[1].change(:offset => "#{@reminderTimeArray[i][3]}")
        if (timeNow.between?(startTime[0], endTime[0]))
          send_reminder(bot, @reminderTimeArray[i][2], "1 hour")
        elsif (timeNow.between?(startTime[1], endTime[1]))
          send_reminder(bot, @reminderTimeArray[i][2], "10 mins")
        end
      end
    end
  end
end
