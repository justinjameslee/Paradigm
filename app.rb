require "bundler"
Bundler.require

require "dotenv"
Dotenv.load

get "/" do
  erb :index
end

post "/" do
  begin
    schedule = Airrecord.table(ENV["API_KEY"], ENV["APP_KEY"], ENV["SCHEDULE_TABLE"])
    date = "#{params[:date]}"
    date = DateTime.parse(date)
    date = date.strftime("%d/%m/%Y")
    record = schedule.new("Date" => "#{date}")
    record["Type"] = "#{params[:type]}"
    record["Team/Coach"] = "#{params[:name]}"
    record["Time"] = "#{params[:time]}"
    record["Owner"] = ["rec5Nb3tjefrxXLzd"]
    record.save
    erb :confirm
  rescue
    erb :index, locals: { error_message: "Your details could not be saved, please try again!" }
  end
end
